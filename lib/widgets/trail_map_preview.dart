import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/trail_service.dart';

/// Intervalo en el tiempo activo de un trail. No incluye las pausas entre
/// segmentos GPS, por lo que coincide con los offsets guardados por canción.
class TrailActiveTimeRange {
  const TrailActiveTimeRange({required this.start, required this.end});

  final Duration start;
  final Duration end;

  bool contains(Duration value) => value >= start && value < end;
}

/// Mini-mapa que dibuja el trazado GPS de un trail finalizado.
///
/// Escala automáticamente todos los segmentos para que quepan en el widget,
/// con un margen interior. Cada tramo se pinta con el color guardado en sus
/// puntos (el color de la canción que sonaba en ese momento); los puntos sin
/// color guardado (trails viejos, o el instante antes de detectar la primera
/// canción) usan [lineColor] como respaldo. Si no hay puntos suficientes,
/// muestra un placeholder con un ícono de ruta.
class TrailMapPreview extends StatelessWidget {
  const TrailMapPreview({
    super.key,
    required this.segments,
    this.height = 160,
    this.lineColor = const Color(0xFF1ED760),
    this.backgroundColor = const Color(0xFF1A1A1A),
    this.lineWidth = 3.0,
    this.highlightedRange,
    this.hiddenRanges = const [],
  });

  final List<List<TrailPoint>> segments;
  final double height;
  final Color lineColor;
  final Color backgroundColor;
  final double lineWidth;

  /// Intervalo de la canción elegida. Se pinta por encima del recorrido
  /// atenuado para identificar su fragmento en el mapa.
  final TrailActiveTimeRange? highlightedRange;

  /// Intervalos de canciones que el usuario decidió no mostrar.
  final List<TrailActiveTimeRange> hiddenRanges;

  bool get _hasPoints => segments.any((seg) => seg.length >= 2);

  // Cuando el widget se usa chico (por ejemplo, en la lista de trails del
  // perfil), no hay espacio para el texto del placeholder: mostramos
  // solamente el ícono.
  bool get _isCompact => height <= 100;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: height,
        width: double.infinity,
        color: backgroundColor,
        child: _hasPoints
            ? CustomPaint(
                painter: _TrailPainter(
                  segments: segments,
                  lineColor: lineColor,
                  lineWidth: lineWidth,
                  highlightedRange: highlightedRange,
                  hiddenRanges: hiddenRanges,
                ),
              )
            : _Placeholder(color: lineColor, compact: _isCompact),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Painter interno
// ──────────────────────────────────────────────────────────────────────────────

class _TrailPainter extends CustomPainter {
  _TrailPainter({
    required this.segments,
    required this.lineColor,
    required this.lineWidth,
    this.highlightedRange,
    this.hiddenRanges = const [],
  });

  final List<List<TrailPoint>> segments;
  final Color lineColor;
  final double lineWidth;
  final TrailActiveTimeRange? highlightedRange;
  final List<TrailActiveTimeRange> hiddenRanges;

  static const double _margin = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Recoger todos los puntos para calcular el bounding box
    final allPoints = segments.expand((seg) => seg).toList();
    if (allPoints.isEmpty) return;

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLon = allPoints.first.longitude;
    double maxLon = allPoints.first.longitude;

    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    final latRange = maxLat - minLat;
    final lonRange = maxLon - minLon;

    final drawW = size.width - _margin * 2;
    final drawH = size.height - _margin * 2;

    // Si el recorrido es un único punto (sin movimiento), dibujamos solo el dot
    final double scaleX = lonRange == 0 ? 1 : drawW / lonRange;
    final double scaleY = latRange == 0 ? 1 : drawH / latRange;
    final double scale = math.min(scaleX, scaleY);

    // Centrar el trazado dentro del área de dibujo
    final double offsetX = _margin + (drawW - lonRange * scale) / 2;
    final double offsetY = _margin + (drawH - latRange * scale) / 2;

    Offset project(TrailPoint p) {
      // Latitud aumenta hacia arriba → invertimos Y
      final x = offsetX + (p.longitude - minLon) * scale;
      final y = offsetY + (maxLat - p.latitude) * scale;
      return Offset(x, y);
    }

    if (highlightedRange != null || hiddenRanges.isNotEmpty) {
      _paintWithSongVisibility(canvas, project, _activeOffsets());
      return;
    }

    // 2. Pintar cada segmento, partido en tramos según el color guardado
    // en cada punto (el color de la canción que sonaba en ese momento).
    for (final segment in segments) {
      if (segment.length < 2) continue;

      final runs = _splitPointsByColor(segment);
      for (final run in runs) {
        if (run.length < 2) continue;

        final runColor = _colorFor(run.first);

        final shadowPaint = Paint()
          ..color = runColor.withValues(alpha: 0.25)
          ..strokeWidth = lineWidth + 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        final linePaint = Paint()
          ..color = runColor
          ..strokeWidth = lineWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;

        final path = Path();
        path.moveTo(project(run.first).dx, project(run.first).dy);
        for (final p in run.skip(1)) {
          final o = project(p);
          path.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(path, shadowPaint);
        canvas.drawPath(path, linePaint);
      }
    }

    // 3. Punto de inicio (círculo blanco con relleno del color real de ese
    // instante del trail).
    final firstSeg = segments.firstWhere((s) => s.isNotEmpty, orElse: () => []);
    if (firstSeg.isNotEmpty) {
      final startColor = _colorFor(firstSeg.first);
      final startOffset = project(firstSeg.first);
      canvas.drawCircle(
        startOffset,
        lineWidth * 2.2,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        startOffset,
        lineWidth * 1.4,
        Paint()..color = startColor,
      );
    }
  }

  /// Dibuja los tramos visibles con menor intensidad y superpone el de la
  /// canción seleccionada. Al evaluar cada par de puntos se evita unir una
  /// línea a través de un intervalo oculto.
  void _paintWithSongVisibility(
    Canvas canvas,
    Offset Function(TrailPoint point) project,
    Map<TrailPoint, Duration> activeOffsets,
  ) {
    for (final segment in segments) {
      for (var index = 1; index < segment.length; index++) {
        final previous = segment[index - 1];
        final current = segment[index];
        if (_isHidden(previous, activeOffsets) ||
            _isHidden(current, activeOffsets)) {
          continue;
        }

        final isHighlighted =
            highlightedRange != null &&
            (_isInRange(previous, highlightedRange!, activeOffsets) ||
                _isInRange(current, highlightedRange!, activeOffsets));
        final from = project(previous);
        final to = project(current);

        if (isHighlighted) {
          final highlightColor = _colorFor(current);
          final accentShadowPaint = Paint()
            ..color = const Color(0xFF654CDD).withValues(alpha: 0.5)
            ..strokeWidth = lineWidth + 9
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          final accentOutlinePaint = Paint()
            ..color = const Color(0xFF654CDD)
            ..strokeWidth = lineWidth + 5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          final songColorPaint = Paint()
            ..color = highlightColor
            ..strokeWidth = lineWidth
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          canvas.drawLine(from, to, accentShadowPaint);
          canvas.drawLine(from, to, accentOutlinePaint);
          canvas.drawLine(from, to, songColorPaint);
        } else {
          final runColor = _colorFor(current);
          final shadowPaint = Paint()
            ..color = runColor.withValues(alpha: 0.25)
            ..strokeWidth = lineWidth + 6
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          final linePaint = Paint()
            ..color = runColor
            ..strokeWidth = lineWidth
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke;
          canvas.drawLine(from, to, shadowPaint);
          canvas.drawLine(from, to, linePaint);
        }
      }
    }

    final firstSegment = segments.firstWhere(
      (segment) => segment.isNotEmpty,
      orElse: () => [],
    );
    if (firstSegment.isEmpty || _isHidden(firstSegment.first, activeOffsets)) {
      return;
    }

    final start = project(firstSegment.first);
    canvas.drawCircle(start, lineWidth * 2.2, Paint()..color = Colors.white);
    canvas.drawCircle(
      start,
      lineWidth * 1.4,
      Paint()..color = _colorFor(firstSegment.first),
    );
  }

  Map<TrailPoint, Duration> _activeOffsets() {
    final offsets = <TrailPoint, Duration>{};
    var elapsed = Duration.zero;

    for (final segment in segments) {
      if (segment.isEmpty) continue;
      final start = segment.first.recordedAt;
      for (final point in segment) {
        final pointElapsed = point.recordedAt.difference(start);
        offsets[point] =
            elapsed + (pointElapsed.isNegative ? Duration.zero : pointElapsed);
      }
      final segmentDuration = segment.last.recordedAt.difference(start);
      if (!segmentDuration.isNegative) elapsed += segmentDuration;
    }
    return offsets;
  }

  bool _isHidden(TrailPoint point, Map<TrailPoint, Duration> activeOffsets) =>
      hiddenRanges.any((range) => _isInRange(point, range, activeOffsets));

  bool _isInRange(
    TrailPoint point,
    TrailActiveTimeRange range,
    Map<TrailPoint, Duration> activeOffsets,
  ) => range.contains(activeOffsets[point] ?? Duration.zero);

  /// Divide los puntos de un segmento en tramos que comparten el mismo
  /// color, para poder pintar cada tramo con el color de la canción que
  /// sonaba en ese momento.
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

  Color _colorFor(TrailPoint point) {
    final value = point.colorValue;
    return value != null ? Color(value) : lineColor;
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.segments != segments ||
      old.lineColor != lineColor ||
      old.lineWidth != lineWidth ||
      old.highlightedRange != highlightedRange ||
      old.hiddenRanges != hiddenRanges;
}

// ──────────────────────────────────────────────────────────────────────────────
// Placeholder sin puntos suficientes
// ──────────────────────────────────────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.color, this.compact = false});

  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Center(
        child: Icon(
          Icons.route_outlined,
          size: 24,
          color: color.withValues(alpha: 0.5),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route_outlined,
            size: 36,
            color: color.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 6),
          Text(
            'Sin trazado GPS',
            style: TextStyle(color: color.withValues(alpha: 0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
