import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conversation.dart';

/// Todo lo relacionado a mensajes 1 a 1 pasa por acá: listar tus chats,
/// crear/abrir un chat con otro usuario, mandar mensajes, marcarlos
/// como recibidos/leídos, y editar o borrar los tuyos.
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
  /// vez que alguien manda, edita o borra un mensaje (yo o la otra
  /// persona), o cambia su estado de recibido/leído, este stream emite
  /// la lista completa actualizada.
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

  /// Cambia el texto de un mensaje mío. Solo funciona con mensajes
  /// propios (lo controla una política de seguridad en Supabase).
  Future<void> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    await _client.from('messages').update({
      'content': newContent,
      'edited_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', messageId);
  }

  /// Borra un mensaje mío. Solo funciona con mensajes propios.
  Future<void> deleteMessage(String messageId) async {
    await _client.from('messages').delete().eq('id', messageId);
  }

  /// Marca como leídos todos los mensajes que me mandó la otra persona
  /// en esta conversación (también los marca como recibidos, por las
  /// dudas).
  Future<void> markConversationRead(String conversationId) async {
    await _client.rpc(
      'mark_conversation_read',
      params: {'p_conversation_id': conversationId},
    );
  }

  /// Marca como "recibidos" (2 tildes grises) todos los mensajes que me
  /// mandaron en cualquier conversación. La llamamos cada vez que la
  /// app sincroniza la lista de chats, simulando que "me llegaron".
  Future<void> markAllReceived() async {
    try {
      await _client.rpc('mark_all_received');
    } catch (_) {
      // Si esto falla no es grave: no bloqueamos la carga de la lista.
    }
  }
}