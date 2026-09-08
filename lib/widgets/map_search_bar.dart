import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../screens/user_profile_screen.dart';
import '../services/profile_service.dart';
import 'liquid_glass.dart';

/// Barra de búsqueda de la pestaña del mapa.
///
/// Por ahora solo busca usuarios (reutiliza la misma lógica que la
/// pantalla de "Buscar usuarios" en Mensajes). El día que exista búsqueda
/// de canciones o lugares, se puede sumar acá mismo sin tocar el diseño.
class MapSearchBar extends StatefulWidget {
  const MapSearchBar({super.key});

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  static const double _barWidth = 293;

  final _profileService = ProfileService();
  final _controller = TextEditingController();

  Timer? _debounce;
  bool _isSearching = false;
  List<UserProfile> _results = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    // Refresca la UI para mostrar/ocultar la lista de resultados apenas
    // hay (o deja de haber) texto, y programa la búsqueda con un pequeño
    // retraso para no consultar la base de datos en cada letra tipeada.
    setState(() {});

    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(_controller.text),
    );
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
        });
      }
      return;
    }

    setState(() => _isSearching = true);

    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      final results = await _profileService.searchUsersByUsername(
        trimmed,
        excludeUserId: myId,
      );
      if (!mounted) return;
      setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _openProfile(UserProfile profile) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: profile.id)),
    );
  }

  bool get _hasQuery => _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: _barWidth, child: _buildSearchField()),
        if (_hasQuery) ...[
          const SizedBox(height: 8),
          SizedBox(width: _barWidth, child: _buildResultsPanel()),
        ],
      ],
    );
  }

  Widget _buildSearchField() {
    return LiquidGlass(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/icons/search_icon.svg',
              width: 17,
              height: 17,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: Colors.white,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Search song, user or place',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SvgPicture.asset(
              'assets/icons/microphone.svg',
              width: 14,
              height: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsPanel() {
    return LiquidGlass(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: _buildResultsContent(),
      ),
    );
  }

  Widget _buildResultsContent() {
    if (_isSearching && _results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        child: Text(
          'No se encontraron usuarios.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final profile = _results[index];
        final hasAvatar =
            profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty;

        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          leading: CircleAvatar(
            radius: 15,
            backgroundColor: const Color(0xFF3A3A3A),
            backgroundImage:
                hasAvatar ? NetworkImage(profile.avatarUrl!) : null,
            child: hasAvatar
                ? null
                : const Icon(Icons.person, size: 15, color: Colors.white70),
          ),
          title: Text(
            '@${profile.username}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          onTap: () => _openProfile(profile),
        );
      },
    );
  }
}