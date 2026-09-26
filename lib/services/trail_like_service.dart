import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Estado de likes de un trail cacheado en memoria.
class _LikeState {
  _LikeState({required this.count, required this.isLiked});
  int count;
  bool isLiked;
}

/// Se encarga de todo lo relacionado a los likes de un trail: contar
/// cuántos tiene, saber si el usuario actual ya le dado like, y
/// dárselo o sacárselo.
///
/// Mantiene un caché en memoria (singleton) para que todas las instancias
/// de [TrailLikeButton] que muestren el mismo trail compartan el estado y
/// no tengan que volver a consultar Supabase cada vez que se rearman.
class TrailLikeService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final TrailLikeService _instance = TrailLikeService._internal();
  factory TrailLikeService() => _instance;
  TrailLikeService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  /// Stream que emite el trailId cada vez que su estado de like cambia.
  /// Todos los [TrailLikeButton] montados pueden escucharlo para reconstruirse.
  final _changesController = StreamController<String>.broadcast();
  Stream<String> get changes => _changesController.stream;

  /// Caché en memoria: trailId → _LikeState.
  final Map<String, _LikeState> _cache = {};

  // ── Lectura con caché ──────────────────────────────────────────────────────

  /// Devuelve `true` si el estado de este trail ya está en caché.
  bool isCached(String trailId) => _cache.containsKey(trailId);

  /// Estado cacheado para un trail. Solo llamar si [isCached] es `true`.
  (int count, bool isLiked) getCached(String trailId) {
    final s = _cache[trailId]!;
    return (s.count, s.isLiked);
  }

  /// Carga el estado desde Supabase y lo guarda en caché.
  /// Si ya hay caché, devuelve el valor cacheado sin ir a la red.
  Future<(int count, bool isLiked)> fetchLikeInfo(String trailId) async {
    if (_cache.containsKey(trailId)) {
      final s = _cache[trailId]!;
      return (s.count, s.isLiked);
    }

    final results = await Future.wait([
      _getLikeCount(trailId),
      _hasLiked(trailId),
    ]);

    final state = _LikeState(
      count: results[0] as int,
      isLiked: results[1] as bool,
    );
    _cache[trailId] = state;
    return (state.count, state.isLiked);
  }

  // ── Mutaciones ─────────────────────────────────────────────────────────────

  /// Actualiza el caché optimistamente **antes** de ir a la red.
  /// Llama esto primero; si la operación de red falla, usá [revertLike].
  void applyOptimisticLike(String trailId, {required bool liked}) {
    final s = _cache[trailId];
    if (s == null) return;
    s.isLiked = liked;
    s.count = liked ? s.count + 1 : s.count - 1;
    _changesController.add(trailId);
  }

  /// Revierte el caché al estado anterior si la operación de red falló.
  void revertLike(String trailId, {required bool wasLiked, required int previousCount}) {
    final s = _cache[trailId];
    if (s == null) return;
    s.isLiked = wasLiked;
    s.count = previousCount;
    _changesController.add(trailId);
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

  // ── Privados ───────────────────────────────────────────────────────────────

  Future<int> _getLikeCount(String trailId) async {
    final result = await _client
        .from('trail_likes')
        .select()
        .eq('trail_id', trailId)
        .count();
    return result.count;
  }

  Future<bool> _hasLiked(String trailId) async {
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
}