import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/completed_trail.dart';
import '../services/follow_service.dart';
import '../services/profile_service.dart';
import '../services/trail_library_service.dart';
import '../widgets/profile_counter.dart';
import '../widgets/trail_detail_dialog.dart';
import '../widgets/trail_like_button.dart';
import '../widgets/trail_map_preview.dart';
import '../widgets/trail_month_list.dart';
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
  final _trailLibrary = TrailLibraryService.instance;

  bool _isLoading = true;
  String? _errorMessage;
  String? _username;
  String? _avatarUrl;
  List<CompletedTrail> _trails = [];
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
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) _loadTrails(userId);
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
      try {
        _trails = await _trailLibrary.getTrailsForUser(userId);
      } catch (_) {
        // Un problema al consultar el historial no debe impedir mostrar el
        // resto del perfil.
        _trails = [];
      }
    } catch (e) {
      setState(() => _errorMessage = 'No se pudo cargar el perfil.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTrails(String userId) async {
    try {
      final trails = await _trailLibrary.getTrailsForUser(userId);
      if (!mounted || Supabase.instance.client.auth.currentUser?.id != userId) {
        return;
      }
      setState(() => _trails = trails);
    } catch (_) {
      // El perfil puede seguir mostrándose si una recarga puntual falla.
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
                      _AvatarImage(imageUrl: _avatarUrl),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            ProfileCounter(
                              label: 'trails',
                              value: _trails.length,
                            ),
                            ProfileCounter(
                              label: 'followers',
                              value: _followersCount,
                              onTap: () =>
                                  _openFollowList(FollowListTab.followers),
                            ),
                            ProfileCounter(
                              label: 'following',
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  const Text(
                    'Your trails',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (_trails.isEmpty)
                    Text(
                      'Todavía no completaste ningún trail.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    )
                  else
                    TrailMonthList(
                      trails: _trails,
                      itemBuilder: (trail) => TrailSummaryCard(trail),
                    ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                         style: const TextStyle(color: Color(0xFFE01414)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Una fila compacta por cada trail guardado.
///
/// Diseño: mini-mapa cuadrado a la izquierda | nombre + fecha al centro |
/// chevron de expansión a la derecha. Al tocarla se abre TrailDetailDialog.
///
/// El mini-mapa no dibuja las canciones que el dueño ocultó.
class TrailSummaryCard extends StatelessWidget {
  const TrailSummaryCard(this.trail, {super.key, this.isOwnProfile = true});

  final CompletedTrail trail;

  /// `true` cuando se muestra en tu propio perfil. En el perfil de otro
  /// usuario se pasa `false` para que el detalle no muestre el lápiz de
  /// edición.
  final bool isOwnProfile;

  static const _accentColor = Color(0xFF654CDD);

  /// Convierte las canciones ocultas en rangos de tiempo del trail.
  List<TrailActiveTimeRange> get _hiddenRanges {
    final ranges = <TrailActiveTimeRange>[];
    for (final index in trail.hiddenSongIndexes) {
      if (index < 0 || index >= trail.songs.length) continue;
      final start = trail.songStartOffsetAt(index);
      final end = trail.songEndOffsetAt(index);
      if (end > start) {
        ranges.add(TrailActiveTimeRange(start: start, end: end));
      }
    }
    return ranges;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return '${months[date.month - 1]}. ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Capturar posición del card en pantalla para la animación de origen
        final box = context.findRenderObject() as RenderBox?;
        final screenSize = MediaQuery.of(context).size;
        var origin = Alignment.center;
        if (box != null) {
          final pos = box.localToGlobal(Offset.zero);
          final cardCenter =
              pos + Offset(box.size.width / 2, box.size.height / 2);
          origin = Alignment(
            ((cardCenter.dx / screenSize.width) * 2 - 1).clamp(-1.0, 1.0),
            ((cardCenter.dy / screenSize.height) * 2 - 1).clamp(-1.0, 1.0),
          );
        }
        TrailDetailDialog.show(
          context,
          trail,
          origin: origin,
          isOwnTrail: isOwnProfile,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            Row(
              children: [
                // ── Mini-mapa cuadrado ──────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: TrailMapPreview(
                      segments: trail.segments,
                      height: 64,
                      hiddenRanges: _hiddenRanges,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // ── Nombre y fecha ────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              trail.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SvgPicture.asset(
                            'assets/icons/star.svg',
                            width: 14,
                            height: 14,
                            colorFilter: const ColorFilter.mode(
                              _accentColor,
                              BlendMode.srcIn,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(trail.completedAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // ── Chevron ───────────────────────────────────────────────
                SvgPicture.asset(
                  'assets/icons/expand.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    Colors.white.withValues(alpha: 0.4),
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
            // ── Likes: corazón + contador, abajo a la derecha ────────────
            Positioned(
              right: 32,
              bottom: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/public.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF654CDD),
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Public',
                        style: TextStyle(
                          color: Color(0xFFFEFEFE),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  TrailLikeButton(trailId: trail.id),
                ],
              ),
            ),
          ],
        ),
      ),
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