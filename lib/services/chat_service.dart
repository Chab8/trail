import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conversation.dart';

/// Todo lo relacionado a mensajes 1 a 1 pasa por acá: listar tus chats,
/// crear/abrir un chat con otro usuario, mandar mensajes y marcarlos
/// como leídos.
///
/// La regla de "solo le podés escribir a quien seguís" se aplica del
/// lado de Supabase (función get_or_create_conversation), no acá. Así
/// que aunque alguien intente saltarse la app, la base de datos igual
/// lo bloquea.
class ChatService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Lista de mis conversaciones, de la más reciente a la más vieja,
  /// con el username/avatar del otro usuario y cuántos mensajes no
  /// leídos tengo en cada una.
  Future<List<Conversation>> getConversations() async {
    final data = await _client.rpc('get_conversations');
    return (data as List)
        .map((row) => Conversation.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Devuelve el id de la conversación con [otherUserId]. Si todavía no
  /// existe, la crea. Falla si no seguís a esa persona.
  Future<String> getOrCreateConversation(String otherUserId) async {
    final result = await _client.rpc(
      'get_or_create_conversation',
      params: {'p_other_user_id': otherUserId},
    );
    return result as String;
  }

  /// Stream en vivo con todos los mensajes de una conversación. Cada
  /// vez que alguien manda un mensaje nuevo (yo o la otra persona),
  /// este stream emite la lista completa actualizada.
  Stream<List<Map<String, dynamic>>> watchMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
  }

  Future<void> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;

    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': myId,
      'content': content,
    });
  }

  /// Marca como leídos todos los mensajes que me mandó la otra persona
  /// en esta conversación.
  Future<void> markConversationRead(String conversationId) async {
    await _client.rpc(
      'mark_conversation_read',
      params: {'p_conversation_id': conversationId},
    );
  }
}