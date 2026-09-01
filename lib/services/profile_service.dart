import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Chequea si un nombre de usuario ya está tomado, ANTES de crear la cuenta.
  Future<bool> isUsernameTaken(String username) async {
    final result = await _client.rpc(
      'is_username_taken',
      params: {'p_username': username},
    );
    return result as bool;
  }

  Future<void> createProfile({
    required String userId,
    required String username,
  }) async {
    await _client.from('profiles').insert({
      'id': userId,
      'username': username,
    });
  }

  Future<UserProfile?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return UserProfile.fromMap(data);
  }

  Future<void> updateUsername({
    required String userId,
    required String username,
  }) async {
    await _client.from('profiles').update({'username': username}).eq('id', userId);
  }

  Future<void> updateAvatarUrl({
    required String userId,
    required String avatarUrl,
  }) async {
    await _client.from('profiles').update({'avatar_url': avatarUrl}).eq('id', userId);
  }

  /// Busca usuarios cuyo nombre de usuario contenga [query] (sin importar
  /// mayúsculas/minúsculas). Por ejemplo, buscar "ana" encuentra a "Ana99",
  /// "SantiAna", etc.
  ///
  /// Si se pasa [excludeUserId], ese usuario no aparece en los resultados
  /// (lo usamos para no mostrarte a vos mismo en tu propia búsqueda).
  Future<List<UserProfile>> searchUsersByUsername(
    String query, {
    String? excludeUserId,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final baseQuery = _client
        .from('profiles')
        .select()
        .ilike('username', '%$trimmed%');

    final filteredQuery = excludeUserId == null
        ? baseQuery
        : baseQuery.neq('id', excludeUserId);

    final data = await filteredQuery
        .order('username', ascending: true)
        .limit(20);

    return data.map((row) => UserProfile.fromMap(row)).toList();
  }
}