class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? editedAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.deliveredAt,
    this.readAt,
    this.editedAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      deliveredAt: map['delivered_at'] != null
          ? DateTime.parse(map['delivered_at'] as String)
          : null,
      readAt: map['read_at'] != null
          ? DateTime.parse(map['read_at'] as String)
          : null,
      editedAt: map['edited_at'] != null
          ? DateTime.parse(map['edited_at'] as String)
          : null,
    );
  }
}