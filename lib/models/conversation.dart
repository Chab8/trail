class Conversation {
  final String id;
  final String otherUserId;
  final String otherUsername;
  final String? otherAvatarUrl;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherUsername,
    this.otherAvatarUrl,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.lastMessageSenderId,
    required this.unreadCount,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['conversation_id'] as String,
      otherUserId: map['other_user_id'] as String,
      otherUsername: map['other_username'] as String,
      otherAvatarUrl: map['other_avatar_url'] as String?,
      lastMessagePreview: map['last_message_preview'] as String?,
      lastMessageAt: map['last_message_at'] != null
          ? DateTime.parse(map['last_message_at'] as String)
          : null,
      lastMessageSenderId: map['last_message_sender_id'] as String?,
      unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}