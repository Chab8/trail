import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_service.dart';
import '../widgets/settings_header.dart';
import 'account_management_screen.dart' show UsernameScreen;

// ─────────────────────────────────────────────────────────────────────────────
// Colores y estilos (iguales a los de "Manejo de la cuenta")
// ─────────────────────────────────────────────────────────────────────────────
const Color _kMain = Color(0xFFFEFEFE);
const Color _kSub = Color(0xFF9C9C9C);
const Color _kDanger = Color(0xFFE01414);
const Color _kBg = Color(0xFF09080B);

/// Interruptor: colores pedidos por Chab.
const Color _kSwitchOff = Color(0xFF242424);
const Color _kSwitchOn = Color(0xFFB8B8FF);

/// Máximo de palabras permitidas en la biografía.
const int _kBioMaxWords = 50;

/// Máximo de caracteres del nombre visible.
const int _kDisplayNameMaxChars = 50;

TextStyle get _titleStyle =>
    const TextStyle(color: _kMain, fontSize: 16, fontWeight: FontWeight.w500);

TextStyle get _subStyle =>
    const TextStyle(color: _kSub, fontSize: 12, fontWeight: FontWeight.w500);

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla principal: Editar perfil
// ─────────────────────────────────────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _profileService = ProfileService();
  final _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isPickingAvatar = false;
  String? _userId;
  String _displayName = '';
  String _username = '';
  String _bio = '';
  String? _avatarUrl;
  Uint8List? _selectedAvatarBytes;
  bool _showSpotifyProfile = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _userId = user.id;

    try {
      final profile = await _profileService.getProfile(user.id);
      if (mounted) {
        setState(() {
          _displayName = profile?.displayName ?? '';
          _username = profile?.username ?? '';
          _bio = profile?.bio ?? '';
          _avatarUrl = profile?.avatarUrl;
          _showSpotifyProfile = profile?.showSpotifyProfile ?? true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Abre una sub-pantalla y, al volver, recarga los datos para que se
  /// vea lo que se acaba de cambiar.
  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _loadData();
  }

  // ── Foto de perfil (esta lógica antes estaba en ProfileScreen) ───────────
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

      // Link público de la foto, con "?v=..." para evitar la caché vieja.
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);
      final freshUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

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
        setState(() => _selectedAvatarBytes = null);
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

  // ── Interruptor "Mostrar perfil de Spotify" ──────────────────────────────
  Future<void> _toggleSpotifyProfile(bool value) async {
    final userId = _userId;
    if (userId == null) return;

    final previous = _showSpotifyProfile;
    // Cambio inmediato en pantalla; si falla el guardado, se revierte.
    setState(() => _showSpotifyProfile = value);

    try {
      await _profileService.updateShowSpotifyProfile(
        userId: userId,
        show: value,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _showSpotifyProfile = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el cambio.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          const SettingsHeader(title: 'Editar perfil'),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: EdgeInsets.fromLTRB(21, 24, 21, bottomPad + 32),
                    children: [
                      // ── Foto de perfil 87x87 ───────────────────────────
                      Center(
                        child: Semantics(
                          button: true,
                          label: 'Cambiar foto de perfil',
                          child: GestureDetector(
                            onTap: _isPickingAvatar ? null : _pickAvatar,
                            child: _EditableAvatar(
                              imageBytes: _selectedAvatarBytes,
                              imageUrl: _avatarUrl,
                              isLoading: _isPickingAvatar,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 44),

                      // ── Nombre visible ─────────────────────────────────
                      _AccountRow(
                        title: 'Nombre visible',
                        subtitle: _displayName.isEmpty ? '—' : _displayName,
                        onTap: () => _push(
                          _DisplayNameScreen(
                            userId: _userId!,
                            currentName: _displayName,
                          ),
                        ),
                      ),
                      const SizedBox(height: 38),

                      // ── Nombre de usuario (pantalla que ya existía) ────
                      _AccountRow(
                        title: 'Nombre de usuario',
                        subtitle: _username.isEmpty ? '—' : _username,
                        onTap: () => _push(
                          UsernameScreen(
                            userId: _userId!,
                            currentUsername: _username,
                          ),
                        ),
                      ),
                      const SizedBox(height: 38),

                      // ── Biografía (sin texto debajo) ───────────────────
                      _SingleRow(
                        title: 'Biografía',
                        onTap: () => _push(
                          _BioScreen(userId: _userId!, currentBio: _bio),
                        ),
                      ),
                      const SizedBox(height: 38),

                      // ── Mostrar perfil de Spotify ──────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Mostrar perfil de Spotify',
                              style: _titleStyle,
                            ),
                          ),
                          _TrailSwitch(
                            value: _showSpotifyProfile,
                            onChanged: _toggleSpotifyProfile,
                          ),
                        ],
                      ),
                      const SizedBox(height: 38),

                      // ── Insignias (no abre ninguna pantalla) ───────────
                      Text('Insignias', style: _titleStyle),
                      const SizedBox(height: 22),
                      const _BadgeSlots(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Foto de perfil con el circulito de editar
// ─────────────────────────────────────────────────────────────────────────────
class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({
    this.imageBytes,
    this.imageUrl,
    this.isLoading = false,
  });

  final Uint8List? imageBytes;
  final String? imageUrl;
  final bool isLoading;

  static const double _size = 87;
  static const double _badgeSize = 31;
  static const double _badgeIconSize = 17;

  @override
  Widget build(BuildContext context) {
    Widget image = const Icon(Icons.person, size: 44, color: Colors.white70);
    if (imageBytes != null) {
      image = Image.memory(imageBytes!, fit: BoxFit.cover);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      image = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.person, size: 44, color: Colors.white70),
      );
    }

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: _size,
            height: _size,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: Color(0xFF3A3A3A),
              shape: BoxShape.circle,
            ),
            child: image,
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: _badgeSize,
              height: _badgeSize,
              decoration: const BoxDecoration(
                color: _kSub,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _kMain,
                        ),
                      )
                    : SvgPicture.asset(
                        'assets/icons/edit white icon.svg',
                        width: _badgeIconSize,
                        height: _badgeIconSize,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filas (idénticas a las de "Manejo de la cuenta")
// ─────────────────────────────────────────────────────────────────────────────
class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _titleStyle),
                const SizedBox(height: 12),
                Text(subtitle, style: _subStyle),
              ],
            ),
          ),
          SvgPicture.asset('assets/icons/right arrow.svg', height: 17),
        ],
      ),
    );
  }
}

class _SingleRow extends StatelessWidget {
  const _SingleRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(child: Text(title, style: _titleStyle)),
          SvgPicture.asset('assets/icons/right arrow.svg', height: 17),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interruptor propio (para controlar exactamente los colores)
// ─────────────────────────────────────────────────────────────────────────────
class _TrailSwitch extends StatelessWidget {
  const _TrailSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  static const double _width = 52;
  static const double _height = 30;
  static const double _thumbSize = 24;
  static const double _padding = 3;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: 'Mostrar perfil de Spotify',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: _width,
          height: _height,
          padding: const EdgeInsets.all(_padding),
          decoration: BoxDecoration(
            color: value ? _kSwitchOn : _kSwitchOff,
            borderRadius: BorderRadius.circular(_height / 2),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: _thumbSize,
              height: _thumbSize,
              decoration: const BoxDecoration(
                color: _kMain,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Los 3 hexágonos de insignias (por ahora no hacen nada)
// ─────────────────────────────────────────────────────────────────────────────
class _BadgeSlots extends StatelessWidget {
  const _BadgeSlots();

  static const double _hexWidth = 76;
  static const double _gap = 36;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          SvgPicture.asset('assets/components/badge empty.svg', width: _hexWidth),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-pantalla: Nombre visible
// ─────────────────────────────────────────────────────────────────────────────
class _DisplayNameScreen extends StatefulWidget {
  const _DisplayNameScreen({required this.userId, required this.currentName});

  final String userId;
  final String currentName;

  @override
  State<_DisplayNameScreen> createState() => _DisplayNameScreenState();
}

class _DisplayNameScreenState extends State<_DisplayNameScreen> {
  late final TextEditingController _ctrl;
  final _profileService = ProfileService();
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      await _profileService.updateDisplayName(
        userId: widget.userId,
        displayName: _ctrl.text,
      );
      if (mounted) setState(() => _success = 'Nombre visible actualizado.');
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          const SettingsHeader(title: 'Nombre visible'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(21, 32, 21, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StyledTextField(
                    controller: _ctrl,
                    label: 'Nombre visible',
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(_kDisplayNameMaxChars),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: _kDanger, fontSize: 13),
                    ),
                  ],
                  if (_success != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _success!,
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _SaveButton(
                    onPressed: _saving ? null : _save,
                    saving: _saving,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-pantalla: Biografía (con máximo de palabras)
// ─────────────────────────────────────────────────────────────────────────────

/// Cuenta las palabras de un texto (separadas por espacios o saltos de línea).
int _countWords(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).length;
}

/// Impide escribir (o pegar) más palabras que el máximo permitido.
class _WordLimitFormatter extends TextInputFormatter {
  _WordLimitFormatter(this.maxWords);

  final int maxWords;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_countWords(newValue.text) > maxWords) return oldValue;
    return newValue;
  }
}

class _BioScreen extends StatefulWidget {
  const _BioScreen({required this.userId, required this.currentBio});

  final String userId;
  final String currentBio;

  @override
  State<_BioScreen> createState() => _BioScreenState();
}

class _BioScreenState extends State<_BioScreen> {
  late final TextEditingController _ctrl;
  final _profileService = ProfileService();
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentBio);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      await _profileService.updateBio(userId: widget.userId, bio: _ctrl.text);
      if (mounted) setState(() => _success = 'Biografía actualizada.');
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = _countWords(_ctrl.text);

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          const SettingsHeader(title: 'Biografía'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(21, 32, 21, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StyledTextField(
                    controller: _ctrl,
                    label: 'Biografía',
                    keyboardType: TextInputType.multiline,
                    minLines: 3,
                    maxLines: 8,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(500),
                      _WordLimitFormatter(_kBioMaxWords),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$words/$_kBioMaxWords palabras',
                      style: _subStyle,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: _kDanger, fontSize: 13),
                    ),
                  ],
                  if (_success != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _success!,
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _SaveButton(
                    onPressed: _saving ? null : _save,
                    saving: _saving,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares (mismo diseño que en "Manejo de la cuenta")
// ─────────────────────────────────────────────────────────────────────────────
class _StyledTextField extends StatelessWidget {
  const _StyledTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: _kMain, fontSize: 15),
      cursorColor: _kMain,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kSub, fontSize: 14),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF3A3A3A)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _kMain),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.onPressed,
    required this.saving,
    this.label = 'Guardar',
  });

  final VoidCallback? onPressed;
  final bool saving;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kMain,
          foregroundColor: _kBg,
          disabledBackgroundColor: const Color(0xFF3A3A3A),
          shape: const StadiumBorder(),
        ),
        child: saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kBg),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}