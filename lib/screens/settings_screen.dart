import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../services/spotify_service.dart';
import 'follow_requests_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _profileService = ProfileService();
  final _usernameController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _checkingSpotify = true;
  bool _spotifyConnected = false;
  bool _spotifyBusy = false;
  bool _isPrivate = false;
  bool _updatingPrivacy = false;
  String? _userId;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    _userId = userId;

    try {
      final results = await Future.wait<Object?>([
        _profileService.getProfile(userId),
        SpotifyService.instance.isConnected(),
      ]);
      final profile = results[0] as UserProfile?;
      if (profile != null) {
        _usernameController.text = profile.username;
        _isPrivate = profile.isPrivate;
      }
      if (mounted) {
        setState(() {
          _spotifyConnected = results[1] as bool;
          _checkingSpotify = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No se pudo cargar la configuración.';
          _checkingSpotify = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveUsername() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final username = _usernameController.text.trim();
    if (userId == null || username.isEmpty) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _profileService.updateUsername(userId: userId, username: username);
      if (mounted) {
        setState(() => _successMessage = 'Nombre de usuario actualizado.');
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.code == '23505'
              ? 'Ese nombre de usuario ya está en uso.'
              : 'No se pudo guardar: ${e.message}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'No se pudo guardar el nombre de usuario.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _togglePrivacy(bool value) async {
    final userId = _userId;
    if (userId == null) return;

    // Cambiamos el interruptor al toque (para que se sienta instantáneo)
    // y lo volvemos atrás si falla el guardado.
    setState(() {
      _isPrivate = value;
      _updatingPrivacy = true;
    });

    try {
      await _profileService.updatePrivacy(userId: userId, isPrivate: value);
    } catch (_) {
      if (mounted) {
        setState(() => _isPrivate = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar la privacidad.')),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingPrivacy = false);
    }
  }

  Future<void> _disconnectSpotify() async {
    setState(() => _spotifyBusy = true);
    try {
      await SpotifyService.instance.disconnect();
      if (mounted) {
        setState(() => _spotifyConnected = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spotify fue desconectado.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo desconectar Spotify.')),
        );
      }
    } finally {
      if (mounted) setState(() => _spotifyBusy = false);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  MediaQuery.viewPaddingOf(context).bottom + 24,
                ),
                children: [
                  const Text(
                    'Cuenta',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Usuario (@username)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  if (_successMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.greenAccent),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveUsername,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar nombre de usuario'),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Privacidad',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Perfil privado'),
                    subtitle: Text(
                      _isPrivate
                          ? 'Los nuevos seguidores necesitan tu aprobación.'
                          : 'Cualquiera puede seguirte directamente.',
                    ),
                    value: _isPrivate,
                    onChanged: _updatingPrivacy ? null : _togglePrivacy,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_add_alt_1_outlined),
                    title: const Text('Solicitudes de seguidor'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FollowRequestsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Música',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
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
                            ? 'Podés desconectarlo cuando quieras.'
                            : 'No hay una cuenta de Spotify conectada.',
                      ),
                      trailing: _spotifyBusy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : _spotifyConnected
                          ? TextButton(
                              onPressed: _disconnectSpotify,
                              child: const Text('Desconectar'),
                            )
                          : null,
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