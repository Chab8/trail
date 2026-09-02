import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../services/dominant_color_service.dart';
import '../services/spotify_service.dart';
import '../services/trail_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Color que se conserva cuando no hay una canción reproduciéndose.
  static const _fallbackTrailColor = 0xFF1ED760;
  static const _trailLineWidth = 28.0;

  final TrailService _trailService = TrailService.instance;
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _trailLineManager;
  CircleAnnotationManager? _trailStartManager;
  final List<PolylineAnnotation?> _segmentLines = [];
  final List<int> _renderedPointCounts = [];
  bool _isDisposed = false;
  bool _isRenderingTrail = false;
  bool _needsTrailRender = false;
  int _renderedTrailRevision = -1;
  int _renderedTrailColor = -1;
  double _renderedTrailLineWidth = -1;
  int _renderedStartMarkerCount = 0;
  int _lastCenteredSegmentCount = 0;
  int _trailColor = _fallbackTrailColor;
  int _colorTrailRevision = -1;
  bool _needsStartMarkerRefresh = false;

  @override
  void initState() {
    super.initState();
    _trailService.addListener(_onTrailChanged);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _trailService.removeListener(_onTrailChanged);
    _mapboxMap = null;
    _trailLineManager = null;
    _trailStartManager = null;
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _mapboxMap = controller;

    await controller.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await controller.compass.updateSettings(CompassSettings(enabled: false));
    await controller.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        puckBearingEnabled: true,
      ),
    );

    final lineManager = await controller.annotations
        .createPolylineAnnotationManager();
    final startManager = await controller.annotations
        .createCircleAnnotationManager();

    if (_isDisposed || _mapboxMap != controller) return;

    _trailLineManager = lineManager;
    _trailStartManager = startManager;
    _scheduleTrailRender();
    await _goToUserLocation();
  }

  Future<void> _goToUserLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      final position = await Geolocator.getCurrentPosition();
      await _mapboxMap?.setCamera(
        CameraOptions(
          center: Point(
            coordinates: Position(position.longitude, position.latitude),
          ),
          zoom: 15.0,
        ),
      );
    } catch (_) {
      // El control de Trail muestra el error si no se puede registrar luego.
    }
  }

  void _onTrailChanged() {
    if (_trailService.isIdle) _lastCenteredSegmentCount = 0;

    final revision = _trailService.trailRevision;
    if (_trailService.segments.isNotEmpty && revision != _colorTrailRevision) {
      _colorTrailRevision = revision;
      _trailColor = _fallbackTrailColor;
      _needsStartMarkerRefresh = true;
      unawaited(_loadTrailColor(revision));
    }

    _scheduleTrailRender();
  }

  /// El color se define al iniciar cada trail para que todo su recorrido
  /// represente la canción que se estaba reproduciendo en ese momento.
  Future<void> _loadTrailColor(int trailRevision) async {
    try {
      final track = await SpotifyService.instance.getCurrentlyPlaying();
      if (track == null || !track.isPlaying) return;

      final color = await DominantColorService.getColor(track.albumArtUrl);
      if (color == null ||
          _isDisposed ||
          trailRevision != _trailService.trailRevision) {
        return;
      }

      final colorValue = color.toARGB32();
      if (_trailColor == colorValue) return;

      _trailColor = colorValue;
      _needsStartMarkerRefresh = true;
      _scheduleTrailRender();
    } catch (_) {
      // Sin una canción o sin conexión usamos el color de respaldo.
    }
  }

  void _scheduleTrailRender() {
    if (_isDisposed ||
        _trailLineManager == null ||
        _trailStartManager == null) {
      return;
    }

    _needsTrailRender = true;
    if (_isRenderingTrail) return;
    unawaited(_renderTrail());
  }

  /// Sincroniza sólo los puntos nuevos con Mapbox. No recreamos la línea en
  /// cada lectura GPS, así la polilínea se actualiza de forma estable al andar.
  Future<void> _renderTrail() async {
    _isRenderingTrail = true;

    try {
      while (_needsTrailRender && !_isDisposed) {
        _needsTrailRender = false;
        await _renderTrailSnapshot();
      }
    } catch (error) {
      debugPrint('No se pudo actualizar el trazado del trail: $error');
    } finally {
      _isRenderingTrail = false;
      if (_needsTrailRender && !_isDisposed) _scheduleTrailRender();
    }
  }

  Future<void> _renderTrailSnapshot() async {
    final lineManager = _trailLineManager;
    final startManager = _trailStartManager;
    if (lineManager == null || startManager == null) return;

    final revision = _trailService.trailRevision;
    final segments = _trailService.segments;
    if (_renderedTrailRevision != revision) {
      if (_renderedTrailRevision != -1) {
        await lineManager.deleteAll();
        await startManager.deleteAll();
      }
      _renderedTrailRevision = revision;
      _renderedTrailColor = -1;
      _renderedTrailLineWidth = -1;
      _renderedStartMarkerCount = 0;
      _segmentLines.clear();
      _renderedPointCounts.clear();
      _needsStartMarkerRefresh = false;
    }

    if (_isDisposed ||
        lineManager != _trailLineManager ||
        startManager != _trailStartManager) {
      return;
    }

    if (_needsStartMarkerRefresh) {
      await startManager.deleteAll();
      _renderedStartMarkerCount = 0;
      _needsStartMarkerRefresh = false;
    }

    // Cada segmento comienza con un punto visible; al retomar habrá un punto
    // nuevo y la ausencia de una línea entre ambos representa la pausa.
    while (_renderedStartMarkerCount < segments.length) {
      final segment = segments[_renderedStartMarkerCount];
      if (segment.isNotEmpty) {
        try {
          await startManager.create(
            CircleAnnotationOptions(
              geometry: _mapboxPoint(segment.first),
              circleColor: _trailColor,
              circleRadius: 8,
            ),
          );
        } catch (error) {
          // Un marcador fallido no debe impedir que se dibuje la línea.
          debugPrint('No se pudo dibujar el inicio del trail: $error');
        }
      }
      _renderedStartMarkerCount++;
    }

    while (_segmentLines.length < segments.length) {
      _segmentLines.add(null);
      _renderedPointCounts.add(0);
    }

    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      if (segment.length < 2) continue;

      final geometry = LineString(
        coordinates: segment.map(_mapboxPosition).toList(),
      );
      final line = _segmentLines[index];
      if (line == null) {
        _segmentLines[index] = await lineManager.create(
          PolylineAnnotationOptions(
            geometry: geometry,
            lineColor: _trailColor,
            // Evita que la iluminación del estilo de Mapbox oscurezca el
            // color extraído de la portada.
            lineEmissiveStrength: 1,
            lineJoin: LineJoin.ROUND,
            lineWidth: _trailLineWidth,
          ),
        );
      } else {
        final geometryChanged = _renderedPointCounts[index] != segment.length;
        final styleChanged =
            _renderedTrailColor != _trailColor ||
            _renderedTrailLineWidth != _trailLineWidth;
        if (geometryChanged || styleChanged) {
          if (geometryChanged) line.geometry = geometry;
          if (styleChanged) {
            line.lineColor = _trailColor;
            line.lineEmissiveStrength = 1;
            line.lineWidth = _trailLineWidth;
          }
          await lineManager.update(line);
        }
      }
      _renderedPointCounts[index] = segment.length;
    }

    _renderedTrailColor = _trailColor;
    _renderedTrailLineWidth = _trailLineWidth;

    await _centerOnNewSegment(segments);
  }

  Future<void> _centerOnNewSegment(List<List<TrailPoint>> segments) async {
    if (!_trailService.isActive ||
        segments.isEmpty ||
        segments.last.length != 1 ||
        _lastCenteredSegmentCount == segments.length) {
      return;
    }

    _lastCenteredSegmentCount = segments.length;
    await _mapboxMap?.easeTo(
      CameraOptions(center: _mapboxPoint(segments.last.first), zoom: 16),
      MapAnimationOptions(duration: 600),
    );
  }

  Point _mapboxPoint(TrailPoint point) {
    return Point(coordinates: _mapboxPosition(point));
  }

  Position _mapboxPosition(TrailPoint point) {
    return Position(point.longitude, point.latitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapWidget(
        key: const ValueKey('mapWidget'),
        styleUri: 'mapbox://styles/chab8/cmm6hxker009n01s8ftpbgmdc',
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(-65.2226, -26.8241)),
          zoom: 12.0,
        ),
        onMapCreated: _onMapCreated,
      ),
    );
  }
}
