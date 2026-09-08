import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/completed_trail.dart';
import '../models/follow_relationship.dart';
import '../models/user_profile.dart';
import '../services/chat_service.dart';
import '../services/follow_service.dart';
import '../services/profile_service.dart';
import '../services/trail_library_service.dart';
import '../widgets/profile_counter.dart';
import 'chat_screen.dart';
import 'profile_screen.dart' show TrailSummaryCard;

/// Pantalla de perfil de OTRO usuario (no el tuyo). Se llega acá tocando
/// un resultado de búsqueda, o desde un chat.
///
/// A diferencia de "Mi perfil" (ProfileScreen), acá no se puede editar
/// nada: solo se ve la info del usuario y hay un botón para seguirlo o
/// dejar de seguirlo, y (si lo seguís) uno para mandarle un mensaje.
///
/// La galería de trails de este usuario se muestra solo si:
///  - el perfil es público, o
///  - el perfil es privado pero vos ya lo seguís (o son tus propios trails).
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
  final _trailLibrary = TrailLibraryService.instance;

  bool _isLoading = true;
  bool _isFollowBusy = false;
  bool _isOpeningChat = false;
  String? _errorMessage;

  UserProfile? _profile;
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;
  bool _isRequested = false;

  List<CompletedTrail> _trails = [];
  bool _isLoadingTrails = false;

  bool get _isOwnProfile =>
      widget.userId == Supabase.instance.client.auth.currentUser?.id;

  /// Podés ver la galería de trails si es tu propio perfil, si el perfil
  /// es público, o si es privado pero ya lo seguís.
  bool get _canViewTrails {
    final profile = _profile;
    if (profile == null) return false;
    return _isOwnProfile || !profile.isPrivate || _isFollowing;
  }

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

      final relationship = _isOwnProfile
          ? FollowRelationship.none
          : await _followService.getRelationship(widget.userId);

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _followersCount = counts.followersCount;
        _followingCount = counts.followingCount;
        _isFollowing = relationship == FollowRelationship.following;
        _isRequested = relationship == FollowRelationship.requested;
      });

      await _loadTrails();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'No se pudo cargar el perfil.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Trae los trails de este usuario, solo si tenemos permiso para verlos.
  /// Si el perfil es privado y no lo seguimos, ni siquiera consultamos:
  /// mostramos directamente un mensaje explicando por qué no se ve nada.
  Future<void> _loadTrails() async {
    if (!_canViewTrails) {
      if (mounted) setState(() => _trails = []);
      return;
    }

    setState(() => _isLoadingTrails = true);
    try {
      final trails = await _trailLibrary.getTrailsForUser(widget.userId);
      if (!mounted) return;
      setState(() => _trails = trails);
    } catch (_) {
      // Un problema al traer los trails no debe romper el resto del perfil.
    } finally {
      if (mounted) setState(() => _isLoadingTrails = false);
    }
  }

  /// Sigue, deja de seguir, pide o cancela una solicitud de seguimiento,
  /// según el estado actual y si el perfil es privado o no.
  Future<void> _toggleFollow() async {
    setState(() => _isFollowBusy = true);

    final wasFollowing = _isFollowing;
    final wasRequested = _isRequested;
    final isPrivate = _profile?.isPrivate ?? false;

    try {
      if (wasFollowing) {
        await _followService.unfollow(widget.userId);
        if (!mounted) return;
        setState(() {
          _isFollowing = false;
          _followersCount = _followersCount > 0 ? _followersCount - 1 : 0;
        });
      } else if (wasRequested) {
        await _followService.cancelFollowRequest(widget.userId);
        if (!mounted) return;
        setState(() => _isRequested = false);
      } else if (isPrivate) {
        await _followService.sendFollowRequest(widget.userId);
        if (!mounted) return;
        setState(() => _isRequested = true);
      } else {
        await _followService.follow(widget.userId);
        if (!mounted) return;
        setState(() {
          _isFollowing = true;
          _followersCount = _followersCount + 1;
        });
      }

      // Si pasamos a seguir (o dejamos de seguir), la visibilidad de los
      // trails puede haber cambiado.
      await _loadTrails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasFollowing
                  ? 'No se pudo dejar de seguir a este usuario.'
                  : 'No se pudo completar la acción.',
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
              ProfileCounter(label: 'Trails', value: _trails.length),
              ProfileCounter(label: 'Followers', value: _followersCount),
              ProfileCounter(label: 'Following', value: _followingCount),
            ],
          ),
          if (!_isOwnProfile) ...[
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: SizedBox(height: 44, child: _buildFollowButton()),
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
          const SizedBox(height: 32),
          const Text(
            'Trails',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _buildTrailsSection(),
        ],
      ),
    );
  }

  Widget _buildFollowButton() {
    if (_isFollowing) {
      return OutlinedButton(
        onPressed: _isFollowBusy ? null : _toggleFollow,
        child: _isFollowBusy
            ? const _ButtonSpinner()
            : const Text('Following'),
      );
    }
    if (_isRequested) {
      return OutlinedButton(
        onPressed: _isFollowBusy ? null : _toggleFollow,
        child: _isFollowBusy
            ? const _ButtonSpinner()
            : const Text('Requested'),
      );
    }
    return ElevatedButton(
      onPressed: _isFollowBusy ? null : _toggleFollow,
      child: _isFollowBusy
          ? const _ButtonSpinner()
          : Text((_profile?.isPrivate ?? false) ? 'Request' : 'Follow'),
    );
  }

  Widget _buildTrailsSection() {
    if (_isLoadingTrails) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_canViewTrails) {
      return Text(
        'Esta cuenta es privada. Seguila para ver sus trails.',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
      );
    }

    if (_trails.isEmpty) {
      return Text(
        'Todavía no completó ningún trail.',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
      );
    }

    return Column(children: _trails.map(TrailSummaryCard.new).toList());
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