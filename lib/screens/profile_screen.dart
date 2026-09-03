import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/completed_trail.dart';
import '../models/trail_song.dart';
import '../services/follow_service.dart';
import '../services/profile_service.dart';
import '../services/trail_library_service.dart';
import '../widgets/profile_counter.dart';
import 'follow_list_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  final _followService = FollowService();
  final _imagePicker = ImagePicker();
  final _trailLibrary = TrailLibraryService.instance;

  bool _isLoading = true;
  bool _isPickingAvatar = false;
  String? _errorMessage;
  String? _username;
  String? _avatarUrl;
  Uint8List? _selectedAvatarBytes;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _trailLibrary.addListener(_onTrailsChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    _trailLibrary.removeListener(_onTrailsChanged);
    super.dispose();
  }

  void _onTrailsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final profile = await _profileService.getProfile(userId);
      if (profile != null) {
        _username = profile.username;
        _avatarUrl = profile.avatarUrl;
      }

      // Contamos a cuántos seguidores y seguidos tenés en este momento.
      final counts = await _followService.getFollowCounts(userId);
      _followersCount = counts.followersCount;
      _followingCount = counts.followingCount;
    } catch (e) {
      setState(() => _errorMessage = 'No se pudo cargar el perfil.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAvatar() async {
    setState(() => _isPickingAvatar = true);

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (mounted) setState(() => _selectedAvatarBytes = bytes);

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final extension = _extensionFromPath(image.path);
      final filePath = '$userId/avatar.$extension';

      // Sube la foto al bucket "avatars". upsert:true significa que si ya
      // existe una foto anterior para este usuario, la reemplaza.
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentTypeFromExtension(extension),
            ),
          );

      // Arma el link público de la foto. Le agregamos un "?v=..." al final
      // para que el teléfono no muestre una versión vieja guardada en caché.
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);
      final freshUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      // Guarda el link en la tabla profiles, para que persista.
      await _profileService.updateAvatarUrl(
        userId: userId,
        avatarUrl: freshUrl,
      );

      if (mounted) {
        setState(() {
          _avatarUrl = freshUrl;
          _selectedAvatarBytes = null;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar la foto de perfil.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingAvatar = false);
    }
  }

  String _extensionFromPath(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) return 'jpg';
    return path.substring(dotIndex + 1).toLowerCase();
  }

  String _contentTypeFromExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'heic':
        return 'image/heic';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    if (mounted) _loadProfile();
  }

  Future<void> _openFollowList(FollowListTab tab) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || _username == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          userId: userId,
          username: _username!,
          initialTab: tab,
        ),
      ),
    );

    // Si en esa pantalla seguiste o dejaste de seguir a alguien, los
    // contadores de acá pueden haber cambiado: los volvemos a cargar.
    if (mounted) _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  MediaQuery.viewPaddingOf(context).bottom + 116,
                ),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Configuración',
                      onPressed: _openSettings,
                      icon: SvgPicture.asset(
                        'assets/icons/settings_icon.svg',
                        width: 22,
                        height: 23,
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Semantics(
                        button: true,
                        label: 'Elegir foto de perfil',
                        child: InkWell(
                          onTap: _isPickingAvatar ? null : _pickAvatar,
                          borderRadius: BorderRadius.circular(48),
                          child: Stack(
                            children: [
                              _AvatarImage(
                                imageBytes: _selectedAvatarBytes,
                                imageUrl: _avatarUrl,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: const BoxDecoration(
                                    color: Colors.deepPurple,
                                    shape: BoxShape.circle,
                                  ),
                                  child: _isPickingAvatar
                                      ? const Padding(
                                          padding: EdgeInsets.all(7),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.edit, size: 17),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            ProfileCounter(
                              label: 'Trails',
                              value: _trailLibrary.count,
                            ),
                            ProfileCounter(
                              label: 'Followers',
                              value: _followersCount,
                              onTap: () =>
                                  _openFollowList(FollowListTab.followers),
                            ),
                            ProfileCounter(
                              label: 'Following',
                              value: _followingCount,
                              onTap: () =>
                                  _openFollowList(FollowListTab.following),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_username != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      '@$_username',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  const Text(
                    'Tus trails',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (_trailLibrary.trails.isEmpty)
                    Text(
                      'Todavía no completaste ningún trail.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    )
                  else
                    ..._trailLibrary.trails.map(_TrailSummaryCard.new),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _TrailSummaryCard extends StatelessWidget {
  const _TrailSummaryCard(this.trail);

  final CompletedTrail trail;

  @override
  Widget build(BuildContext context) {
    final List<TrailSong> songs = trail.songs;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trail.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (songs.isEmpty)
              const Text('No se detectaron canciones durante este trail.')
            else
              ...songs.map<Widget>(
                (song) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${song.title} — ${song.artist}')),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? imageUrl;

  const _AvatarImage({this.imageBytes, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    Widget image = const Icon(Icons.person, size: 48, color: Colors.white70);
    if (imageBytes != null) {
      image = Image.memory(imageBytes!, fit: BoxFit.cover);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
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
