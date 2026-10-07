class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? editedAt;

  /// 'text' o 'audio'.
  final String messageType;

  /// Ruta del archivo dentro del bucket privado `chat-audios`
  /// (solo para mensajes de audio).
  final String? audioPath;

  /// Duración del audio en milisegundos (solo para mensajes de audio).
  final int? audioDurationMs;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.deliveredAt,
    this.readAt,
    this.editedAt,
    this.messageType = 'text',
    this.audioPath,
    this.audioDurationMs,
  });

  bool get isAudio => messageType == 'audio' && audioPath != null;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      content: (map['content'] as String?) ?? '',
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
      messageType: (map['message_type'] as String?) ?? 'text',
      audioPath: map['audio_path'] as String?,
      audioDurationMs: (map['audio_duration_ms'] as num?)?.toInt(),
    );
  }
}