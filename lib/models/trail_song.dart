/// Una canción que sonó mientras se registraba un trail.
class TrailSong {
  const TrailSong({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.startedAt,
  });

  final String trackId;
  final String title;
  final String artist;

  /// Momento en el que detectamos que esta canción empezó a sonar. Se usa
  /// para calcular cuántos minutos escuchaste a cada artista.
  final DateTime startedAt;

  Map<String, String> toMap() => {
    'track_id': trackId,
    'title': title,
    'artist': artist,
    'started_at': startedAt.toIso8601String(),
  };

  factory TrailSong.fromMap(Map<String, dynamic> map) => TrailSong(
    trackId: map['track_id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    artist: map['artist'] as String? ?? '',
    startedAt: map['started_at'] != null
        ? DateTime.parse(map['started_at'] as String)
        : DateTime.now(),
  );
}