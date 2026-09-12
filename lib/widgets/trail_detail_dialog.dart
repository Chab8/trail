import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/completed_trail.dart';
import 'trail_like_button.dart';
import 'trail_map_preview.dart';

/// Color de acento morado usado en toda la app.
const _accentColor = Color(0xFF654CDD);

/// Blanco principal para títulos y encabezados de sección.
const _colorMain = Color(0xFFFEFEFE);

/// Gris para subtítulos, estadísticas y separadores.
const _colorSub = Color(0xFF9C9C9C);

/// Ancho de los separadores de sección.
const _dividerWidth = 248.0;

/// Detalle expandido de un trail: nombre, mapa, estadísticas (duración,
/// distancia, cantidad de tracks) y el artista más escuchado.
class TrailDetailDialog extends StatelessWidget {
  const TrailDetailDialog({
    super.key,
    required this.trail,
    this.isOwnTrail = true,
  });

  final CompletedTrail trail;

  /// Si es `false` (perfil de otro usuario), se oculta el botón de editar:
  /// solo el dueño del trail puede editarlo.
  final bool isOwnTrail;

  static Future<void> show(
    BuildContext context,
    CompletedTrail trail, {
    Alignment origin = Alignment.center,
    bool isOwnTrail = true,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Trail Detail',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, _, _) =>
          TrailDetailDialog(trail: trail, isOwnTrail: isOwnTrail),
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutExpo,
        );
        // Fade rápido en la primera mitad de la animación
        final fadeAnim = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.05, end: 1.0).animate(curved),
          alignment: origin,
          child: FadeTransition(opacity: fadeAnim, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 90),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              // #09080B al 60 % de opacidad
              color: const Color(0x9909080B),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // ── Contenido principal ───────────────────────────────────
                SingleChildScrollView(
                  child: Padding(
                    // Padding superior alto para dejar espacio a los iconos de esquina
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nombre del trail
                        Text(
                          trail.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _colorMain,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ── Mapa 116 × 86 sin fondo + likes a la derecha ──
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 116,
                              height: 86,
                              child: TrailMapPreview(
                                segments: trail.segments,
                                height: 86,
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            TrailLikeButton(trailId: trail.id),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Separador
                        Container(
                          width: _dividerWidth,
                          height: 1,
                          color: _colorSub,
                        ),
                        const SizedBox(height: 14),
                        // ── Sección "Destacada" ────────────────────────────
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
                        const SizedBox(height: 16),
                        // Separador
                        Container(
                          width: _dividerWidth,
                          height: 1,
                          color: _colorSub,
                        ),
                        const SizedBox(height: 14),
                        // ── Sección artista: nombre como encabezado ────────
                        _SectionHeader(label: trail.topArtist ?? 'Sin datos'),
                        const SizedBox(height: 6),
                        const Text(
                          'Genre',
                          style: TextStyle(color: _colorSub, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(trail.completedAt),
                          style: const TextStyle(
                            color: _colorSub,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Botón cerrar — esquina superior izquierda ─────────────
                Positioned(
                  top: 14,
                  left: 14,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: SvgPicture.asset(
                        'assets/icons/exit_cross.svg',
                        width: 14,
                        height: 14,
                        colorFilter: const ColorFilter.mode(
                          _colorSub,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Botón editar — esquina superior derecha ───────────────
                // Solo se muestra en tus propios trails; en el perfil de
                // otro usuario no tiene sentido poder editarlo.
                if (isOwnTrail)
                  Positioned(
                    top: 14,
                    right: 14,
                    child: GestureDetector(
                      // TODO: implementar la edición del trail más adelante.
                      onTap: () {},
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: SvgPicture.asset(
                          'assets/icons/edit.svg',
                          width: 14,
                          height: 14,
                          colorFilter: const ColorFilter.mode(
                            _colorSub,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Encabezado de sección: ★ + label en _colorMain
// ─────────────────────────────────────────────────────────────────────────────
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
          width: 14,
          height: 14,
          colorFilter: const ColorFilter.mode(_accentColor, BlendMode.srcIn),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: _colorMain,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip de estadística: icono SVG + texto en _colorSub
// ─────────────────────────────────────────────────────────────────────────────
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
          width: 13,
          height: 13,
          colorFilter: const ColorFilter.mode(_colorSub, BlendMode.srcIn),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: _colorSub, fontSize: 13),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers de formato
// ─────────────────────────────────────────────────────────────────────────────
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