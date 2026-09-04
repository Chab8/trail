import 'trail_song.dart';

/// El resumen que se muestra en el perfil para un trail finalizado.
///
/// Por ahora sólo conserva su nombre y las canciones escuchadas. Más adelante
/// se le pueden sumar el trazado, duración, privacidad y otros metadatos.
class CompletedTrail {
  const CompletedTrail({
    required this.name,
    required this.songs,
    required this.completedAt,
  });

  final String name;
  final List<TrailSong> songs;
  final DateTime completedAt;

  factory CompletedTrail.fromMap(Map<String, dynamic> map) {
    final rawSongs = map['songs'] as List<dynamic>? ?? [];
    return CompletedTrail(
      name: map['name'] as String? ?? 'Trail',
      songs: rawSongs
          .whereType<Map<String, dynamic>>()
          .map(TrailSong.fromMap)
          .toList(growable: false),
      completedAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
