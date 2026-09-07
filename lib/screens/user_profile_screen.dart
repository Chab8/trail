import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/chat_service.dart';
import '../services/follow_service.dart';
import '../services/profile_service.dart';
import '../widgets/profile_counter.dart';
import 'chat_screen.dart';

/// Pantalla de perfil de OTRO usuario (no el tuyo). Se llega acá tocando
/// un resultado de búsqueda, o desde un chat.
///
/// A diferencia de "Mi perfil" (ProfileScreen), acá no se puede editar
/// nada: solo se ve la info del usuario y hay un botón para seguirlo o
/// dejar de seguirlo, y (si lo seguís) uno para mandarle un mensaje.
class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _profileService = ProfileService();
  final _followService = FollowService();
  final _chatService = ChatService();

  bool _isLoading = true;
  bool _isFollowBusy = false;
  bool _isOpeningChat = false;
  String? _errorMessage;

  UserProfile? _profile;
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;

  bool get _isOwnProfile =>
      widget.userId == Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _profileService.getProfile(widget.userId);

      if (profile == null) {
        setState(() => _errorMessage = 'No se encontró este perfil.');
        return;
      }

      final counts = await _followService.getFollowCounts(widget.userId);

      final myId = Supabase.instance.client.auth.currentUser?.id;
      final following = (myId == null || _isOwnProfile)
          ? false
          : await _followService.isFollowing(
              followerId: myId,
              followingId: widget.userId,
            );

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _followersCount = counts.followersCount;
        _followingCount = counts.followingCount;
        _isFollowing = following;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'No se pudo cargar el perfil.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _isFollowBusy = true);

    final wasFollowing = _isFollowing;

    try {
      if (wasFollowing) {
        await _followService.unfollow(widget.userId);
      } else {
        await _followService.follow(widget.userId);
      }

      if (!mounted) return;
      setState(() {
        _isFollowing = !wasFollowing;
        _followersCount = wasFollowing
            ? (_followersCount > 0 ? _followersCount - 1 : 0)
            : _followersCount + 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasFollowing
                  ? 'No se pudo dejar de seguir a este usuario.'
                  : 'No se pudo seguir a este usuario.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFollowBusy = false);
    }
  }

  Future<void> _openChat() async {
    if (_profile == null) return;

    setState(() => _isOpeningChat = true);

    String? conversationId;
    try {
      conversationId =
          await _chatService.getOrCreateConversation(widget.userId);
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el chat.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningChat = false);
    }

    if (conversationId != null && mounted) {
      final id = conversationId;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: id,
            otherUserId: widget.userId,
            otherUsername: _profile!.username,
            otherAvatarUrl: _profile!.avatarUrl,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile != null ? '@${_profile!.username}' : 'Perfil'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : _buildProfile(),
    );
  }

  Widget _buildProfile() {
    final profile = _profile!;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          Center(child: _AvatarImage(imageUrl: profile.avatarUrl)),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '@${profile.username}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const ProfileCounter(label: 'Trails', value: 0),
              ProfileCounter(label: 'Followers', value: _followersCount),
              ProfileCounter(label: 'Following', value: _followingCount),
            ],
          ),
          if (!_isOwnProfile) ...[
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: _isFollowing
                        ? OutlinedButton(
                            onPressed: _isFollowBusy ? null : _toggleFollow,
                            child: _isFollowBusy
                                ? const _ButtonSpinner()
                                : const Text('Following'),
                          )
                        : ElevatedButton(
                            onPressed: _isFollowBusy ? null : _toggleFollow,
                            child: _isFollowBusy
                                ? const _ButtonSpinner()
                                : const Text('Follow'),
                          ),
                  ),
                ),
                if (_isFollowing) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _isOpeningChat ? null : _openChat,
                        child: _isOpeningChat
                            ? const _ButtonSpinner()
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chat_bubble_outline, size: 18),
                                  SizedBox(width: 6),
                                  Text('Mensaje'),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  final String? imageUrl;

  const _AvatarImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    Widget image = const Icon(Icons.person, size: 48, color: Colors.white70);
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      image = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.person, size: 48, color: Colors.white70),
      );
    }

    return Container(
      width: 96,
      height: 96,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Color(0xFF3A3A3A),
        shape: BoxShape.circle,
      ),
      child: image,
    );
  }
}