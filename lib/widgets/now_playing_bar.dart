import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/dominant_color_service.dart';
import '../services/spotify_service.dart';
import 'liquid_glass.dart';

/// Se muestra si hay una cuenta de Spotify conectada y una pista actual.
/// La pista sigue visible cuando Spotify queda en pausa.
class NowPlayingBar extends StatefulWidget {
  const NowPlayingBar({super.key});

  @override
  State<NowPlayingBar> createState() => _NowPlayingBarState();
}

class _NowPlayingBarState extends State<NowPlayingBar> {
  SpotifyNowPlaying? _track;
  bool _spotifyConnected = false;
  Timer? _timer;

  Color? _dominantColor;
  String? _colorUrl;

  @override
  void initState() {
    super.initState();

    _checkConnectionAndFetch();

    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetch(),
    );
  }

  Future<void> _checkConnectionAndFetch() async {
    final connected = await SpotifyService.instance.isConnected();

    if (!mounted) return;

    setState(() {
      _spotifyConnected = connected;
    });

    if (connected) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    if (!_spotifyConnected) return;

    final track =
        await SpotifyService.instance.getCurrentlyPlaying();

    if (!mounted) return;

    setState(() {
      _track = track;
    });

    // No hay canción.
    if (track == null || track.albumArtUrl == null) {
      if (mounted) {
        setState(() {
          _dominantColor = null;
          _colorUrl = null;
        });
      }

      return;
    }

    final imageUrl = track.albumArtUrl!;

    // La portada no cambió.
    if (_colorUrl == imageUrl) {
      return;
    }

    _colorUrl = imageUrl;

    final color =
        await DominantColorService.getColor(imageUrl);

    if (!mounted) return;

    // La canción cambió mientras procesábamos la imagen.
    if (_track?.albumArtUrl != imageUrl) {
      return;
    }

    if (color != null) {
      setState(() {
        _dominantColor = Color.fromARGB(
          color.alpha,
          color.red,
          color.green,
          color.blue,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_spotifyConnected || _track == null) {
      return const SizedBox.shrink();
    }

    final track = _track!;

    return LiquidGlass(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: track.albumArtUrl != null
                ? Image.network(
                    track.albumArtUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 40,
                    height: 40,
                    color: Colors.white.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.music_note,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.trackName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    shadows: [
                      Shadow(
                        color: Colors.black45,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          MiniSoundwave(
            isPlaying: track.isPlaying,
            color: _dominantColor ?? Colors.white,
          ),
        ],
      ),
    );
  }
}

class MiniSoundwave extends StatefulWidget {
  const MiniSoundwave({
    super.key,
    required this.isPlaying,
    required this.color,
  });

  final bool isPlaying;
  final Color color;

  @override
  State<MiniSoundwave> createState() => _MiniSoundwaveState();
}

class _MiniSoundwaveState extends State<MiniSoundwave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _barHeights = <double>[
    10,
    18,
    14,
    20,
    12,
    16,
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(
    covariant MiniSoundwave oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (widget.isPlaying && !oldWidget.isPlaying) {
      _controller.repeat();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        end: widget.color,
      ),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      builder: (context, color, child) {
        return SizedBox(
          width: 30,
          height: 22,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                crossAxisAlignment:
                    CrossAxisAlignment.center,
                children: List.generate(
                  _barHeights.length,
                  (index) {
                    final wave =
                        (1 +
                                math.sin(
                                  (_controller.value *
                                          math.pi *
                                          2) +
                                      index * 1.7,
                                )) /
                            2;

                    final height = widget.isPlaying
                        ? 7 +
                            ((_barHeights[index] - 7) *
                                wave)
                        : 3.5;

                    return Container(
                      width: 3.5,
                      height: height,
                      decoration: BoxDecoration(
                        color: color ?? Colors.white,
                        borderRadius:
                            BorderRadius.circular(999),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}