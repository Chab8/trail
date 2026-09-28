import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final _chatService = ChatService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late final AnimationController _composerController;

  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  bool _isSending = false;
  bool _didInitialScroll = false;

  String? get _myId => Supabase.instance.client.auth.currentUser?.id;
  bool get _hasDraft => _textController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _messagesStream = _chatService.watchMessages(widget.conversationId);
    _chatService.markConversationRead(widget.conversationId);
    _composerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() => setState(() {}));
    _textController.addListener(_onDraftChanged);
  }

  void _onDraftChanged() {
    if (_hasDraft) {
      _composerController.forward();
    } else {
      _composerController.reverse();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _composerController.dispose();
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
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
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
      body: Stack(
        children: [
          SafeArea(
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
                                _scrollController.position.maxScrollExtent -
                                    80) {
                          _scrollToBottomNow();
                        }

                        final hasUnreadFromOther = messages.any(
                          (m) => m.senderId != _myId && m.readAt == null,
                        );
                        if (hasUnreadFromOther) {
                          _chatService.markConversationRead(
                            widget.conversationId,
                          );
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
          // Cabecera sobre el contenido: comienza en el borde superior de la
          // pantalla y deja los controles del AppBar visibles por encima.
          const IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: double.infinity,
                height: 144,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF09080B), Color(0x0009080B)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    SizedBox(
                      width: 55,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).maybePop(),
                            behavior: HitTestBehavior.opaque,
                            child: const _HeaderButtonSvg(
                              'assets/buttons/back button.svg',
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: _openOtherProfile,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 39,
                              height: 39,
                              child: CircleAvatar(
                                radius: 19.5,
                                backgroundColor: const Color(0xFF3A3A3A),
                                backgroundImage: hasAvatar
                                    ? NetworkImage(widget.otherAvatarUrl!)
                                    : null,
                                child: hasAvatar
                                    ? null
                                    : const Icon(
                                        Icons.person,
                                        size: 18,
                                        color: Colors.white70,
                                      ),
                              ),
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
                    const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: _HeaderButtonSvg('assets/buttons/call button.svg'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.viewInsetsOf(context).bottom > 0 ? 8 : 16,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const actionSize = 33.0;
          const gap = 10.0;
          const hiddenActionsWidth = (actionSize + gap) * 2;
          final collapsedInputWidth = (constraints.maxWidth - 129)
              .clamp(0.0, 220.0)
              .toDouble();
          final groupWidth = collapsedInputWidth + 129;
          final progress = Curves.easeInOut.transform(
            _composerController.value,
          );
          final inputWidth =
              collapsedInputWidth + (hiddenActionsWidth * progress);
          final trailingOpacity = 1 - Curves.easeIn.transform(progress);

          return Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: groupWidth,
              height: actionSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: inputWidth,
                    height: actionSize,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0x805B5A5F),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Center(
                        child: TextField(
                          controller: _textController,
                          minLines: 1,
                          maxLines: 1,
                          textAlignVertical: TextAlignVertical.center,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                            color: Color(0xFFFEFEFE),
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: inputWidth + gap,
                    child: IgnorePointer(
                      ignoring: progress > 0.05,
                      child: Opacity(
                        opacity: trailingOpacity,
                        child: const _ChatActionButton(
                          assetPath: 'assets/buttons/trail button.svg',
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left:
                        collapsedInputWidth +
                        gap +
                        actionSize +
                        gap +
                        ((actionSize + gap) * progress),
                    child: IgnorePointer(
                      ignoring: progress > 0.05,
                      child: Opacity(
                        opacity: trailingOpacity,
                        child: const _ChatActionButton(
                          assetPath: 'assets/buttons/camera button.svg',
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: _ChatActionButton(
                      assetPath: _hasDraft
                          ? 'assets/buttons/send button.svg'
                          : 'assets/buttons/microphone button.svg',
                      onTap: _hasDraft && !_isSending ? _send : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Los SVG de acciones tienen un canvas grande para su sombra. Esta ventana
/// conserva el círculo visible en exactamente 33×33 px.
class _ChatActionButton extends StatelessWidget {
  const _ChatActionButton({required this.assetPath, this.onTap});

  final String assetPath;
  final VoidCallback? onTap;

  double get _assetWidth {
    switch (assetPath) {
      case 'assets/buttons/send button.svg':
        return 93;
      case 'assets/buttons/microphone button.svg':
        return 88;
      default:
        return 113;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRect(
        child: SizedBox(
          width: 33,
          height: 33,
          child: OverflowBox(
            maxWidth: _assetWidth,
            maxHeight: 103,
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: const Offset(-40, -32),
              child: SvgPicture.asset(
                assetPath,
                width: _assetWidth,
                height: 103,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El SVG incluye el espacio de su sombra; se recorta el círculo central a
/// un botón de 39×39 px.
class _HeaderButtonSvg extends StatelessWidget {
  const _HeaderButtonSvg(this.assetPath);

  final String assetPath;

  double get _assetWidth =>
      assetPath == 'assets/buttons/call button.svg' ? 99 : 119;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: 39,
        height: 39,
        child: OverflowBox(
          maxWidth: _assetWidth,
          maxHeight: 119,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: const Offset(-40, -32),
            child: SvgPicture.asset(assetPath, width: _assetWidth, height: 119),
          ),
        ),
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
        ? const Color(0xFF654CDD)
        : const Color(0xFFFEFEFE);
    final textColor = isMine
        ? const Color(0xFFFEFEFE)
        : const Color(0xFF151515);

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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message.content, style: TextStyle(color: textColor)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.editedAt != null) ...[
                    Text(
                      'editado',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.55),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.65),
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
