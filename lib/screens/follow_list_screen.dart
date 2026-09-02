import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/follow_service.dart';
import 'user_profile_screen.dart';

/// Qué pestaña se muestra primero al abrir la pantalla: la de
/// seguidores o la de seguidos.
enum FollowListTab { followers, following }

/// Pantalla con dos pestañas ("Seguidores" y "Siguiendo") para un usuario
/// en particular.
///
/// Se llega acá tocando el contador de "Followers" o "Following" en
/// ProfileScreen (tu propio perfil) o en UserProfileScreen (el perfil de
/// otra persona). Sirve tanto para ver tus propios seguidores/seguidos
/// como los de cualquier otro usuario.
class FollowListScreen extends StatefulWidget {
  /// El dueño de la lista que se muestra (de quién son los seguidores).
  final String userId;

  /// Nombre de usuario del dueño de la lista, para el título de la pantalla.
  final String username;

  /// Con qué pestaña arranca abierta la pantalla.
  final FollowListTab initialTab;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.username,
    this.initialTab = FollowListTab.followers,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen>
    with SingleTickerProviderStateMixin {
  final _followService = FollowService();
  late final TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  List<UserProfile> _followers = [];
  List<UserProfile> _following = [];

  // A quiénes sigue el usuario LOGUEADO (no necesariamente el dueño de
  // esta pantalla) y a quiénes les mandó una solicitud pendiente. Con
  // esto sabemos qué botón mostrar (Follow / Following / Requested) al
  // lado de cada persona de la lista, sin tener que preguntarlo una por
  // una.
  Set<String> _myFollowingIds = {};
  Set<String> _myPendingRequestIds = {};

  String? get _myId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == FollowListTab.following ? 1 : 0,
    );
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _followService.getFollowers(widget.userId),
        _followService.getFollowing(widget.userId),
        _followService.getMyFollowingIds(),
        _followService.getMyPendingRequestIds(),
      ]);

      if (!mounted) return;
      setState(() {
        _followers = results[0] as List<UserProfile>;
        _following = results[1] as List<UserProfile>;
        _myFollowingIds = results[2] as Set<String>;
        _myPendingRequestIds = results[3] as Set<String>;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'No se pudo cargar la lista.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFollowTap(UserProfile user) async {
    final isFollowing = _myFollowingIds.contains(user.id);
    final isRequested = _myPendingRequestIds.contains(user.id);

    try {
      if (isFollowing) {
        await _followService.unfollow(user.id);
        if (!mounted) return;
        setState(() => _myFollowingIds.remove(user.id));
      } else if (isRequested) {
        await _followService.cancelFollowRequest(user.id);
        if (!mounted) return;
        setState(() => _myPendingRequestIds.remove(user.id));
      } else if (user.isPrivate) {
        await _followService.sendFollowRequest(user.id);
        if (!mounted) return;
        setState(() => _myPendingRequestIds.add(user.id));
      } else {
        await _followService.follow(user.id);
        if (!mounted) return;
        setState(() => _myFollowingIds.add(user.id));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la acción.')),
        );
      }
    }
  }

  void _openProfile(UserProfile user) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: user.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.username}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Seguidores'), Tab(text: 'Siguiendo')],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_followers, 'Todavía no tiene seguidores.'),
                _buildList(_following, 'Todavía no sigue a nadie.'),
              ],
            ),
    );
  }

  Widget _buildList(List<UserProfile> users, String emptyMessage) {
    if (users.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final hasAvatar =
            user.avatarUrl != null && user.avatarUrl!.isNotEmpty;
        final isMe = user.id == _myId;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF3A3A3A),
            backgroundImage: hasAvatar ? NetworkImage(user.avatarUrl!) : null,
            child: hasAvatar
                ? null
                : const Icon(Icons.person, color: Colors.white70),
          ),
          title: Text('@${user.username}'),
          onTap: () => _openProfile(user),
          // No mostramos ningún botón al lado de tu propia fila (no te
          // podés seguir a vos mismo).
          trailing: isMe ? null : _buildFollowButton(user),
        );
      },
    );
  }

  Widget _buildFollowButton(UserProfile user) {
    final isFollowing = _myFollowingIds.contains(user.id);
    final isRequested = _myPendingRequestIds.contains(user.id);

    final label = isFollowing
        ? 'Following'
        : isRequested
        ? 'Requested'
        : user.isPrivate
        ? 'Request'
        : 'Follow';

    if (isFollowing || isRequested) {
      return OutlinedButton(
        onPressed: () => _handleFollowTap(user),
        child: Text(label),
      );
    }

    return ElevatedButton(
      onPressed: () => _handleFollowTap(user),
      child: Text(label),
    );
  }
}