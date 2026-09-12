import 'package:supabase_flutter/supabase_flutter.dart';

/// Se encarga de todo lo relacionado a los likes de un trail: contar
/// cuántos tiene, saber si el usuario actual ya le dio like, y
/// dárselo o sacárselo.
class TrailLikeService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Cuenta cuántos likes tiene un trail.
  Future<int> getLikeCount(String trailId) async {
    final result = await _client
        .from('trail_likes')
        .select()
        .eq('trail_id', trailId)
        .count();
    return result.count;
  }

  /// True si el usuario actual ya le dio like a este trail.
  Future<bool> hasLiked(String trailId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final row = await _client
        .from('trail_likes')
        .select('trail_id')
        .eq('trail_id', trailId)
        .eq('user_id', userId)
        .maybeSingle();

    return row != null;
  }

  /// Le da like al trail en nombre del usuario actual.
  Future<void> like(String trailId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('trail_likes').insert({
      'trail_id': trailId,
      'user_id': userId,
    });
  }

  /// Saca el like que el usuario actual le había dado al trail.
  Future<void> unlike(String trailId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('trail_likes')
        .delete()
        .eq('trail_id', trailId)
        .eq('user_id', userId);
  }
}