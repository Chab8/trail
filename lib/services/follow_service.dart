import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/follow_counts.dart';

/// Este servicio se encarga de todo lo relacionado a "seguir" usuarios:
/// seguir, dejar de seguir, y contar seguidores/seguidos.
///
/// Toda la información se guarda en la tabla `follows` de Supabase, donde
/// cada fila significa "follower_id sigue a following_id".
class FollowService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Devuelve true si [followerId] ya sigue a [followingId].
  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    final row = await _client
        .from('follows')
        .select()
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();

    return row != null;
  }

  /// El usuario actual (el que está logueado) empieza a seguir a
  /// [targetUserId].
  Future<void> follow(String targetUserId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;

    await _client.from('follows').insert({
      'follower_id': myId,
      'following_id': targetUserId,
    });
  }

  /// El usuario actual deja de seguir a [targetUserId].
  Future<void> unfollow(String targetUserId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;

    await _client
        .from('follows')
        .delete()
        .eq('follower_id', myId)
        .eq('following_id', targetUserId);
  }

  /// Cuenta cuántos seguidores tiene [userId] y a cuántos sigue.
  ///
  /// Hacemos las dos consultas en paralelo (Future.wait) para que sea
  /// más rápido que pedirlas una después de la otra.
  Future<FollowCounts> getFollowCounts(String userId) async {
    final results = await Future.wait([
      // ¿Cuántas filas hay donde ESTE usuario es el "seguido"? = seguidores
      _client.from('follows').select().eq('following_id', userId).count(),
      // ¿Cuántas filas hay donde ESTE usuario es el que "sigue"? = seguidos
      _client.from('follows').select().eq('follower_id', userId).count(),
    ]);

    return FollowCounts(
      followersCount: results[0].count,
      followingCount: results[1].count,
    );
  }
}