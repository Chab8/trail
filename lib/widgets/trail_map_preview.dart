import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/trail_service.dart';

/// Mini-mapa que dibuja el trazado GPS de un trail finalizado.
///
/// Escala automáticamente todos los segmentos para que quepan en el widget,
/// con un margen interior. Si no hay puntos suficientes, muestra un
/// placeholder con un ícono de ruta.
class TrailMapPreview extends StatelessWidget {
  const TrailMapPreview({
    super.key,
    required this.segments,
    this.height = 160,
    this.lineColor = const Color(0xFF1ED760),
    this.backgroundColor = const Color(0xFF1A1A1A),
    this.lineWidth = 3.0,
  });

  final List<List<TrailPoint>> segments;
  final double height;
  final Color lineColor;
  final Color backgroundColor;
  final double lineWidth;

  bool get _hasPoints =>
      segments.any((seg) => seg.length >= 2);

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
  });

  final List<List<TrailPoint>> segments;
  final Color lineColor;
  final double lineWidth;

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
    final double offsetX =
        _margin + (drawW - lonRange * scale) / 2;
    final double offsetY =
        _margin + (drawH - latRange * scale) / 2;

    Offset project(TrailPoint p) {
      // Latitud aumenta hacia arriba → invertimos Y
      final x = offsetX + (p.longitude - minLon) * scale;
      final y = offsetY + (maxLat - p.latitude) * scale;
      return Offset(x, y);
    }

    // 2. Pintar sombra suave de la línea
    final shadowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.25)
      ..strokeWidth = lineWidth + 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final segment in segments) {
      if (segment.length < 2) continue;
      final path = Path();
      path.moveTo(project(segment.first).dx, project(segment.first).dy);
      for (final p in segment.skip(1)) {
        final o = project(p);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, shadowPaint);
      canvas.drawPath(path, linePaint);
    }

    // 3. Punto de inicio (círculo blanco con relleno del color del trail)
    final firstSeg = segments.firstWhere(
      (s) => s.isNotEmpty,
      orElse: () => [],
    );
    if (firstSeg.isNotEmpty) {
      final startOffset = project(firstSeg.first);
      canvas.drawCircle(
        startOffset,
        lineWidth * 2.2,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        startOffset,
        lineWidth * 1.4,
        Paint()..color = lineColor,
      );
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.segments != segments ||
      old.lineColor != lineColor ||
      old.lineWidth != lineWidth;
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
          Icon(Icons.route_outlined, size: 36, color: color.withValues(alpha: 0.5)),
          const SizedBox(height: 6),
          Text(
            'Sin trazado GPS',
            style: TextStyle(
              color: color.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}