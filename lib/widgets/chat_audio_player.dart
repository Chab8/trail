import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/chat_service.dart';

/// Reproductor que va dentro de la burbuja de un mensaje de audio:
/// botón de play/pausa, barra de progreso y duración.
class ChatAudioPlayer extends StatefulWidget {
  const ChatAudioPlayer({
    super.key,
    required this.audioPath,
    required this.durationMs,
    required this.color,
  });

  /// Ruta del archivo en el bucket privado `chat-audios`.
  final String audioPath;

  /// Duración guardada en el mensaje (se usa hasta que el audio carga).
  final int durationMs;

  /// Color del ícono, la barra y los textos (depende de la burbuja).
  final Color color;

  @override
  State<ChatAudioPlayer> createState() => _ChatAudioPlayerState();
}

class _ChatAudioPlayerState extends State<ChatAudioPlayer> {
  /// Reproductor que está sonando ahora, para pausarlo cuando se toca
  /// play en otro audio.
  static AudioPlayer? _activePlayer;

  final _chatService = ChatService();
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;

  bool _loaded = false;
  bool _loading = false;
  bool _playing = false;
  Duration _position = Duration.zero;

  Duration get _total => Duration(milliseconds: widget.durationMs);

  @override
  void initState() {
    super.initState();
    _stateSub = _player.playerStateStream.listen((state) async {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        await _player.pause();
        await _player.seek(Duration.zero);
        if (!mounted) return;
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      } else {
        setState(() => _playing = state.playing);
      }
    });
    _positionSub = _player.positionStream.listen((position) {
      if (!mounted || !_playing) return;
      setState(() => _position = position);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _positionSub?.cancel();
    if (identical(_activePlayer, _player)) _activePlayer = null;
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_loading) return;

    if (_playing) {
      await _player.pause();
      return;
    }

    try {
      if (!_loaded) {
        setState(() => _loading = true);
        final url = await _chatService.getAudioUrl(widget.audioPath);
        await _player.setUrl(url);
        _loaded = true;
      }
      if (!mounted) return;

      final active = _activePlayer;
      if (active != null && !identical(active, _player)) {
        await active.pause();
      }
      _activePlayer = _player;
      unawaited(_player.play());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reproducir el audio.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _seekTo(double fraction) async {
    if (!_loaded) return;
    final target = Duration(
      milliseconds: (_total.inMilliseconds * fraction).round(),
    );
    setState(() => _position = target);
    await _player.seek(target);
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.toString();
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _total.inMilliseconds <= 0 ? 1 : _total.inMilliseconds;
    final progress = (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    // Mientras suena se muestra el tiempo transcurrido; en reposo, el total.
    final shownTime = (_playing || _position > Duration.zero)
        ? _position
        : _total;

    return SizedBox(
      width: 210,
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 36,
              height: 36,
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.color,
                      ),
                    )
                  : Icon(
                      _playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 32,
                      color: widget.color,
                    ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                ),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: widget.color,
                inactiveTrackColor: widget.color.withValues(alpha: 0.3),
                thumbColor: widget.color,
              ),
              child: Slider(
                value: progress,
                onChanged: _seekTo,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _format(shownTime),
            style: TextStyle(
              color: widget.color.withValues(alpha: 0.8),
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}