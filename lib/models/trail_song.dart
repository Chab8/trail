/// Una canción que sonó mientras se registraba un trail.
class TrailSong {
  const TrailSong({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.startedAt,
    this.trailStartOffset = Duration.zero,
    this.trailEndOffset,
  });

  final String trackId;
  final String title;
  final String artist;

  /// Momento en el que detectamos que esta canción empezó a sonar. Se usa
  /// para calcular cuántos minutos escuchaste a cada artista.
  final DateTime startedAt;

  /// Instante de inicio dentro del tiempo activo del trail. A diferencia de
  /// [startedAt], este valor no incluye los intervalos en pausa.
  final Duration trailStartOffset;

  /// Instante de finalización dentro del tiempo activo del trail. Es nulo
  /// mientras la canción sigue sonando durante el registro.
  final Duration? trailEndOffset;

  TrailSong copyWith({Duration? trailEndOffset}) => TrailSong(
    trackId: trackId,
    title: title,
    artist: artist,
    startedAt: startedAt,
    trailStartOffset: trailStartOffset,
    trailEndOffset: trailEndOffset ?? this.trailEndOffset,
  );

  Map<String, dynamic> toMap() => {
    'track_id': trackId,
    'title': title,
    'artist': artist,
    'started_at': startedAt.toIso8601String(),
    'trail_start_offset_ms': trailStartOffset.inMilliseconds,
    if (trailEndOffset != null)
      'trail_end_offset_ms': trailEndOffset!.inMilliseconds,
  };

  factory TrailSong.fromMap(Map<String, dynamic> map) => TrailSong(
    trackId: map['track_id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    artist: map['artist'] as String? ?? '',
    startedAt: map['started_at'] != null
        ? DateTime.parse(map['started_at'] as String)
        : DateTime.now(),
    trailStartOffset: Duration(
      milliseconds: (map['trail_start_offset_ms'] as num?)?.toInt() ?? 0,
    ),
    trailEndOffset: map['trail_end_offset_ms'] == null
        ? null
        : Duration(
            milliseconds: (map['trail_end_offset_ms'] as num?)?.toInt() ?? 0,
          ),
  );
}
