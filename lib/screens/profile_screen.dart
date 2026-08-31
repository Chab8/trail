import 'package:flutter/material.dart';
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
  final _usernameController = TextEditingController();
  final _avatarUrlController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

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
        _avatarUrlController.text = profile.avatarUrl ?? '';
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
              const SnackBar(content: Text('No se pudo conectar con Spotify. Probá de nuevo.')),
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
      if (_avatarUrlController.text.trim().isNotEmpty) {
        await _profileService.updateAvatarUrl(
          userId: userId,
          avatarUrl: _avatarUrlController.text.trim(),
        );
      }
      setState(() => _successMessage = 'Perfil actualizado.');
    } on PostgrestException catch (e) {
      setState(() => _errorMessage =
          e.code == '23505' ? 'Ese nombre de usuario ya está en uso.' : 'No se pudo guardar: ${e.message}');
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

  @override
  void dispose() {
    _usernameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Usuario (@username)'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _avatarUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL de foto de perfil',
                      hintText: 'https://...',
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (_successMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_successMessage!, style: const TextStyle(color: Colors.green)),
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
                  const Text('Música', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (_checkingSpotify)
                    const Center(child: CircularProgressIndicator())
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.music_note,
                        color: _spotifyConnected ? const Color(0xFF1DB954) : Colors.grey,
                      ),
                      title: Text(_spotifyConnected ? 'Spotify conectado' : 'Spotify no conectado'),
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
                              child: Text(_spotifyConnected ? 'Desconectar' : 'Conectar'),
                            ),
                    ),
                ],
              ),
            ),
    );
  }
}