import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_service.dart';
import '../services/spotify_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  final _imagePicker = ImagePicker();
  final _usernameController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPickingAvatar = false;
  String? _errorMessage;
  String? _successMessage;
  String? _avatarUrl;
  Uint8List? _selectedAvatarBytes;

  bool _checkingSpotify = true;
  bool _spotifyConnected = false;
  bool _spotifyBusy = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadSpotifyStatus();
  }

  Future<void> _loadProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final profile = await _profileService.getProfile(userId);
      if (profile != null) {
        _usernameController.text = profile.username;
        _avatarUrl = profile.avatarUrl;
      }
    } catch (e) {
      setState(() => _errorMessage = 'No se pudo cargar el perfil.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSpotifyStatus() async {
    final connected = await SpotifyService.instance.isConnected();
    if (mounted) {
      setState(() {
        _spotifyConnected = connected;
        _checkingSpotify = false;
      });
    }
  }

  Future<void> _toggleSpotify() async {
    setState(() => _spotifyBusy = true);
    try {
      if (_spotifyConnected) {
        await SpotifyService.instance.disconnect();
        if (mounted) setState(() => _spotifyConnected = false);
      } else {
        final success = await SpotifyService.instance.connect();
        if (mounted) {
          setState(() => _spotifyConnected = success);
          if (!success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No se pudo conectar con Spotify. Probá de nuevo.',
                ),
              ),
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _spotifyBusy = false);
    }
  }

  Future<void> _saveProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _profileService.updateUsername(
        userId: userId,
        username: _usernameController.text.trim(),
      );
      setState(() => _successMessage = 'Perfil actualizado.');
    } on PostgrestException catch (e) {
      setState(
        () => _errorMessage = e.code == '23505'
            ? 'Ese nombre de usuario ya está en uso.'
            : 'No se pudo guardar: ${e.message}',
      );
    } catch (e) {
      setState(() => _errorMessage = 'No se pudo guardar el perfil.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo seleccionar la foto.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingAvatar = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
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
                      const Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _ProfileCounter(label: 'Trails'),
                            _ProfileCounter(label: 'Followers'),
                            _ProfileCounter(label: 'Following'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Usuario (@username)',
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (_successMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar cambios'),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Música',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (_checkingSpotify)
                    const Center(child: CircularProgressIndicator())
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.music_note,
                        color: _spotifyConnected
                            ? const Color(0xFF1DB954)
                            : Colors.grey,
                      ),
                      title: Text(
                        _spotifyConnected
                            ? 'Spotify conectado'
                            : 'Spotify no conectado',
                      ),
                      subtitle: Text(
                        _spotifyConnected
                            ? 'Vamos a mostrar lo que estás escuchando en el mapa.'
                            : 'Conectá tu cuenta para mostrar en el mapa lo que estás escuchando.',
                      ),
                      trailing: _spotifyBusy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : TextButton(
                              onPressed: _toggleSpotify,
                              child: Text(
                                _spotifyConnected ? 'Desconectar' : 'Conectar',
                              ),
                            ),
                    ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfileCounter extends StatelessWidget {
  final String label;

  const _ProfileCounter({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '0',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
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
