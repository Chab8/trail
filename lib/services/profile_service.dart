import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

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
}