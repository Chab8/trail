import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/profile_service.dart';
import 'user_profile_screen.dart';

/// Pantalla de "Mensajes". Por ahora funciona como buscador de personas:
/// escribís un nombre de usuario arriba y aparece una lista de
/// coincidencias. Tocando un resultado, se abre el perfil de esa persona,
/// donde podés seguirla.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _profileService = ProfileService();
  final _searchController = TextEditingController();

  Timer? _debounce;
  bool _isSearching = false;
  String? _errorMessage;
  List<UserProfile> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // "Debounce" quiere decir: esperar un poquito después de que la persona
  // deja de tipear antes de buscar. Así, si escribís "ana" letra por
  // letra, no hacemos 3 búsquedas (a, an, ana), sino una sola.
  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(query);
    });
    // Refrescamos la pantalla para mostrar/ocultar el botón de limpiar (X).
    setState(() {});
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      final results = await _profileService.searchUsersByUsername(
        trimmed,
        excludeUserId: myId,
      );
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'No se pudo buscar usuarios.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _onQueryChanged('');
  }

  void _openProfile(UserProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: profile.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre de usuario',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _clearSearch,
                        ),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Buscá a otros usuarios por su nombre de usuario para\n'
            'seguirlos y ver sus trails.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(child: Text('No se encontraron usuarios.'));
    }

    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 116;

    return ListView.builder(
      padding: EdgeInsets.only(bottom: bottomPadding),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final profile = _results[index];
        final hasAvatar = profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF3A3A3A),
            backgroundImage: hasAvatar ? NetworkImage(profile.avatarUrl!) : null,
            child: hasAvatar
                ? null
                : const Icon(Icons.person, color: Colors.white70),
          ),
          title: Text('@${profile.username}'),
          onTap: () => _openProfile(profile),
        );
      },
    );
  }
}