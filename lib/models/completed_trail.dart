import 'trail_song.dart';
import '../services/trail_service.dart';

/// El resumen que se muestra en el perfil para un trail finalizado.
///
/// Conserva el nombre, las canciones escuchadas, el trazado GPS del
/// recorrido (dividido en segmentos: cada pausa genera un segmento nuevo),
/// la duración activa y la distancia recorrida.
class CompletedTrail {
  const CompletedTrail({
    required this.name,
    required this.songs,
    required this.completedAt,
    required this.duration,
    required this.distanceMeters,
    this.segments = const [],
  });

  final String name;
  final List<TrailSong> songs;
  final DateTime completedAt;

  /// Tiempo total que el trail estuvo activo (sin contar las pausas).
  final Duration duration;

  /// Distancia total recorrida durante el trail, en metros.
  final double distanceMeters;

  /// Segmentos del recorrido GPS. Cada segmento es una lista de puntos
  /// consecutivos; los segmentos separados indican que el trail estuvo
  /// pausado entre ambos.
  final List<List<TrailPoint>> segments;

  /// El artista al que más minutos le dedicaste durante este trail, o
  /// null si no hay datos suficientes para calcularlo.
  String? get topArtist {
    final totals = _artistListeningTotals();
    if (totals.isEmpty) return null;
    return totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Suma, por artista, cuánto tiempo estuvo sonando durante los tramos
  /// en los que el trail estuvo efectivamente grabando (sin contar pausas).
  Map<String, Duration> _artistListeningTotals() {
    if (songs.isEmpty || segments.isEmpty) return {};

    final activeSpans = segments
        .where((segment) => segment.length >= 2)
        .map((segment) => _TimeSpan(segment.first.recordedAt, segment.last.recordedAt))
        .toList();
    if (activeSpans.isEmpty) return {};

    final trailEnd = activeSpans.last.end;
    final totals = <String, Duration>{};

    for (var i = 0; i < songs.length; i++) {
      final start = songs[i].startedAt;
      final end = i + 1 < songs.length ? songs[i + 1].startedAt : trailEnd;
      if (!end.isAfter(start)) continue;

      final songSpan = _TimeSpan(start, end);
      for (final active in activeSpans) {
        final overlap = songSpan.overlapWith(active);
        if (overlap == null) continue;
        totals.update(
          songs[i].artist,
          (value) => value + overlap,
          ifAbsent: () => overlap,
        );
      }
    }
    return totals;
  }

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
      duration: Duration(seconds: map['duration_seconds'] as int? ?? 0),
      distanceMeters: (map['distance_meters'] as num?)?.toDouble() ?? 0,
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
        'duration_seconds': duration.inSeconds,
        'distance_meters': distanceMeters,
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

/// Representa un intervalo de tiempo, usado para calcular cuánto se
/// superponen las canciones escuchadas con los tramos activos del trail.
class _TimeSpan {
  _TimeSpan(this.start, this.end);

  final DateTime start;
  final DateTime end;

  Duration? overlapWith(_TimeSpan other) {
    final overlapStart = start.isAfter(other.start) ? start : other.start;
    final overlapEnd = end.isBefore(other.end) ? end : other.end;
    if (!overlapEnd.isAfter(overlapStart)) return null;
    return overlapEnd.difference(overlapStart);
  }
}