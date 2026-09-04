import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/completed_trail.dart';
import '../models/trail_song.dart';

/// Biblioteca de trails finalizados, separada por el usuario que los grabó.
///
/// Por ahora mantiene el resumen en memoria, pero nunca mezcla los trails de
/// cuentas distintas. Esto también permite mostrar el historial al visitar el
/// perfil de otro usuario mientras la app sigue abierta.
class TrailLibraryService extends ChangeNotifier {
  TrailLibraryService._internal();
  static final TrailLibraryService instance = TrailLibraryService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  final Map<String, List<CompletedTrail>> _trailsByUser = {};

  Future<List<CompletedTrail>> getTrailsForUser(String userId) async {
    return List<CompletedTrail>.unmodifiable(_trailsByUser[userId] ?? const []);
  }

  Future<String> getNextDefaultName() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('No hay una sesión iniciada.');

    return 'Trail #${(_trailsByUser[userId]?.length ?? 0) + 1}';
  }

  Future<void> addTrail({
    required String name,
    required List<TrailSong> songs,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('No hay una sesión iniciada.');

    final userTrails = _trailsByUser.putIfAbsent(userId, () => []);
    final trimmedName = name.trim();
    userTrails.insert(
      0,
      CompletedTrail(
        name: trimmedName.isEmpty
            ? 'Trail #${userTrails.length + 1}'
            : trimmedName,
        songs: List<TrailSong>.unmodifiable(songs),
        completedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
