import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/trail_song.dart';
import 'dominant_color_service.dart';
import 'spotify_service.dart';

/// Estados posibles de un Trail (recorrido musical).
enum TrailStatus { idle, active, paused }

/// Un punto del recorrido actual.
///
/// Se mantiene separado de Mapbox para que el servicio sólo se ocupe de
/// registrar ubicación y el mapa pueda decidir cómo representarla.
class TrailPoint {
  const TrailPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.colorValue,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;

  /// Color (ARGB) de la portada de la canción que sonaba cuando se
  /// registró este punto. Es null para los puntos grabados antes de
  /// detectar la primera canción; en ese caso se usa un color de respaldo.
  final int? colorValue;
}

/// Maneja el Trail que se está registrando en este momento.
///
/// El recorrido se conserva solamente en memoria. Cada vez que se pausa y se
/// retoma, se crea un segmento nuevo para que el mapa no dibuje una línea
/// durante el intervalo de pausa.
class TrailService extends ChangeNotifier {
  TrailService._internal();
  static final TrailService instance = TrailService._internal();

  static const _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    // Pedimos cada actualización disponible; el filtro final se aplica abajo
    // para que los teléfonos que publican lecturas espaciadas no omitan el
    // recorrido al caminar.
    distanceFilter: 0,
  );

  // Configuración del "polling inteligente" de Spotify: en vez de preguntar
  // todo el tiempo a un ritmo fijo, programamos la próxima consulta para el
  // momento en que la canción actual debería terminar. Esto detecta el
  // cambio de canción casi al instante y evita saturar la API de Spotify
  // (lo cual puede hacer que Spotify empiece a rechazar pedidos).
  static const _songPollFallbackInterval = Duration(seconds: 6);
  static const _songPollMinInterval = Duration(seconds: 3);
  static const _songPollMaxInterval = Duration(seconds: 30);
  static const _songPollBuffer = Duration(milliseconds: 1500);

  TrailStatus _status = TrailStatus.idle;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _songTimer;
  final List<List<TrailPoint>> _segments = [];
  final List<TrailSong> _songs = [];
  String? _locationErrorMessage;
  bool _isStarting = false;
  int _startRequestId = 0;
  int _trailRevision = 0;
  DateTime? _activeSince;
  Duration _accumulatedDuration = Duration.zero;
  double _accumulatedDistanceMeters = 0;

  /// Color (ARGB) que se le asigna a cada punto nuevo del recorrido. Se
  /// actualiza cada vez que detectamos un cambio de canción, calculando el
  /// color dominante de la portada del álbum.
  int? _currentPointColor;

  TrailStatus get status => _status;

  bool get isIdle => _status == TrailStatus.idle;
  bool get isActive => _status == TrailStatus.active;
  bool get isPaused => _status == TrailStatus.paused;
  bool get isStarting => _isStarting;
  int get trailRevision => _trailRevision;

  /// Color (ARGB) que se le está asignando en este momento al trazado del
  /// trail. Es null si todavía no se detectó ninguna canción.
  int? get currentColor => _currentPointColor;

  /// Tiempo total que el trail estuvo activo (sin contar las pausas).
  Duration get elapsedDuration => _activeSince == null
      ? _accumulatedDuration
      : _accumulatedDuration + DateTime.now().difference(_activeSince!);

  /// Distancia total recorrida durante el trail, en metros.
  double get distanceMeters => _accumulatedDistanceMeters;

  /// Canciones detectadas durante el trail que está en curso o recién terminó.
  List<TrailSong> get songs => List<TrailSong>.unmodifiable(_songs);

  /// Último error de ubicación, pensado para que la UI informe al usuario.
  String? get locationErrorMessage => _locationErrorMessage;

  /// Segmentos del trail actual/finalizado en esta sesión.
  ///
  /// La copia evita que la UI pueda alterar accidentalmente el recorrido.
  List<List<TrailPoint>> get segments => List<List<TrailPoint>>.unmodifiable(
    _segments.map<List<TrailPoint>>(
      (segment) => List<TrailPoint>.unmodifiable(segment),
    ),
  );

  /// Inicia un Trail nuevo o retoma uno pausado desde la ubicación actual.
  Future<void> play() async {
    if (_status == TrailStatus.active || _isStarting) return;

    final requestId = ++_startRequestId;
    final startsNewTrail = _status == TrailStatus.idle;
    _isStarting = true;
    _locationErrorMessage = null;
    notifyListeners();

    try {
      await _ensureLocationAccess();
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      // El usuario pudo cancelar el inicio mientras se obtenía la ubicación.
      if (requestId != _startRequestId) return;

      if (startsNewTrail) {
        _segments.clear();
        _songs.clear();
        _trailRevision++;
        _accumulatedDuration = Duration.zero;
        _accumulatedDistanceMeters = 0;
        _currentPointColor = null;
      }
      _segments.add([_trailPointFrom(position)]);
      _status = TrailStatus.active;
      _isStarting = false;
      _activeSince = DateTime.now();
      _listenToPositionUpdates();
      _startSongTracking();
      notifyListeners();
    } on _TrailLocationException catch (error) {
      if (requestId != _startRequestId) return;
      _isStarting = false;
      _locationErrorMessage = error.message;
      notifyListeners();
    } on TimeoutException {
      if (requestId != _startRequestId) return;
      _isStarting = false;
      _locationErrorMessage =
          'No pudimos obtener tu ubicación. Probá de nuevo en unos segundos.';
      notifyListeners();
    } catch (_) {
      if (requestId != _startRequestId) return;
      _isStarting = false;
      _locationErrorMessage =
          'No pudimos iniciar el registro de tu ubicación. Probá de nuevo.';
      notifyListeners();
    }
  }

  /// Pausa el registro. Al retomar se iniciará otro segmento del recorrido.
  Future<void> pause() async {
    if (_status != TrailStatus.active) return;

    _pauseStopwatch();
    _status = TrailStatus.paused;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    _stopSongTracking();
    notifyListeners();
    await subscription?.cancel();
  }

  /// Finaliza el registro, pero deja visible el recorrido hasta iniciar otro.
  Future<void> stop() async {
    if (_status == TrailStatus.idle && !_isStarting) return;

    _pauseStopwatch();
    ++_startRequestId;
    _isStarting = false;
    _status = TrailStatus.idle;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    _stopSongTracking();
    notifyListeners();
    await subscription?.cancel();
  }

  Future<void> _ensureLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const _TrailLocationException(
        'Activá los servicios de ubicación para iniciar un trail.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const _TrailLocationException(
        'Necesitamos permiso de ubicación para registrar tu trail.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const _TrailLocationException(
        'El permiso de ubicación está bloqueado. Habilitalo desde Ajustes.',
      );
    }
  }

  void _listenToPositionUpdates() {
    final subscription =
        Geolocator.getPositionStream(locationSettings: _locationSettings)
            .listen(
              _recordPosition,
              onError: (Object _) {
                _locationErrorMessage = 'Se interrumpió el registro de ubicación. Revisá tu señal e intentá continuar el trail.';
                notifyListeners();
              },
            );
    _positionSubscription = subscription;
  }

  /// Arranca el seguimiento de canciones: consulta a Spotify ahora mismo y
  /// programa las siguientes consultas de forma inteligente.
  void _startSongTracking() {
    _stopSongTracking();
    unawaited(_pollCurrentSong());
  }

  void _stopSongTracking() {
    _songTimer?.cancel();
    _songTimer = null;
  }

  void _scheduleNextSongPoll(Duration delay) {
    _songTimer?.cancel();
    if (!isActive) return;
    _songTimer = Timer(delay, () => unawaited(_pollCurrentSong()));
  }

  /// Suma el tiempo activo transcurrido desde el último play() al total
  /// acumulado, y detiene el "cronómetro" hasta el próximo play().
  void _pauseStopwatch() {
    final activeSince = _activeSince;
    if (activeSince == null) return;
    _accumulatedDuration += DateTime.now().difference(activeSince);
    _activeSince = null;
  }

  /// Le pregunta a Spotify qué está sonando ahora, actualiza la canción y el
  /// color si cambió, y programa la próxima consulta para el momento justo
  /// en que la canción actual debería terminar (en vez de preguntar a un
  /// ritmo fijo todo el tiempo, lo cual puede hacer que Spotify empiece a
  /// rechazar pedidos si el trail dura mucho).
  Future<void> _pollCurrentSong() async {
    if (!isActive) return;

    SpotifyNowPlaying? track;
    try {
      track = await SpotifyService.instance.getCurrentlyPlaying();
    } catch (_) {
      // Problema momentáneo de red: reintentamos más adelante sin
      // interrumpir el registro de ubicación del trail.
      _scheduleNextSongPoll(_songPollFallbackInterval);
      return;
    }

    if (!isActive) return;

    if (track == null || !track.isPlaying) {
      _scheduleNextSongPoll(_songPollFallbackInterval);
      return;
    }

    // Si Spotify sigue en la misma canción, no la repetimos en la lista.
    if (_songs.isEmpty || _songs.last.trackId != track.trackId) {
      _songs.add(
        TrailSong(
          trackId: track.trackId,
          title: track.trackName,
          artist: track.artistName,
          startedAt: DateTime.now(),
        ),
      );
      notifyListeners();

      // A partir de ahora, el trazado del trail toma el color de la
      // portada de esta canción nueva, hasta que vuelva a cambiar.
      await _updateColorForCurrentSong(track.albumArtUrl);
    }

    _scheduleNextSongPoll(_nextPollDelayFor(track));
  }

  /// Calcula cuánto falta impide que la canción actual termine, para
  /// preguntarle a Spotify justo en ese momento (más un pequeño margen).
  Duration _nextPollDelayFor(SpotifyNowPlaying track) {
    if (track.durationMs <= 0) return _songPollFallbackInterval;

    final remainingMs = track.durationMs - track.progressMs;
    if (remainingMs <= 0) return _songPollMinInterval;

    final delay = Duration(milliseconds: remainingMs) + _songPollBuffer;
    if (delay < _songPollMinInterval) return _songPollMinInterval;
    if (delay > _songPollMaxInterval) return _songPollMaxInterval;
    return delay;
  }

  /// Calcula el color dominante de la portada del álbum y lo deja
  /// guardado para que los próximos puntos del recorrido lo usen.
  Future<void> _updateColorForCurrentSong(String? albumArtUrl) async {
    try {
      final color = await DominantColorService.getColor(albumArtUrl);
      if (color == null || !isActive) return;

      final colorValue = color.toARGB32();
      if (_currentPointColor == colorValue) return;

      _currentPointColor = colorValue;
      notifyListeners();
    } catch (_) {
      // Si falla la descarga de la portada, seguimos usando el color
      // anterior en vez de interrumpir el trail.
    }
  }

  void _recordPosition(Position position) {
    if (_status != TrailStatus.active || _segments.isEmpty) return;

    final currentSegment = _segments.last;
    final lastPoint = currentSegment.last;
    final distance = Geolocator.distanceBetween(
      lastPoint.latitude,
      lastPoint.longitude,
      position.latitude,
      position.longitude,
    );

    // Conservamos movimientos de al menos un metro. El filtro nativo se deja
    // en cero porque algunos dispositivos emiten actualizaciones muy poco
    // frecuentes cuando se configura un filtro de distancia mayor.
    if (distance < 1) return;

    _accumulatedDistanceMeters += distance;
    currentSegment.add(_trailPointFrom(position));
    notifyListeners();
  }

  TrailPoint _trailPointFrom(Position position) {
    return TrailPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      recordedAt: position.timestamp,
      colorValue: _currentPointColor,
    );
  }
}

class _TrailLocationException implements Exception {
  const _TrailLocationException(this.message);

  final String message;
}