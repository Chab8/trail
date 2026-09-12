import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/trail_library_service.dart';
import '../services/trail_service.dart';
import 'now_playing_bar.dart';

// Altura compartida entre la barra de canción y los botones, para que
// queden perfectamente alineados (misma altura en pixeles).
const double _trailRowHeight = 60;
const double _trailButtonSize = 58;
const double _trailGap = 10;

/// Qué eligió el usuario en el diálogo de "Guardar trail".
enum _FinishTrailChoice { cancel, discard, save }

/// Fila que combina la barra de "reproduciendo ahora" (Spotify) con los
/// controles del Trail: play, pause y stop.
///
/// [TrailService] se encarga de registrar la ubicación mientras el Trail está
/// activo. Al finalizarlo se guarda su resumen en el perfil.
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
  String? _lastShownLocationError;
  bool _isFinishing = false;

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

    final locationError = _trailService.locationErrorMessage;
    if (locationError == null) {
      _lastShownLocationError = null;
    } else if (locationError != _lastShownLocationError) {
      _lastShownLocationError = locationError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(locationError)));
      });
    }

    if (mounted) setState(() {});
  }

  Future<void> _finishTrail() async {
    if (_isFinishing || !_trailService.isPaused) return;

    final library = TrailLibraryService.instance;
    String trailName;
    try {
      trailName = await library.getNextDefaultName();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo preparar el guardado del trail.'),
        ),
      );
      return;
    }

    // Si el usuario elige "Descartar" pero después se arrepiente en la
    // confirmación, este bucle vuelve a mostrar el diálogo de guardado
    // con el nombre que ya había escrito.
    while (true) {
      if (!mounted) return;

      final choice = await showDialog<_FinishTrailChoice>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Guardar trail'),
          content: TextFormField(
            initialValue: trailName,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nombre del trail'),
            onChanged: (value) => trailName = value,
            onFieldSubmitted: (value) =>
                Navigator.of(dialogContext).pop(_FinishTrailChoice.save),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(_FinishTrailChoice.discard),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Descartar'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext)
                      .pop(_FinishTrailChoice.cancel),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext)
                      .pop(_FinishTrailChoice.save),
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      );

      // Cerrar el diálogo tocando afuera, o elegir "Cancelar", deja el
      // trail pausado para poder retomarlo o finalizarlo más tarde.
      if (choice == null || choice == _FinishTrailChoice.cancel) return;

      if (choice == _FinishTrailChoice.save) {
        await _saveTrail(trailName);
        return;
      }

      // choice == _FinishTrailChoice.discard: pedimos confirmación antes
      // de borrar definitivamente el recorrido.
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (confirmContext) => AlertDialog(
          title: const Text(
            '¿Estás seguro que quieres eliminar este trail?',
          ),
          content: const Text(
            'Se perderá todo el recorrido registrado. Esta acción no se '
            'puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(confirmContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(confirmContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _trailService.stop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trail descartado.')),
          );
        }
        return;
      }
      // Si canceló la confirmación, el bucle vuelve a mostrar el diálogo
      // de guardado.
    }
  }

  Future<void> _saveTrail(String trailName) async {
    if (!mounted) return;
    final library = TrailLibraryService.instance;

    setState(() => _isFinishing = true);
    try {
      await library.addTrail(
        name: trailName,
        songs: _trailService.songs,
        segments: _trailService.segments,
        duration: _trailService.elapsedDuration,
        distanceMeters: _trailService.distanceMeters,
      );
      await _trailService.stop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el trail.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaused = _trailService.isPaused;
    final isActive = _trailService.isActive;
    final isStarting = _trailService.isStarting;

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
                              onTap: _finishTrail,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: (_trailRowHeight - _trailButtonSize) / 2,
                          child: IgnorePointer(
                            ignoring: isStarting,
                            child: _TrailIconButton(
                              assetPath: isActive
                                  ? 'assets/icons/pause_trail.svg'
                                  : 'assets/icons/play_trail.svg',
                              tooltip: isStarting
                                  ? 'Obteniendo tu ubicación'
                                  : isActive
                                  ? 'Pausar trail'
                                  : 'Iniciar trail',
                              onTap: isActive
                                  ? _trailService.pause
                                  : _trailService.play,
                            ),
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