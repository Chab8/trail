/// Una canción que sonó mientras se registraba un trail.
class TrailSong {
  const TrailSong({
    required this.trackId,
    required this.title,
    required this.artist,
  });

  final String trackId;
  final String title;
  final String artist;

  Map<String, String> toMap() => {
    'track_id': trackId,
    'title': title,
    'artist': artist,
  };

  factory TrailSong.fromMap(Map<String, dynamic> map) => TrailSong(
    trackId: map['track_id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    artist: map['artist'] as String? ?? '',
  );
}
