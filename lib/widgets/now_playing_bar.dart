import 'dart:async';
import 'package:flutter/material.dart';
import '../services/spotify_service.dart';

/// Se muestra sola solamente si hay una cuenta de Spotify conectada
/// Y hay algo sonando en este momento. Si no, no ocupa espacio.
class NowPlayingBar extends StatefulWidget {
  const NowPlayingBar({super.key});

  @override
  State<NowPlayingBar> createState() => _NowPlayingBarState();
}

class _NowPlayingBarState extends State<NowPlayingBar> {
  SpotifyNowPlaying? _track;
  bool _spotifyConnected = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkConnectionAndFetch();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _fetch());
  }

  Future<void> _checkConnectionAndFetch() async {
    final connected = await SpotifyService.instance.isConnected();
    if (!mounted) return;
    setState(() => _spotifyConnected = connected);
    if (connected) _fetch();
  }

  Future<void> _fetch() async {
    if (!_spotifyConnected) return;
    final track = await SpotifyService.instance.getCurrentlyPlaying();
    if (mounted) setState(() => _track = track);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: track.albumArtUrl != null
                ? Image.network(track.albumArtUrl!, width: 36, height: 36, fit: BoxFit.cover)
                : Container(width: 36, height: 36, color: Colors.white24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.trackName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.graphic_eq, color: Colors.greenAccent, size: 20),
        ],
      ),
    );
  }
}