import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../services/trail_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _trailColor = 0xFF1ED760;
  static const _trailOutlineColor = 0xFF133D22;

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
  int _renderedStartMarkerCount = 0;
  int _lastCenteredSegmentCount = 0;

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
    _scheduleTrailRender();
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
      _renderedStartMarkerCount = 0;
      _segmentLines.clear();
      _renderedPointCounts.clear();
    }

    if (_isDisposed ||
        lineManager != _trailLineManager ||
        startManager != _trailStartManager) {
      return;
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
              circleRadius: 6,
              circleStrokeColor: _trailOutlineColor,
              circleStrokeWidth: 2,
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
            lineBorderColor: _trailOutlineColor,
            lineBorderWidth: 1.5,
            lineJoin: LineJoin.ROUND,
            lineWidth: 6,
          ),
        );
      } else if (_renderedPointCounts[index] != segment.length) {
        line.geometry = geometry;
        await lineManager.update(line);
      }
      _renderedPointCounts[index] = segment.length;
    }

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
