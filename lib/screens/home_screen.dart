import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../services/trail_service.dart';
import '../widgets/map_search_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Color que se usa para los tramos grabados antes de detectar una
  // canción (por ejemplo, el primer instante del trail).
  static const _fallbackTrailColor = 0xFF1ED760;
  static const _trailLineWidth = 28.0;

  final TrailService _trailService = TrailService.instance;
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _trailLineManager;
  CircleAnnotationManager? _trailStartManager;

  // Por cada segmento geográfico (separado por pausas), guardamos la lista
  // de "tramos de color": sub-recorridos dentro del segmento que comparten
  // el mismo color porque sonaba la misma canción.
  final List<List<_ColorRun>> _segmentRuns = [];
  int _renderedStartMarkerCount = 0;
  bool _isDisposed = false;
  bool _isRenderingTrail = false;
  bool _needsTrailRender = false;
  int _renderedTrailRevision = -1;
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
    await controller.logo.updateSettings(
      LogoSettings(
        position: OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 4,
        marginBottom: 4,
      ),
    );
    await controller.attribution.updateSettings(
      AttributionSettings(
        position: OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 50,
        marginBottom: 4,
        clickable: true,
      ),
    );
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

  /// Sincroniza sólo los tramos nuevos con Mapbox. No recreamos las líneas
  /// en cada lectura GPS, así el trazado se actualiza de forma estable al
  /// andar.
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
      _segmentRuns.clear();
    }

    if (_isDisposed ||
        lineManager != _trailLineManager ||
        startManager != _trailStartManager) {
      return;
    }

    while (_segmentRuns.length < segments.length) {
      _segmentRuns.add(<_ColorRun>[]);
    }

    // Cada segmento comienza con un punto visible; al retomar habrá un punto
    // nuevo y la ausencia de una línea entre ambos representa la pausa. El
    // color del punto de inicio es el que sonaba en ese instante.
    while (_renderedStartMarkerCount < segments.length) {
      final segment = segments[_renderedStartMarkerCount];
      if (segment.isNotEmpty) {
        final markerColor = segment.first.colorValue ?? _fallbackTrailColor;
        try {
          await startManager.create(
            CircleAnnotationOptions(
              geometry: _mapboxPoint(segment.first),
              circleColor: markerColor,
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

    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      if (segment.length < 2) continue;

      final runs = _splitPointsByColor(segment);
      final renderedRuns = _segmentRuns[index];

      while (renderedRuns.length < runs.length) {
        final newRunPoints = runs[renderedRuns.length];
        final color = newRunPoints.first.colorValue ?? _fallbackTrailColor;
        renderedRuns.add(_ColorRun(color));
      }

      for (var runIndex = 0; runIndex < runs.length; runIndex++) {
        final runPoints = runs[runIndex];
        if (runPoints.length < 2) continue;

        final renderedRun = renderedRuns[runIndex];
        if (renderedRun.renderedPointCount == runPoints.length &&
            renderedRun.annotation != null) {
          continue;
        }

        final geometry = LineString(
          coordinates: runPoints.map(_mapboxPosition).toList(),
        );

        if (renderedRun.annotation == null) {
          renderedRun.annotation = await lineManager.create(
            PolylineAnnotationOptions(
              geometry: geometry,
              lineColor: renderedRun.color,
              // Evita que la iluminación del estilo de Mapbox oscurezca el
              // color extraído de la portada.
              lineEmissiveStrength: 1,
              lineJoin: LineJoin.ROUND,
              lineWidth: _trailLineWidth,
            ),
          );
        } else {
          renderedRun.annotation!.geometry = geometry;
          await lineManager.update(renderedRun.annotation!);
        }
        renderedRun.renderedPointCount = runPoints.length;
      }
    }

    await _centerOnNewSegment(segments);
  }

  /// Divide los puntos de un segmento en tramos que comparten el mismo
  /// color. Cada vez que cambia la canción (y por lo tanto el color),
  /// cerramos el tramo anterior justo en ese punto y arrancamos uno nuevo
  /// desde ahí mismo, para que la línea se vea continua en la unión.
  List<List<TrailPoint>> _splitPointsByColor(List<TrailPoint> points) {
    final runs = <List<TrailPoint>>[];
    var current = <TrailPoint>[points.first];
    var currentColor = points.first.colorValue;

    for (var i = 1; i < points.length; i++) {
      final point = points[i];
      if (point.colorValue != currentColor) {
        current.add(point);
        runs.add(current);
        current = <TrailPoint>[point];
        currentColor = point.colorValue;
      } else {
        current.add(point);
      }
    }
    runs.add(current);
    return runs;
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
      body: Stack(
        children: [
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey('mapWidget'),
              styleUri: 'mapbox://styles/chab8/cmm6hxker009n01s8ftpbgmdc',
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(-65.2226, -26.8241)),
                zoom: 12.0,
              ),
              onMapCreated: _onMapCreated,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: Align(
                alignment: Alignment.topLeft,
                child: MapSearchBar(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado de un tramo de color dentro de un segmento del trail: guarda su
/// anotación de Mapbox y cuántos puntos tiene dibujados hasta ahora, para
/// saber si hace falta extender la línea o si ya está al día.
class _ColorRun {
  _ColorRun(this.color);

  final int color;
  PolylineAnnotation? annotation;
  int renderedPointCount = 0;
}