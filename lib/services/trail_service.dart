import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

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
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
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

  TrailStatus _status = TrailStatus.idle;
  StreamSubscription<Position>? _positionSubscription;
  final List<List<TrailPoint>> _segments = [];
  String? _locationErrorMessage;
  bool _isStarting = false;
  int _startRequestId = 0;
  int _trailRevision = 0;

  TrailStatus get status => _status;

  bool get isIdle => _status == TrailStatus.idle;
  bool get isActive => _status == TrailStatus.active;
  bool get isPaused => _status == TrailStatus.paused;
  bool get isStarting => _isStarting;
  int get trailRevision => _trailRevision;

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
        _trailRevision++;
      }
      _segments.add([_trailPointFrom(position)]);
      _status = TrailStatus.active;
      _isStarting = false;
      _listenToPositionUpdates();
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

    _status = TrailStatus.paused;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    notifyListeners();
    await subscription?.cancel();
  }

  /// Finaliza el registro, pero deja visible el recorrido hasta iniciar otro.
  Future<void> stop() async {
    if (_status == TrailStatus.idle && !_isStarting) return;

    ++_startRequestId;
    _isStarting = false;
    _status = TrailStatus.idle;
    final subscription = _positionSubscription;
    _positionSubscription = null;
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

    currentSegment.add(_trailPointFrom(position));
    notifyListeners();
  }

  TrailPoint _trailPointFrom(Position position) {
    return TrailPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      recordedAt: position.timestamp,
    );
  }
}

class _TrailLocationException implements Exception {
  const _TrailLocationException(this.message);

  final String message;
}
