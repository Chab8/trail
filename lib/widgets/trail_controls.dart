import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/trail_service.dart';
import 'now_playing_bar.dart';

// Altura compartida entre la barra de canción y los botones, para que
// queden perfectamente alineados (misma altura en pixeles).
const double _trailRowHeight = 60;
const double _trailButtonSize = 58;
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

class _TrailControlsRowState extends State<TrailControlsRow>
    with SingleTickerProviderStateMixin {
  final TrailService _trailService = TrailService.instance;
  late final AnimationController _controlsController;
  late final Animation<double> _controlsAnimation;

  @override
  void initState() {
    super.initState();
    _controlsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: _trailService.isPaused ? 1 : 0,
    );
    _controlsAnimation = CurvedAnimation(
      parent: _controlsController,
      curve: Curves.easeOut,
    );
    _trailService.addListener(_onTrailChanged);
  }

  @override
  void dispose() {
    _trailService.removeListener(_onTrailChanged);
    _controlsController.dispose();
    super.dispose();
  }

  void _onTrailChanged() {
    if (_trailService.isPaused) {
      _controlsController.forward();
    } else {
      _controlsController.reverse();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isPaused = _trailService.isPaused;
    final isActive = _trailService.isActive;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        return AnimatedBuilder(
          animation: _controlsAnimation,
          builder: (context, child) {
            // El bloque de controles crece hacia la izquierda al mostrar stop.
            // Así el espacio entre él y la barra siempre es exactamente el mismo.
            final controlsWidth =
                _trailButtonSize +
                ((_trailButtonSize + _trailGap) * _controlsAnimation.value);
            final barWidth = (totalWidth - _trailGap - controlsWidth).clamp(
              0.0,
              totalWidth,
            );

            return SizedBox(
              height: _trailRowHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: barWidth,
                    height: _trailRowHeight,
                    child: const NowPlayingBar(),
                  ),
                  const SizedBox(width: _trailGap),
                  SizedBox(
                    width: controlsWidth,
                    height: _trailRowHeight,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: (_trailRowHeight - _trailButtonSize) / 2,
                          child: IgnorePointer(
                            ignoring: !isPaused,
                            child: _TrailIconButton(
                              assetPath: 'assets/icons/stop_trail.svg',
                              tooltip: 'Finalizar trail',
                              onTap: _trailService.stop,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: (_trailRowHeight - _trailButtonSize) / 2,
                          child: _TrailIconButton(
                            assetPath: isActive
                                ? 'assets/icons/pause_trail.svg'
                                : 'assets/icons/play_trail.svg',
                            tooltip: isActive
                                ? 'Pausar trail'
                                : 'Iniciar trail',
                            onTap: isActive
                                ? _trailService.pause
                                : _trailService.play,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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
        child: SizedBox(
          width: _trailButtonSize,
          height: _trailButtonSize,
          child: SvgPicture.asset(
            assetPath,
            width: _trailButtonSize,
            height: _trailButtonSize,
          ),
        ),
      ),
    );
  }
}
