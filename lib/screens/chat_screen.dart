import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../widgets/chat_audio_player.dart';
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

  // Grabación de audio.
  static const Duration _minAudioDuration = Duration(seconds: 1);
  static const Duration _maxAudioDuration = Duration(minutes: 5);
  final AudioRecorder _recorder = AudioRecorder();
  final Stopwatch _recordStopwatch = Stopwatch();
  Timer? _recordTicker;
  String? _recordPath;
  bool _isRecording = false;
  bool _isStoppingRecording = false;
  Duration _recordElapsed = Duration.zero;

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
    _recordTicker?.cancel();
    final recorder = _recorder;
    final pendingPath = _recordPath;
    unawaited(() async {
      try {
        if (await recorder.isRecording()) await recorder.cancel();
      } catch (_) {}
      await recorder.dispose();
      if (pendingPath != null) _deleteTempFile(pendingPath);
    }());
    _textController.dispose();
    _scrollController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _deleteTempFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  /// Toca el micrófono: pide permiso (la primera vez) y empieza a grabar.
  Future<void> _startRecording() async {
    if (_isRecording || _isSending) return;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _showSnack(
          'Necesitás permitir el uso del micrófono para grabar audios. '
          'Podés activarlo en los ajustes del teléfono.',
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/trail_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      _recordPath = path;
      _recordStopwatch
        ..reset()
        ..start();
      _recordTicker?.cancel();
      _recordTicker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        final elapsed = _recordStopwatch.elapsed;
        if (elapsed >= _maxAudioDuration) {
          // Llegó al máximo: se corta y se envía solo.
          _stopRecordingAndSend();
          return;
        }
        setState(() => _recordElapsed = elapsed);
      });

      setState(() {
        _isRecording = true;
        _recordElapsed = Duration.zero;
      });
    } catch (e) {
      _showSnack('No se pudo empezar a grabar el audio.');
    }
  }

  /// Corta la grabación y devuelve (archivo, duración), o null si falló.
  Future<(File, Duration)?> _finishRecording() async {
    _recordTicker?.cancel();
    _recordStopwatch.stop();
    final duration = _recordStopwatch.elapsed;

    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    path ??= _recordPath;

    _recordPath = null;
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordElapsed = Duration.zero;
      });
    }

    if (path == null) return null;
    return (File(path), duration);
  }

  /// Toca la papelera: descarta la grabación sin enviar nada.
  Future<void> _cancelRecording() async {
    if (!_isRecording || _isStoppingRecording) return;
    _isStoppingRecording = true;
    try {
      final result = await _finishRecording();
      if (result != null) _deleteTempFile(result.$1.path);
    } finally {
      _isStoppingRecording = false;
    }
  }

  /// Toca enviar durante la grabación: corta, sube el audio y lo envía.
  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording || _isStoppingRecording) return;
    _isStoppingRecording = true;

    final result = await _finishRecording();
    _isStoppingRecording = false;
    if (result == null) {
      _showSnack('No se pudo guardar el audio.');
      return;
    }
    final (file, duration) = result;

    if (duration < _minAudioDuration) {
      _deleteTempFile(file.path);
      _showSnack('El audio es muy corto. Grabá al menos 1 segundo.');
      return;
    }

    if (mounted) setState(() => _isSending = true);
    try {
      await _chatService.sendAudioMessage(
        conversationId: widget.conversationId,
        audioFile: file,
        durationMs: duration.inMilliseconds,
      );
      _scrollToBottomAfterFrame();
    } catch (e) {
      _showSnack('No se pudo enviar el audio.');
    } finally {
      _deleteTempFile(file.path);
      if (mounted) setState(() => _isSending = false);
    }
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
            // Los audios no se pueden editar, solo borrar.
            if (!message.isAudio)
              ListTile(
                leading: SvgPicture.asset(
                  'assets/icons/edit.svg',
                  width: 22,
                  height: 22,
                ),
                title: const Text('Editar mensaje'),
                onTap: () => Navigator.of(sheetContext).pop('edit'),
              ),
            ListTile(
              leading: SvgPicture.asset(
                'assets/icons/delete red.svg',
                width: 22,
                height: 22,
              ),
              title: const Text(
                'Eliminar mensaje',
                style: TextStyle(color: Color(0xFFE01414)),
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
              style: TextStyle(color: Color(0xFFE01414)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _chatService.deleteMessage(
        message.id,
        audioPath: message.isAudio ? message.audioPath : null,
      );
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
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
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

  /// Barra que reemplaza al campo de texto mientras se graba un audio:
  /// papelera para descartar, punto rojo con el tiempo, y botón de enviar.
  Widget _buildRecordingComposer() {
    final minutes = _recordElapsed.inMinutes.toString();
    final seconds = (_recordElapsed.inSeconds % 60).toString().padLeft(2, '0');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.viewInsetsOf(context).bottom > 0 ? 8 : 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 33,
              decoration: BoxDecoration(
                color: const Color(0x805B5A5F),
                borderRadius: BorderRadius.circular(17),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _cancelRecording,
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      width: 33,
                      height: 33,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 22,
                        color: Color(0xFFE01414),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE01414),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$minutes:$seconds',
                    style: const TextStyle(
                      color: Color(0xFFFEFEFE),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Grabando…',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Color(0xB3FEFEFE), fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _ChatActionButton(
            assetPath: 'assets/buttons/send button.svg',
            onTap: _stopRecordingAndSend,
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    if (_isRecording) return _buildRecordingComposer();

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
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: inputWidth,
                    constraints: const BoxConstraints(minHeight: actionSize),
                    decoration: BoxDecoration(
                      color: const Color(0x805B5A5F),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: Center(
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        textAlignVertical: TextAlignVertical.center,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          color: Color(0xFFFEFEFE),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
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
                    top: 0,
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
                    top: 0,
                    right: 0,
                    child: _ChatActionButton(
                      assetPath: _hasDraft
                          ? 'assets/buttons/send button.svg'
                          : 'assets/buttons/microphone button.svg',
                      onTap: _hasDraft
                          ? (_isSending ? null : _send)
                          : (_isSending ? null : _startRecording),
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

  // Medidas de la burbuja.
  static const double _radius = 14.3;
  static const double _tailWidth = 6;

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
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          child: CustomPaint(
            painter: _BubblePainter(
              color: bubbleColor,
              isMine: isMine,
              radius: _radius,
              tailWidth: _tailWidth,
            ),
            child: Padding(
              // El lado de la cola lleva espacio extra para que el texto
              // no se pise con ella.
              padding: EdgeInsets.fromLTRB(
                isMine ? 14 : 14 + _tailWidth,
                10,
                isMine ? 14 + _tailWidth : 14,
                10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isAudio)
                    ChatAudioPlayer(
                      // La key evita que el reproductor se mezcle con otro
                      // mensaje cuando la lista se actualiza.
                      key: ValueKey('audio_${message.id}'),
                      audioPath: message.audioPath!,
                      durationMs: message.audioDurationMs ?? 0,
                      color: textColor,
                    )
                  else
                    Text(
                      message.content,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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

/// Dibuja la burbuja estilo iMessage: cuerpo con esquinas de radio 14,3 y
/// una cola en la esquina inferior (derecha si es mío, izquierda si
/// es de la otra persona). Antes de la cola, el borde inferior sube
/// suavemente formando una pequeña muesca, y la punta está apenas
/// redondeada.
class _BubblePainter extends CustomPainter {
  _BubblePainter({
    required this.color,
    required this.isMine,
    required this.radius,
    required this.tailWidth,
  });

  final Color color;
  final bool isMine;
  final double radius;
  final double tailWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // Dibujamos siempre la versión "mía" (cola a la derecha). Para la
    // burbuja de la otra persona espejamos el lienzo horizontalmente.
    if (!isMine) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final r = radius;
    final h = size.height;
    final right = size.width - tailWidth; // borde derecho del cuerpo

    // La muesca ocupa unos 17 px hacia la izquierda del borde derecho.
    // Si la burbuja es muy angosta (mensaje corto), la achicamos para
    // que nunca pise la esquina inferior izquierda.
    const notchSpan = 17.0;
    final k = ((right - r) / notchSpan).clamp(0.0, 1.0);
    // Devuelve la posición X a "d" píxeles a la izquierda del borde derecho.
    double dx(double d) => right - d * k;

    final path = Path()
      // Arriba a la izquierda
      ..moveTo(r, 0)
      // Borde superior
      ..lineTo(right - r, 0)
      // Esquina superior derecha
      ..arcToPoint(Offset(right, r), radius: Radius.circular(r))
      // Borde derecho, hasta donde empieza a curvarse hacia la cola
      ..lineTo(right, h - 13)
      // Curva hacia afuera hasta la punta de la cola
      ..cubicTo(
        right, h - 7,
        right + tailWidth * 0.58, h - 2.8,
        right + tailWidth, h - 0.4,
      )
      // Punta apenas redondeada
      ..quadraticBezierTo(
        right + tailWidth, h,
        right + tailWidth - 0.6, h,
      )
      // Tramo plano de abajo, hasta justo antes de la muesca
      ..lineTo(right - 1, h)
      // El borde empieza a subir suavemente hasta la punta de la muesca
      ..cubicTo(
        dx(4.5), h,
        dx(7), h - 1.0,
        dx(9.3), h - 2.0,
      )
      // Y vuelve a bajar hasta el borde inferior normal
      ..cubicTo(
        dx(12), h - 1.0,
        dx(14.5), h,
        dx(17), h,
      )
      // Borde inferior
      ..lineTo(r, h)
      // Esquina inferior izquierda
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      // Borde izquierdo
      ..lineTo(0, r)
      // Esquina superior izquierda
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..close();

    canvas.drawPath(path, Paint()..color = color..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.color != color ||
      old.isMine != isMine ||
      old.radius != radius ||
      old.tailWidth != tailWidth;
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