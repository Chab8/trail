import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/completed_trail.dart';
import '../models/trail_song.dart';
import 'trail_service.dart';

/// Biblioteca de trails finalizados. Se guardan y se leen directamente
/// de Supabase, para que sobrevivan un reinicio de la app.
class TrailLibraryService extends ChangeNotifier {
  TrailLibraryService._internal();
  static final TrailLibraryService instance = TrailLibraryService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<CompletedTrail>> getTrailsForUser(String userId) async {
    final data = await _client
        .from('trails')
        .select(
          'id, title, started_at, ended_at, distance_m, duration_seconds, gps_segments, '
          'trail_segments(track_id, track_name, artist, started_at)',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return data.map<CompletedTrail>((row) {
      final rawSegmentsSongs = row['trail_segments'] as List<dynamic>? ?? [];
      final songs = rawSegmentsSongs
          .whereType<Map<String, dynamic>>()
          .where((s) => (s['track_id'] as String? ?? '').isNotEmpty)
          .map(
            (s) => TrailSong(
              trackId: s['track_id'] as String? ?? '',
              title: s['track_name'] as String? ?? '',
              artist: s['artist'] as String? ?? '',
              startedAt: DateTime.parse(s['started_at'] as String),
            ),
          )
          .toList();

      final completedAtRaw = row['ended_at'] ?? row['started_at'];

      // Reconstruimos el trazado GPS a partir de la columna gps_segments:
      // una lista de segmentos, cada uno con puntos {lat, lon, ts, color}.
      // "color" es el color (ARGB) de la canción que sonaba en ese punto;
      // puede faltar en trails guardados antes de este cambio.
      final rawGpsSegments = row['gps_segments'] as List<dynamic>? ?? [];
      final gpsSegments = rawGpsSegments
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
                    colorValue: p['color'] as int?,
                  ),
                )
                .toList(),
          )
          .toList();

      return CompletedTrail(
        id: row['id'] as String,
        name: row['title'] as String? ?? 'Trail',
        songs: songs,
        completedAt: DateTime.parse(completedAtRaw as String),
        duration: Duration(
          seconds: (row['duration_seconds'] as num?)?.toInt() ?? 0,
        ),
        distanceMeters: (row['distance_m'] as num?)?.toDouble() ?? 0,
        segments: gpsSegments,
      );
    }).toList();
  }

  Future<String> getNextDefaultName() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('No hay una sesión iniciada.');

    final result =
        await _client.from('trails').select().eq('user_id', userId).count();

    return 'Trail #${result.count + 1}';
  }

  Future<void> addTrail({
    required String name,
    required List<TrailSong> songs,
    required List<List<TrailPoint>> segments,
    required Duration duration,
    required double distanceMeters,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('No hay una sesión iniciada.');

    final now = DateTime.now().toUtc();
    final trimmedName = name.trim();
    final title = trimmedName.isEmpty ? 'Trail' : trimmedName;

    // Aproximamos "started_at" restando la duración activa al momento de
    // guardar. No es exacto si hubo pausas largas, pero sirve como
    // referencia temporal razonable del trail.
    final tripStart = now.subtract(duration);

    // Convertimos los segmentos GPS a JSON simple para guardarlos en la
    // columna gps_segments de la tabla trails. Guardamos también el color
    // (ARGB) que tenía cada punto, para poder redibujar el trail más
    // adelante con los mismos colores que tuvo mientras se grababa.
    final segmentsJson = segments
        .map(
          (segment) => segment
              .map(
                (p) => {
                  'lat': p.latitude,
                  'lon': p.longitude,
                  'ts': p.recordedAt.millisecondsSinceEpoch,
                  if (p.colorValue != null) 'color': p.colorValue,
                },
              )
              .toList(),
        )
        .toList();

    final trailRow = await _client
        .from('trails')
        .insert({
          'user_id': userId,
          'title': title,
          'started_at': tripStart.toIso8601String(),
          'ended_at': now.toIso8601String(),
          'distance_m': distanceMeters,
          'duration_seconds': duration.inSeconds,
          'gps_segments': segmentsJson,
        })
        .select('id')
        .single();

    final trailId = trailRow['id'] as String;

    if (songs.isNotEmpty) {
      final sorted = [...songs]
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < sorted.length; i++) {
        final song = sorted[i];
        final segmentEnd =
            i + 1 < sorted.length ? sorted[i + 1].startedAt : now;
        rows.add({
          'trail_id': trailId,
          'track_id': song.trackId,
          'track_name': song.title,
          'artist': song.artist,
          'started_at': song.startedAt.toUtc().toIso8601String(),
          'ended_at': segmentEnd.toUtc().toIso8601String(),
        });
      }
      await _client.from('trail_segments').insert(rows);
    }

    notifyListeners();
  }
}