/// Una solicitud de seguimiento pendiente, con los datos del usuario
/// que la mandó (para poder mostrarla en una lista).
class FollowRequest {
  final String id;
  final String requesterId;
  final String requesterUsername;
  final String? requesterAvatarUrl;
  final DateTime createdAt;

  FollowRequest({
    required this.id,
    required this.requesterId,
    required this.requesterUsername,
    this.requesterAvatarUrl,
    required this.createdAt,
  });

  factory FollowRequest.fromMap(Map<String, dynamic> map) {
    final requester = map['requester'] as Map<String, dynamic>;
    return FollowRequest(
      id: map['id'] as String,
      requesterId: requester['id'] as String,
      requesterUsername: requester['username'] as String,
      requesterAvatarUrl: requester['avatar_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}