class UserProfile {
  final String id;
  final String username;
  final String? spotifyId;
  final String? avatarUrl;
  final bool isPrivate;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.username,
    this.spotifyId,
    this.avatarUrl,
    this.isPrivate = false,
    this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String,
      spotifyId: map['spotify_id'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      isPrivate: map['is_private'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }
}