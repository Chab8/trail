import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/follow_relationship.dart';
import '../models/user_profile.dart';
import '../services/follow_service.dart';
import '../services/profile_service.dart';
import '../widgets/profile_counter.dart';

/// Pantalla de perfil de OTRO usuario (no el tuyo). Se llega acá tocando
/// un resultado de búsqueda en la pantalla de Mensajes.
///
/// A diferencia de "Mi perfil" (ProfileScreen), acá no se puede editar
/// nada: solo se ve la info del usuario y hay un botón para seguirlo,
/// pedirle seguirlo (si es privado) o dejar de seguirlo.
class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _profileService = ProfileService();
  final _followService = FollowService();

  bool _isLoading = true;
  bool _isFollowBusy = false;
  String? _errorMessage;

  UserProfile? _profile;
  int _followersCount = 0;
  int _followingCount = 0;
  FollowRelationship _relationship = FollowRelationship.none;

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

      final relationship = _isOwnProfile
          ? FollowRelationship.none
          : await _followService.getRelationship(widget.userId);

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _followersCount = counts.followersCount;
        _followingCount = counts.followingCount;
        _relationship = relationship;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'No se pudo cargar el perfil.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFollowButton() async {
    final profile = _profile;
    if (profile == null) return;

    setState(() => _isFollowBusy = true);

    final previousRelationship = _relationship;

    try {
      switch (previousRelationship) {
        case FollowRelationship.following:
          await _followService.unfollow(widget.userId);
          if (!mounted) return;
          setState(() {
            _relationship = FollowRelationship.none;
            _followersCount = _followersCount > 0 ? _followersCount - 1 : 0;
          });
          break;

        case FollowRelationship.requested:
          // Tocar "Requested" cancela la solicitud pendiente.
          await _followService.cancelFollowRequest(widget.userId);
          if (!mounted) return;
          setState(() => _relationship = FollowRelationship.none);
          break;

        case FollowRelationship.none:
          if (profile.isPrivate) {
            await _followService.sendFollowRequest(widget.userId);
            if (!mounted) return;
            setState(() => _relationship = FollowRelationship.requested);
          } else {
            await _followService.follow(widget.userId);
            if (!mounted) return;
            setState(() {
              _relationship = FollowRelationship.following;
              _followersCount += 1;
            });
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la acción.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFollowBusy = false);
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
            child: Column(
              children: [
                Text(
                  '@${profile.username}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (profile.isPrivate) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.lock_outline, size: 14, color: Colors.white54),
                      SizedBox(width: 4),
                      Text(
                        'Cuenta privada',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ],
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
            SizedBox(
              width: double.infinity,
              height: 44,
              child: _relationship == FollowRelationship.none
                  ? ElevatedButton(
                      onPressed: _isFollowBusy ? null : _handleFollowButton,
                      child: _isFollowBusy
                          ? const _ButtonSpinner()
                          : Text(profile.isPrivate ? 'Request' : 'Follow'),
                    )
                  : OutlinedButton(
                      onPressed: _isFollowBusy ? null : _handleFollowButton,
                      child: _isFollowBusy
                          ? const _ButtonSpinner()
                          : Text(
                              _relationship == FollowRelationship.following
                                  ? 'Following'
                                  : 'Requested',
                            ),
                    ),
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