import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/trail_service.dart';
import 'liquid_glass.dart';
import 'now_playing_bar.dart';

// Altura compartida entre la barra de canción y los botones, para que
// queden perfectamente alineados (misma altura en pixeles).
const double _trailRowHeight = 60;
const double _trailButtonSize = 60;
const double _trailGap = 10;

/// Fila que combina la barra de "reproduciendo ahora" (Spotify) con los
/// controles del Trail: play, pause y stop.
///
/// Por ahora esto SOLO maneja el estado visual (play/pause/stop) a través
/// de [TrailService]. Todavía no arranca geolocalización ni guarda ningún
/// recorrido: es la base para conectar esa lógica más adelante.
class TrailControlsRow extends StatefulWidget {
  const TrailControlsRow({super.key});

  @override
  State<TrailControlsRow> createState() => _TrailControlsRowState();
}

class _TrailControlsRowState extends State<TrailControlsRow> {
  final TrailService _trailService = TrailService.instance;

  @override
  void initState() {
    super.initState();
    _trailService.addListener(_onTrailChanged);
  }

  @override
  void dispose() {
    _trailService.removeListener(_onTrailChanged);
    super.dispose();
  }

  void _onTrailChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isPaused = _trailService.isPaused;
    final isActive = _trailService.isActive;

    // Pausado: hacemos lugar para 2 botones (stop + play).
    // Si no: un solo botón (play o pause).
    final visibleButtons = isPaused ? 2 : 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final reservedForButtons =
            visibleButtons * (_trailButtonSize + _trailGap);
        final barWidth =
            (totalWidth - reservedForButtons).clamp(0.0, totalWidth);

        return SizedBox(
          height: _trailRowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                width: barWidth,
                height: _trailRowHeight,
                child: const NowPlayingBar(),
              ),
              const SizedBox(width: _trailGap),
              if (isPaused) ...[
                _TrailIconButton(
                  assetPath: 'assets/icons/stop_trail.svg',
                  tooltip: 'Finalizar trail',
                  onTap: _trailService.stop,
                ),
                const SizedBox(width: _trailGap),
              ],
              _TrailIconButton(
                assetPath: isActive
                    ? 'assets/icons/pause_trail.svg'
                    : 'assets/icons/play_trail.svg',
                tooltip: isActive ? 'Pausar trail' : 'Iniciar trail',
                onTap: isActive ? _trailService.pause : _trailService.play,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TrailIconButton extends StatelessWidget {
  final String assetPath;
  final String tooltip;
  final VoidCallback onTap;

  const _TrailIconButton({
    required this.assetPath,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LiquidGlass(
          borderRadius: BorderRadius.circular(_trailButtonSize / 2),
          blurSigma: 16,
          tintOpacity: 0.14,
          child: SizedBox(
            width: _trailButtonSize,
            height: _trailButtonSize,
            child: Center(
              child: SvgPicture.asset(
                assetPath,
                width: 22,
                height: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}