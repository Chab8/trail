import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/completed_trail.dart';
import 'trail_map_preview.dart';

/// Color de acento morado usado en toda la app (íconos seleccionados, etc).
const _accentColor = Color(0xFF654CDD);

/// Detalle expandido de un trail: nombre, mapa, estadísticas (duración,
/// distancia, cantidad de tracks) y el artista más escuchado.
///
/// La lista de canciones (`trail.songs`) se sigue calculando y guardando,
/// pero todavía no se muestra acá — se va a reincorporar más adelante con
/// un diseño definitivo.
class TrailDetailDialog extends StatelessWidget {
  const TrailDetailDialog({super.key, required this.trail});

  final CompletedTrail trail;

  static Future<void> show(BuildContext context, CompletedTrail trail) {
    return showDialog<void>(
      context: context,
      builder: (_) => TrailDetailDialog(trail: trail),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF262626),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 90),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TopBar(name: trail.name),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: TrailMapPreview(segments: trail.segments, height: 140),
            ),
            const SizedBox(height: 18),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 18),
            const _SectionHeader(label: 'Destacada'),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatChip(
                  iconPath: 'assets/icons/clock.svg',
                  label: _formatDuration(trail.duration),
                ),
                const SizedBox(width: 24),
                _StatChip(
                  iconPath: 'assets/icons/steps.svg',
                  label: _formatDistance(trail.distanceMeters),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _StatChip(
              iconPath: 'assets/icons/music_note.svg',
              label: '${trail.songs.length} tracks',
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 20),
            const _SectionHeader(label: 'Top Artist'),
            const SizedBox(height: 10),
            Text(
              trail.topArtist ?? 'Sin datos suficientes',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(trail.completedAt),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: SvgPicture.asset(
            'assets/icons/exit_cross.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(Colors.white70, BlendMode.srcIn),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          icon: SvgPicture.asset(
            'assets/icons/edit.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(Colors.white70, BlendMode.srcIn),
          ),
          // TODO: implementar la edición del trail más adelante.
          onPressed: () {},
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/icons/star.svg',
          width: 16,
          height: 16,
          colorFilter: const ColorFilter.mode(_accentColor, BlendMode.srcIn),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.iconPath, required this.label});

  final String iconPath;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          iconPath,
          width: 14,
          height: 14,
          colorFilter: const ColorFilter.mode(Colors.white54, BlendMode.srcIn),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
        ),
      ],
    );
  }
}

String _formatDuration(Duration duration) => '${duration.inMinutes}min';

String _formatDistance(double meters) =>
    '${(meters / 1000).toStringAsFixed(2)}km';

String _formatDate(DateTime date) {
  const months = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];
  return '${months[date.month - 1]}. ${date.day} ${date.year}';
}