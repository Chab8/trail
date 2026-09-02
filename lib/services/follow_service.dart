import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/follow_counts.dart';
import '../models/follow_relationship.dart';
import '../models/follow_request.dart';
import '../models/user_profile.dart';

/// Este servicio se encarga de todo lo relacionado a "seguir" usuarios:
/// seguir directo, mandar/responder solicitudes (para perfiles privados),
/// dejar de seguir, y contar seguidores/seguidos.
///
/// Los follows confirmados se guardan en la tabla `follows`. Las
/// solicitudes pendientes (para perfiles privados) se guardan en
/// `follow_requests`.
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

  /// Averigua la relación entre el usuario actual y [otherUserId]:
  /// ¿ya lo sigue, le mandó una solicitud, o ninguna de las dos?
  Future<FollowRelationship> getRelationship(String otherUserId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return FollowRelationship.none;

    final alreadyFollowing = await isFollowing(
      followerId: myId,
      followingId: otherUserId,
    );
    if (alreadyFollowing) return FollowRelationship.following;

    final pendingRequest = await _client
        .from('follow_requests')
        .select()
        .eq('requester_id', myId)
        .eq('target_id', otherUserId)
        .eq('status', 'pending')
        .maybeSingle();

    return pendingRequest != null
        ? FollowRelationship.requested
        : FollowRelationship.none;
  }

  /// El usuario actual empieza a seguir a [targetUserId] directamente.
  /// Solo funciona si el perfil de destino NO es privado (si lo es, la
  /// base de datos va a rechazar la operación).
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

  /// Le manda una solicitud de seguimiento a [targetUserId] (para usar
  /// cuando ese perfil es privado).
  Future<void> sendFollowRequest(String targetUserId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;

    await _client.from('follow_requests').insert({
      'requester_id': myId,
      'target_id': targetUserId,
    });
  }

  /// Cancela una solicitud de seguimiento que el usuario actual le mandó
  /// a [targetUserId] (por ejemplo, si toca de nuevo el botón "Requested").
  Future<void> cancelFollowRequest(String targetUserId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;

    await _client
        .from('follow_requests')
        .delete()
        .eq('requester_id', myId)
        .eq('target_id', targetUserId)
        .eq('status', 'pending');
  }

  /// Devuelve las solicitudes de seguimiento pendientes que OTRAS
  /// personas le mandaron al usuario actual (para mostrarlas en la
  /// pantalla de "Solicitudes de seguidor").
  Future<List<FollowRequest>> getPendingRequestsForMe() async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return [];

    final data = await _client
        .from('follow_requests')
        .select(
          'id, created_at, requester:profiles!follow_requests_requester_id_fkey(id, username, avatar_url)',
        )
        .eq('target_id', myId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return data.map((row) => FollowRequest.fromMap(row)).toList();
  }

  /// Acepta o rechaza una solicitud de seguimiento. Si se acepta, del
  /// lado del servidor se crea automáticamente el "follow" correspondiente.
  Future<void> respondToFollowRequest({
    required String requestId,
    required bool approve,
  }) async {
    await _client.rpc(
      'respond_to_follow_request',
      params: {'request_id': requestId, 'approve': approve},
    );
  }

  /// Cuenta cuántos seguidores tiene [userId] y a cuántos sigue.
  Future<FollowCounts> getFollowCounts(String userId) async {
    final results = await Future.wait([
      _client.from('follows').select().eq('following_id', userId).count(),
      _client.from('follows').select().eq('follower_id', userId).count(),
    ]);

    return FollowCounts(
      followersCount: results[0].count,
      followingCount: results[1].count,
    );
  }

  /// Lista de usuarios que siguen a [userId] (sus seguidores), del más
  /// reciente al más antiguo. Se usa en la pantalla "Seguidores/Siguiendo".
  Future<List<UserProfile>> getFollowers(String userId) async {
    final data = await _client
        .from('follows')
        .select(
          'follower:profiles!follows_follower_id_fkey(id, username, avatar_url, is_private)',
        )
        .eq('following_id', userId)
        .order('created_at', ascending: false);

    return data
        .map(
          (row) =>
              UserProfile.fromMap(row['follower'] as Map<String, dynamic>),
        )
        .toList();
  }

  /// Lista de usuarios a los que sigue [userId], del más reciente al más
  /// antiguo. Se usa en la pantalla "Seguidores/Siguiendo".
  Future<List<UserProfile>> getFollowing(String userId) async {
    final data = await _client
        .from('follows')
        .select(
          'following:profiles!follows_following_id_fkey(id, username, avatar_url, is_private)',
        )
        .eq('follower_id', userId)
        .order('created_at', ascending: false);

    return data
        .map(
          (row) =>
              UserProfile.fromMap(row['following'] as Map<String, dynamic>),
        )
        .toList();
  }

  /// IDs de todos los usuarios a los que sigue el usuario LOGUEADO
  /// actualmente. Sirve para, en una lista larga de personas (por
  /// ejemplo los seguidores de otro usuario), saber de una sola consulta
  /// a quiénes ya seguís, en vez de preguntarlo uno por uno.
  Future<Set<String>> getMyFollowingIds() async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return {};

    final data = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', myId);

    return data.map((row) => row['following_id'] as String).toSet();
  }

  /// IDs de los usuarios a los que el usuario LOGUEADO les mandó una
  /// solicitud de seguimiento todavía pendiente (perfiles privados que
  /// no te aprobaron todavía).
  Future<Set<String>> getMyPendingRequestIds() async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return {};

    final data = await _client
        .from('follow_requests')
        .select('target_id')
        .eq('requester_id', myId)
        .eq('status', 'pending');

    return data.map((row) => row['target_id'] as String).toSet();
  }
}