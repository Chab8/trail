import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/completed_trail.dart';
import 'trail_like_button.dart';
import 'trail_map_preview.dart';

/// Color de acento morado usado en toda la app.
const _accentColor = Color(0xFF654CDD);

/// Blanco principal para títulos y encabezados de sección.
const _colorMain = Color(0xFFFEFEFE);

/// Gris para subtítulos, estadísticas y separadores.
const _colorSub = Color(0xFF9C9C9C);

/// Detalle expandido de un trail: nombre, mapa, estadísticas (duración,
/// distancia, cantidad de tracks) y el artista más escuchado.
///
/// Es un [StatefulWidget] para manejar el modo de edición.
class TrailDetailDialog extends StatefulWidget {
  const TrailDetailDialog({
    super.key,
    required this.trail,
    this.isOwnTrail = true,
    this.onDeleted,
  });

  final CompletedTrail trail;

  /// Si es `false` (perfil de otro usuario), se oculta el botón de editar:
  /// solo el dueño del trail puede editarlo.
  final bool isOwnTrail;

  /// Callback invocado cuando el trail es eliminado exitosamente.
  final VoidCallback? onDeleted;

  static Future<void> show(
    BuildContext context,
    CompletedTrail trail, {
    Alignment origin = Alignment.center,
    bool isOwnTrail = true,
    VoidCallback? onDeleted,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Trail Detail',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (_, _, _) => TrailDetailDialog(
        trail: trail,
        isOwnTrail: isOwnTrail,
        onDeleted: onDeleted,
      ),
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
  State<TrailDetailDialog> createState() => _TrailDetailDialogState();
}

class _TrailDetailDialogState extends State<TrailDetailDialog> {
  bool _isEditing = false;
  bool _isDeleting = false;
  bool _isTopExpanded = false;
  int _selectedSongIndex = 0;

  bool get _hasSongs => widget.trail.songs.isNotEmpty;

  String get _selectedSongTitle => _hasSongs
      ? widget.trail.songs[_selectedSongIndex].title
      : 'Sin canciones';

  void _expandTopSection() {
    setState(() {
      _selectedSongIndex = 0;
      _isTopExpanded = true;
    });
  }

  void _showPreviousSong() {
    if (!_hasSongs || _selectedSongIndex == 0) return;
    setState(() => _selectedSongIndex--);
  }

  void _showNextSong() {
    if (!_hasSongs || _selectedSongIndex >= widget.trail.songs.length - 1) {
      return;
    }
    setState(() => _selectedSongIndex++);
  }

  Future<void> _deleteTrail() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Eliminar trail?',
          style: TextStyle(color: _colorMain, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Se eliminará "${widget.trail.name}" permanentemente. Esta acción no se puede deshacer.',
          style: const TextStyle(color: _colorSub, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: _colorSub)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isDeleting = true);
    try {
      await Supabase.instance.client
          .from('trails')
          .delete()
          .eq('id', widget.trail.id);

      if (!mounted) return;
      widget.onDeleted?.call();
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al eliminar el trail')),
      );
    }
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: 350,
            height: _isTopExpanded ? 500 : 340,
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: const Color(0x9909080B),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // ── Contenido principal ────────────────────────────────
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 61, 20, 8),
                      child: _isTopExpanded
                          ? _buildExpandedTopContent()
                          : _buildCollapsedContent(),
                    ),
                  ),

                  // ── Barra superior: botón izq | título | botón der ───────
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 61,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(width: 10),

                        // En la vista expandida se vuelve a la vista normal.
                        if (_isTopExpanded)
                          GestureDetector(
                            onTap: () => setState(() => _isTopExpanded = false),
                            behavior: HitTestBehavior.opaque,
                            child: _ButtonSvg('assets/buttons/back button.svg'),
                          )
                        // Botón izquierdo: Delete (modo edición) o Exit
                        else if (_isEditing)
                          GestureDetector(
                            onTap: _isDeleting ? null : _deleteTrail,
                            behavior: HitTestBehavior.opaque,
                            child: _isDeleting
                                ? const SizedBox(
                                    width: 39,
                                    height: 39,
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _colorSub,
                                        ),
                                      ),
                                    ),
                                  )
                                : _ButtonSvg(
                                    'assets/buttons/delete button.svg',
                                  ),
                          )
                        else
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            behavior: HitTestBehavior.opaque,
                            child: _ButtonSvg('assets/buttons/exit button.svg'),
                          ),

                        // Título centrado entre los dos botones
                        Expanded(
                          child: Text(
                            widget.trail.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _colorMain,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        // En la vista expandida el botón de compartir todavía
                        // no tiene acción.
                        if (_isTopExpanded)
                          GestureDetector(
                            onTap: () {},
                            behavior: HitTestBehavior.opaque,
                            child: _ButtonSvg(
                              'assets/buttons/share button.svg',
                            ),
                          )
                        // Botón derecho: Done (modo edición) o Edit (solo propio)
                        else if (widget.isOwnTrail)
                          if (_isEditing)
                            GestureDetector(
                              onTap: () => setState(() => _isEditing = false),
                              behavior: HitTestBehavior.opaque,
                              child: _ButtonSvg(
                                'assets/buttons/done button.svg',
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: () => setState(() => _isEditing = true),
                              behavior: HitTestBehavior.opaque,
                              child: _ButtonSvg(
                                'assets/buttons/edit button.svg',
                              ),
                            )
                        else
                          // Espacio equivalente para mantener el título centrado
                          const SizedBox(width: 39),

                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Al tocar cualquiera de los elementos de esta sección se expande.
        GestureDetector(
          onTap: _expandTopSection,
          behavior: HitTestBehavior.translucent,
          child: Column(
            children: [
              SizedBox(
                width: 116,
                height: 80,
                child: TrailMapPreview(
                  segments: widget.trail.segments,
                  height: 80,
                  backgroundColor: Colors.transparent,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 248,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/public.svg',
                          width: 14,
                          height: 14,
                          colorFilter: const ColorFilter.mode(
                            _accentColor,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Public',
                          style: TextStyle(color: _colorSub, fontSize: 12),
                        ),
                      ],
                    ),
                    TrailLikeButton(trailId: widget.trail.id),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Container(width: 248, height: 1, color: _colorSub),
        const SizedBox(height: 8),
        const _SectionHeader(label: 'Destacada'),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatChip(
              iconPath: 'assets/icons/clock.svg',
              label: _formatDuration(widget.trail.duration),
            ),
            const SizedBox(width: 24),
            _StatChip(
              iconPath: 'assets/icons/steps.svg',
              label: _formatDistance(widget.trail.distanceMeters),
            ),
          ],
        ),
        const SizedBox(height: 5),
        _StatChip(
          iconPath: 'assets/icons/music_note.svg',
          label: '${widget.trail.songs.length} tracks',
        ),
        const SizedBox(height: 8),
        Container(width: 248, height: 1, color: _colorSub),
        const SizedBox(height: 6),
        _SectionHeader(label: widget.trail.topArtist ?? 'Sin datos'),
        const SizedBox(height: 3),
        const Text('Genre', style: TextStyle(color: _colorSub, fontSize: 13)),
        const SizedBox(height: 2),
        Text(
          _formatDate(widget.trail.completedAt),
          style: const TextStyle(color: _colorSub, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildExpandedTopContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 236,
          height: 164,
          child: TrailMapPreview(
            segments: widget.trail.segments,
            height: 164,
            backgroundColor: Colors.transparent,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _SongArrowButton(
              assetPath: 'assets/icons/left arrow.svg',
              enabled: _hasSongs && _selectedSongIndex > 0,
              onTap: _showPreviousSong,
            ),
            Expanded(
              child: Text(
                _selectedSongTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _colorMain,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _SongArrowButton(
              assetPath: 'assets/icons/right arrow.svg',
              enabled:
                  _hasSongs &&
                  _selectedSongIndex < widget.trail.songs.length - 1,
              onTap: _showNextSong,
            ),
          ],
        ),
        const SizedBox(height: 5),
        const Text(
          '0:00-0:00',
          style: TextStyle(color: _colorSub, fontSize: 15),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icons/music_note.svg',
                width: 17,
                height: 17,
                colorFilter: const ColorFilter.mode(_colorSub, BlendMode.srcIn),
              ),
              const SizedBox(width: 7),
              const Text(
                'View full tracklist',
                style: TextStyle(color: _colorSub, fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SongArrowButton extends StatelessWidget {
  const _SongArrowButton({
    required this.assetPath,
    required this.enabled,
    required this.onTap,
  });

  final String assetPath;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: SvgPicture.asset(assetPath, width: 13, height: 22),
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
        Text(label, style: const TextStyle(color: _colorSub, fontSize: 13)),
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
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];
  return '${months[date.month - 1]}. ${date.day} ${date.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón SVG de 39×39 a partir de un SVG nativo de 119×119.
//
// Los SVG de los botones tienen viewBox 119×119, pero el círculo visible tiene
// r=19.5 (diámetro 39px). Se renderiza el SVG a 119×119 y se recorta una
// ventana de 39×39 centrada en el círculo (cx=59.5, cy=51.5).
// Ajuste Y: 59.5-51.5=8px → normalizado -8/((119-39)/2) ≈ -0.2
// ─────────────────────────────────────────────────────────────────────────────
class _ButtonSvg extends StatelessWidget {
  const _ButtonSvg(this.assetPath);

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: 39,
        height: 39,
        child: OverflowBox(
          maxWidth: 119,
          maxHeight: 119,
          alignment: const Alignment(0.0, -0.2),
          child: SvgPicture.asset(assetPath, width: 119, height: 119),
        ),
      ),
    );
  }
}
