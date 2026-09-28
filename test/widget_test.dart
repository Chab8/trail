import 'package:flutter_test/flutter_test.dart';
import 'package:trail/models/completed_trail.dart';
import 'package:trail/models/trail_song.dart';
import 'package:trail/services/trail_service.dart';

void main() {
  test('un Trail nuevo empieza sin recorrido registrado', () {
    final trail = TrailService.instance;

    expect(trail.status, TrailStatus.idle);
    expect(trail.segments, isEmpty);
  });

  test('conserva los rangos de cada canción desde el inicio del trail', () {
    final startedAt = DateTime(2026, 1, 1);
    final trail = CompletedTrail(
      id: 'trail-id',
      name: 'Trail',
      completedAt: startedAt.add(const Duration(minutes: 4)),
      duration: const Duration(minutes: 4),
      distanceMeters: 0,
      songs: [
        TrailSong(
          trackId: 'song-1',
          title: 'Song 1',
          artist: 'Artist',
          startedAt: startedAt,
          trailStartOffset: Duration.zero,
          trailEndOffset: const Duration(seconds: 30),
        ),
        TrailSong(
          trackId: 'song-2',
          title: 'Song 2',
          artist: 'Artist',
          startedAt: startedAt.add(const Duration(seconds: 30)),
          trailStartOffset: const Duration(seconds: 30),
          trailEndOffset: const Duration(minutes: 3, seconds: 24),
        ),
      ],
    );

    expect(trail.songStartOffsetAt(0), Duration.zero);
    expect(trail.songEndOffsetAt(0), const Duration(seconds: 30));
    expect(trail.songStartOffsetAt(1), const Duration(seconds: 30));
    expect(trail.songEndOffsetAt(1), const Duration(minutes: 3, seconds: 24));
  });
}
