import 'trail_song.dart';
import '../services/trail_service.dart';

/// El resumen que se muestra en el perfil para un trail finalizado.
///
/// Conserva el nombre, las canciones escuchadas y el trazado GPS del
/// recorrido dividido en segmentos (cada pausa genera un segmento nuevo).
class CompletedTrail {
  const CompletedTrail({
    required this.name,
    required this.songs,
    required this.completedAt,
    this.segments = const [],
  });

  final String name;
  final List<TrailSong> songs;
  final DateTime completedAt;

  /// Segmentos del recorrido GPS. Cada segmento es una lista de puntos
  /// consecutivos; los segmentos separados indican que el trail estuvo
  /// pausado entre ambos.
  final List<List<TrailPoint>> segments;

  factory CompletedTrail.fromMap(Map<String, dynamic> map) {
    final rawSongs = map['songs'] as List<dynamic>? ?? [];
    final rawSegments = map['segments'] as List<dynamic>? ?? [];

    return CompletedTrail(
      name: map['name'] as String? ?? 'Trail',
      songs: rawSongs
          .whereType<Map<String, dynamic>>()
          .map(TrailSong.fromMap)
          .toList(growable: false),
      completedAt: DateTime.parse(map['created_at'] as String),
      segments: rawSegments
          .whereType<List<dynamic>>()
          .map(
            (segment) => segment
                .whereType<Map<String, dynamic>>()
                .map(
                  (p) => TrailPoint(
                    latitude: (p['lat'] as num).toDouble(),
                    longitude: (p['lon'] as num).toDouble(),
                    recordedAt: DateTime.fromMillisecondsSinceEpoch(
                      p['ts'] as int? ?? 0,
                    ),
                  ),
                )
                .toList(growable: false),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'songs': songs.map((s) => s.toMap()).toList(),
        'created_at': completedAt.toIso8601String(),
        'segments': segments
            .map(
              (segment) => segment
                  .map(
                    (p) => {
                      'lat': p.latitude,
                      'lon': p.longitude,
                      'ts': p.recordedAt.millisecondsSinceEpoch,
                    },
                  )
                  .toList(),
            )
            .toList(),
      };
}
