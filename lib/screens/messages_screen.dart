import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conversation.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import 'user_search_screen.dart';

/// Pantalla de "Mensajes": la lista de tus conversaciones, como en
/// cualquier app de chat. Para empezar una conversación nueva, tocá el
/// ícono de arriba a la derecha, que te lleva a buscar usuarios.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _chatService = ChatService();

  bool _isLoading = true;
  String? _errorMessage;
  List<Conversation> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final conversations = await _chatService.getConversations();
      if (!mounted) return;
      setState(() => _conversations = conversations);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'No se pudieron cargar tus chats.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openNewChatSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UserSearchScreen()),
    );
    if (mounted) _loadConversations();
  }

  Future<void> _openChat(Conversation conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversation.id,
          otherUserId: conversation.otherUserId,
          otherUsername: conversation.otherUsername,
          otherAvatarUrl: conversation.otherAvatarUrl,
        ),
      ),
    );
    if (mounted) _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square),
            tooltip: 'Nuevo mensaje',
            onPressed: _openNewChatSearch,
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Todavía no tenés conversaciones.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _openNewChatSearch,
                child: const Text('Buscar a alguien'),
              ),
            ],
          ),
        ),
      );
    }

    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 116;
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: bottomPadding),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          final hasAvatar = conversation.otherAvatarUrl != null &&
              conversation.otherAvatarUrl!.isNotEmpty;
          final isMine = conversation.lastMessageSenderId == myId;
          final hasUnread = conversation.unreadCount > 0;

          return ListTile(
            leading: CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF3A3A3A),
              backgroundImage: hasAvatar
                  ? NetworkImage(conversation.otherAvatarUrl!)
                  : null,
              child: hasAvatar
                  ? null
                  : const Icon(Icons.person, color: Colors.white70),
            ),
            title: Text(
              '@${conversation.otherUsername}',
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              conversation.lastMessagePreview == null
                  ? 'Empezá la conversación'
                  : isMine
                      ? 'Vos: ${conversation.lastMessagePreview}'
                      : conversation.lastMessagePreview!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            trailing: hasUnread
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${conversation.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
                : null,
            onTap: () => _openChat(conversation),
          );
        },
      ),
    );
  }
}