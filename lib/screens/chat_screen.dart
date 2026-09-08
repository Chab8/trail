import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';
import 'user_profile_screen.dart';

/// Pantalla de conversación con otra persona, estilo WhatsApp: burbujas
/// de mensaje con tildes de enviado/recibido/visto, un campo de texto
/// abajo para escribir, actualización en vivo, y la posibilidad de
/// mantener apretado un mensaje propio para editarlo o borrarlo.
class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUsername;
  final String? otherAvatarUrl;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUsername,
    this.otherAvatarUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  bool _isSending = false;
  bool _didInitialScroll = false;

  String? get _myId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _messagesStream = _chatService.watchMessages(widget.conversationId);
    _chatService.markConversationRead(widget.conversationId);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversationId,
        content: text,
      );
      _scrollToBottomAfterFrame();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el mensaje.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottomNow({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  void _scrollToBottomAfterFrame({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottomNow(animate: animate);
    });
  }

  void _openOtherProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: widget.otherUserId),
      ),
    );
  }

  Future<void> _handleMessageLongPress(ChatMessage message) async {
    // Solo podés editar o borrar TUS PROPIOS mensajes.
    if (message.senderId != _myId) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar mensaje'),
              onTap: () => Navigator.of(sheetContext).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text(
                'Eliminar mensaje',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'edit') {
      await _showEditDialog(message);
    } else if (action == 'delete') {
      await _confirmDelete(message);
    }
  }

  Future<void> _showEditDialog(ChatMessage message) async {
    final controller = TextEditingController(text: message.content);

    final newContent = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar mensaje'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newContent == null ||
        newContent.isEmpty ||
        newContent == message.content) {
      return;
    }

    try {
      await _chatService.editMessage(
        messageId: message.id,
        newContent: newContent,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo editar el mensaje.')),
        );
      }
    }
  }

  Future<void> _confirmDelete(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar este mensaje?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _chatService.deleteMessage(message.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el mensaje.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar =
        widget.otherAvatarUrl != null && widget.otherAvatarUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _openOtherProfile,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF3A3A3A),
                backgroundImage:
                    hasAvatar ? NetworkImage(widget.otherAvatarUrl!) : null,
                child: hasAvatar
                    ? null
                    : const Icon(Icons.person, size: 18, color: Colors.white70),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '@${widget.otherUsername}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!
                      .map((row) => ChatMessage.fromMap(row))
                      .toList();

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_didInitialScroll && messages.isNotEmpty) {
                      _didInitialScroll = true;
                      _scrollToBottomNow(animate: false);
                    } else if (_scrollController.hasClients &&
                        _scrollController.position.pixels >=
                            _scrollController.position.maxScrollExtent - 80) {
                      _scrollToBottomNow();
                    }

                    final hasUnreadFromOther = messages.any(
                      (m) => m.senderId != _myId && m.readAt == null,
                    );
                    if (hasUnreadFromOther) {
                      _chatService.markConversationRead(widget.conversationId);
                    }
                  });

                  if (messages.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'Todavía no hay mensajes. ¡Decí hola!',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMine = message.senderId == _myId;
                      return _MessageBubble(
                        message: message,
                        isMine: isMine,
                        onLongPress: isMine
                            ? () => _handleMessageLongPress(message)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.viewInsetsOf(context).bottom > 0 ? 8 : 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escribí un mensaje...',
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isSending ? null : _send,
            icon: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_upward),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final VoidCallback? onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFF3A3A3A);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.content,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.editedAt != null) ...[
                    Text(
                      'editado',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    _StatusTicks(message: message),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Las tildes de estado, como en WhatsApp:
/// - 1 tilde gris: el mensaje se envió.
/// - 2 tildes grises: la otra persona lo recibió.
/// - 2 tildes celestes: la otra persona lo vio.
class _StatusTicks extends StatelessWidget {
  final ChatMessage message;

  const _StatusTicks({required this.message});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;

    if (message.readAt != null) {
      icon = Icons.done_all;
      color = const Color(0xFF34B7F1);
    } else if (message.deliveredAt != null) {
      icon = Icons.done_all;
      color = Colors.white.withValues(alpha: 0.65);
    } else {
      icon = Icons.done;
      color = Colors.white.withValues(alpha: 0.65);
    }

    return Icon(icon, size: 14, color: color);
  }
}