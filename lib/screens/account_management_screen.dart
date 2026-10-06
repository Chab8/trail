import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_service.dart';
import '../widgets/settings_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colores y estilos compartidos
// ─────────────────────────────────────────────────────────────────────────────
const Color _kMain = Color(0xFFFEFEFE);
const Color _kSub = Color(0xFF9C9C9C);
const Color _kDanger = Color(0xFFE01414);
const Color _kBg = Color(0xFF09080B);

TextStyle get _titleStyle =>
    const TextStyle(color: _kMain, fontSize: 16, fontWeight: FontWeight.w500);

TextStyle get _subStyle =>
    const TextStyle(color: _kSub, fontSize: 12, fontWeight: FontWeight.w500);

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla principal: Manejo de la cuenta
// ─────────────────────────────────────────────────────────────────────────────
class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  final _profileService = ProfileService();

  bool _isLoading = true;
  String _email = '';
  String _username = '';
  String _phone = '';
  String? _countryCode;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _userId = user.id;
    _email = user.email ?? '';

    try {
      final profile = await _profileService.getProfile(user.id);
      if (mounted) {
        setState(() {
          _username = profile?.username ?? '';
          _phone = profile?.phone ?? '';
          _countryCode = profile?.countryCode;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          const SettingsHeader(title: 'Manejo de la cuenta'),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: EdgeInsets.fromLTRB(21, 32, 21, bottomPad + 32),
                    children: [
                      _AccountRow(
                        title: 'Email',
                        subtitle: _email.isEmpty ? '—' : _email,
                        onTap: () => _push(const _EmailScreen()),
                      ),
                      const SizedBox(height: 38),
                      _AccountRow(
                        title: 'Nombre de usuario',
                        subtitle: _username.isEmpty ? '—' : _username,
                        onTap: () => _push(
                          _UsernameScreen(
                            userId: _userId!,
                            currentUsername: _username,
                          ),
                        ),
                      ),
                      const SizedBox(height: 38),
                      _AccountRow(
                        title: 'Teléfono',
                        subtitle: _phone.isEmpty ? '—' : _phone,
                        onTap: () => _push(
                          _PhoneScreen(
                            userId: _userId!,
                            currentPhone: _phone,
                            defaultCountryCode: _countryCode,
                          ),
                        ),
                      ),
                      const SizedBox(height: 38),
                      _AccountRow(
                        title: 'Contraseña',
                        subtitle: '••••••••••',
                        onTap: () => _push(const _PasswordScreen()),
                      ),
                      const SizedBox(height: 38),
                      _AccountRow(
                        title: 'País',
                        subtitle: _countryCode == null
                            ? '—'
                            : '${_countryFlag(_countryCode!)} ${CountryParser.parseCountryCode(_countryCode!).name}',
                        onTap: () => _push(
                          _CountryScreen(
                            userId: _userId!,
                            currentCode: _countryCode,
                          ),
                        ),
                      ),
                      const SizedBox(height: 38),
                      _IdRow(userId: _userId ?? ''),
                      const SizedBox(height: 46),
                      _SingleRow(
                        title: 'Descargar mis datos',
                        onTap: () => _push(
                          const _PlaceholderScreen(
                            title: 'Descargar mis datos',
                          ),
                        ),
                      ),
                      const SizedBox(height: 46),
                      _SingleRow(
                        title: 'Cerrar sesión en todos los dispositivos',
                        onTap: () => _push(
                          const _PlaceholderScreen(
                            title: 'Cerrar sesión en todos los dispositivos',
                          ),
                        ),
                      ),
                      const SizedBox(height: 46),
                      _SingleRow(
                        title: 'Desactivar cuenta temporalmente',
                        onTap: () => _push(
                          const _PlaceholderScreen(
                            title: 'Desactivar cuenta temporalmente',
                          ),
                        ),
                      ),
                      const SizedBox(height: 46),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          // Funcionalidad pendiente
                        },
                        child: const Text(
                          'Eliminar cuenta',
                          style: TextStyle(
                            color: _kDanger,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets de fila
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
        // El arrow se centra verticalmente en todo el bloque (título + hueco +
        // subtítulo), así que queda a la mitad entre ambos textos.
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

class _IdRow extends StatelessWidget {
  const _IdRow({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final displayId = userId.length > 8
        ? userId.substring(0, 8).toUpperCase()
        : userId.toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID del usuario', style: _titleStyle),
              const SizedBox(height: 12),
              Text(displayId, style: _subStyle),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: userId));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ID copiado al portapapeles'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: _kMain,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Copiar',
              style: TextStyle(
                color: _kBg,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-pantalla: Email (solo lectura)
// ─────────────────────────────────────────────────────────────────────────────
class _EmailScreen extends StatelessWidget {
  const _EmailScreen();

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          const SettingsHeader(title: 'Email'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(21, 32, 21, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email actual', style: _subStyle),
                  const SizedBox(height: 12),
                  Text(email.isEmpty ? '—' : email, style: _titleStyle),
                  const SizedBox(height: 32),
                  Text(
                    'La posibilidad de cambiar el email estará disponible próximamente.',
                    style: _subStyle,
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
// Sub-pantalla: Nombre de usuario (editable)
// ─────────────────────────────────────────────────────────────────────────────
class _UsernameScreen extends StatefulWidget {
  const _UsernameScreen({required this.userId, required this.currentUsername});

  final String userId;
  final String currentUsername;

  @override
  State<_UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<_UsernameScreen> {
  late final TextEditingController _ctrl;
  final _profileService = ProfileService();
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentUsername);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _ctrl.text.trim();
    if (username.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      await _profileService.updateUsername(
        userId: widget.userId,
        username: username,
      );
      if (mounted) setState(() => _success = 'Nombre de usuario actualizado.');
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.code == '23505'
              ? 'Ese nombre de usuario ya está en uso.'
              : 'No se pudo guardar: ${e.message}';
        });
      }
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
          const SettingsHeader(title: 'Nombre de usuario'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(21, 32, 21, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StyledTextField(
                    controller: _ctrl,
                    label: 'Nombre de usuario',
                    keyboardType: TextInputType.text,
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
// Sub-pantalla: Teléfono (con selector de código de país)
// ─────────────────────────────────────────────────────────────────────────────
class _PhoneScreen extends StatefulWidget {
  const _PhoneScreen({
    required this.userId,
    required this.currentPhone,
    this.defaultCountryCode,
  });

  final String userId;
  final String currentPhone;

  /// Código ISO del país ya guardado en el perfil. Se usa solo como
  /// valor inicial del selector de código telefónico.
  final String? defaultCountryCode;

  @override
  State<_PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<_PhoneScreen> {
  late final TextEditingController _ctrl;
  Country? _dialCountry;
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();

    // Intentamos pre-seleccionar el código del país guardado.
    // Si el número ya tiene un prefijo (+XX...) lo extraemos y buscamos
    // el país por código telefónico; si no, usamos el país del perfil.
    final stored = widget.currentPhone.trim();
    Country? preselected;

    if (stored.startsWith('+')) {
      // Detectar el dial code a partir del número guardado
      try {
        final allCountries = CountryService().getAll();
        // Ordenar del más largo al más corto para mayor precisión
        final sorted = List<Country>.from(allCountries)
          ..sort((a, b) => b.phoneCode.length.compareTo(a.phoneCode.length));
        for (final c in sorted) {
          if (stored.startsWith('+${c.phoneCode}')) {
            preselected = c;
            break;
          }
        }
      } catch (_) {}
    }

    // Si no se detectó por el número, usar el país del perfil como default.
    if (preselected == null && widget.defaultCountryCode != null) {
      try {
        preselected = CountryParser.parseCountryCode(
          widget.defaultCountryCode!,
        );
      } catch (_) {}
    }

    _dialCountry = preselected;

    // El campo de texto solo muestra la parte local (sin prefijo).
    String localNumber = stored;
    if (_dialCountry != null &&
        stored.startsWith('+${_dialCountry!.phoneCode}')) {
      localNumber = stored.substring(_dialCountry!.phoneCode.length + 1).trim();
    }
    _ctrl = TextEditingController(text: localNumber);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _openDialPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        backgroundColor: const Color(0xFF141218),
        textStyle: const TextStyle(color: _kMain, fontSize: 15),
        searchTextStyle: const TextStyle(color: _kMain, fontSize: 15),
        inputDecoration: InputDecoration(
          hintText: 'Buscar país...',
          hintStyle: const TextStyle(color: _kSub),
          prefixIcon: const Icon(Icons.search, color: _kSub),
          filled: true,
          fillColor: const Color(0xFF1E1C22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      onSelect: (Country c) => setState(() => _dialCountry = c),
    );
  }

  Future<void> _save() async {
    final local = _ctrl.text.trim();
    if (local.isEmpty) return;

    // Guardar en formato internacional si se eligió código.
    final fullPhone = _dialCountry != null
        ? '+${_dialCountry!.phoneCode} $local'
        : local;

    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'phone': fullPhone})
          .eq('id', widget.userId);
      if (mounted) setState(() => _success = 'Teléfono actualizado.');
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() => _error = 'Error: ${e.message} [${e.code}]');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
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
          const SettingsHeader(title: 'Teléfono'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(21, 32, 21, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Fila: [selector código] | [campo número] ─────────────
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF3A3A3A)),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Selector de código
                        GestureDetector(
                          onTap: _openDialPicker,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: 16,
                              bottom: 12,
                              right: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _dialCountry == null
                                      ? '🏳️'
                                      : _countryFlag(_dialCountry!.countryCode),
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _dialCountry == null
                                      ? '+--'
                                      : '+${_dialCountry!.phoneCode}',
                                  style: const TextStyle(
                                    color: _kMain,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: _kSub,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Divisor vertical
                        Container(
                          width: 1,
                          height: 24,
                          color: const Color(0xFF3A3A3A),
                          margin: const EdgeInsets.only(right: 12),
                        ),
                        // Campo número local
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: _kMain, fontSize: 15),
                            cursorColor: _kMain,
                            decoration: const InputDecoration(
                              hintText: 'Número de teléfono',
                              hintStyle: TextStyle(color: _kSub, fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                  const SizedBox(height: 28),
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
// Sub-pantalla: Contraseña (cambio con vieja + nueva + confirmar)
// ─────────────────────────────────────────────────────────────────────────────
class _PasswordScreen extends StatefulWidget {
  const _PasswordScreen();

  @override
  State<_PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<_PasswordScreen> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final oldPwd = _oldCtrl.text;
    final newPwd = _newCtrl.text;
    final confirmPwd = _confirmCtrl.text;

    if (oldPwd.isEmpty || newPwd.isEmpty || confirmPwd.isEmpty) {
      setState(() => _error = 'Completá todos los campos.');
      return;
    }
    if (newPwd != confirmPwd) {
      setState(() => _error = 'Las contraseñas nuevas no coinciden.');
      return;
    }
    if (newPwd.length < 6) {
      setState(
        () => _error = 'La nueva contraseña debe tener al menos 6 caracteres.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });

    try {
      final email = Supabase.instance.client.auth.currentUser?.email ?? '';
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: oldPwd,
      );
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPwd),
      );
      if (mounted) {
        setState(() => _success = 'Contraseña actualizada correctamente.');
        _oldCtrl.clear();
        _newCtrl.clear();
        _confirmCtrl.clear();
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message.contains('Invalid login')
              ? 'La contraseña actual es incorrecta.'
              : 'Error: ${e.message}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo actualizar la contraseña.');
      }
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
          const SettingsHeader(title: 'Contraseña'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(21, 32, 21, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StyledTextField(
                    controller: _oldCtrl,
                    label: 'Contraseña actual',
                    obscure: !_showOld,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showOld ? Icons.visibility_off : Icons.visibility,
                        color: _kSub,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _showOld = !_showOld),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _StyledTextField(
                    controller: _newCtrl,
                    label: 'Nueva contraseña',
                    obscure: !_showNew,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showNew ? Icons.visibility_off : Icons.visibility,
                        color: _kSub,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _showNew = !_showNew),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _StyledTextField(
                    controller: _confirmCtrl,
                    label: 'Repetir nueva contraseña',
                    obscure: !_showConfirm,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showConfirm ? Icons.visibility_off : Icons.visibility,
                        color: _kSub,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _showConfirm = !_showConfirm),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: _kDanger, fontSize: 13),
                    ),
                  ],
                  if (_success != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _success!,
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  _SaveButton(
                    onPressed: _saving ? null : _save,
                    saving: _saving,
                    label: 'Cambiar contraseña',
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
// Helper: convierte ISO-3166-1 alpha-2 en emoji de bandera
// ─────────────────────────────────────────────────────────────────────────────
String _countryFlag(String code) {
  return code
      .toUpperCase()
      .runes
      .map((r) => String.fromCharCode(r + 0x1F1A5))
      .join();
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-pantalla: País (country_picker)
// ─────────────────────────────────────────────────────────────────────────────
class _CountryScreen extends StatefulWidget {
  const _CountryScreen({required this.userId, this.currentCode});

  final String userId;
  final String? currentCode;

  @override
  State<_CountryScreen> createState() => _CountryScreenState();
}

class _CountryScreenState extends State<_CountryScreen> {
  Country? _selected;
  bool _saving = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    if (widget.currentCode != null) {
      try {
        _selected = CountryParser.parseCountryCode(widget.currentCode!);
      } catch (_) {
        _selected = null;
      }
    }
  }

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() {
      _saving = true;
      _error = null;
      _success = null;
    });
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'country_code': _selected!.countryCode})
          .eq('id', widget.userId);
      if (mounted) setState(() => _success = 'País actualizado.');
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = 'Error: ${e.message} [${e.code}]');
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        backgroundColor: const Color(0xFF141218),
        textStyle: const TextStyle(color: _kMain, fontSize: 15),
        searchTextStyle: const TextStyle(color: _kMain, fontSize: 15),
        inputDecoration: InputDecoration(
          hintText: 'Buscar país...',
          hintStyle: const TextStyle(color: _kSub),
          prefixIcon: const Icon(Icons.search, color: _kSub),
          filled: true,
          fillColor: const Color(0xFF1E1C22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      onSelect: (Country c) {
        setState(() {
          _selected = c;
          _success = null;
          _error = null;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          const SettingsHeader(title: 'País'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(21, 32, 21, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector tocable
                  GestureDetector(
                    onTap: _openPicker,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1C22),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _selected == null
                                ? Text('Seleccionar país', style: _subStyle)
                                : Text(
                                    '${_countryFlag(_selected!.countryCode)}  ${_selected!.name}',
                                    style: _titleStyle,
                                  ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _kSub,
                            size: 22,
                          ),
                        ],
                      ),
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
                    onPressed: (_saving || _selected == null) ? null : _save,
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
// Sub-pantalla placeholder
// ─────────────────────────────────────────────────────────────────────────────
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          SettingsHeader(title: title),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _StyledTextField extends StatelessWidget {
  const _StyledTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscure = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: _kMain, fontSize: 15),
      cursorColor: _kMain,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kSub, fontSize: 14),
        suffixIcon: suffixIcon,
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
          // Botón completamente redondeado: el radio es la mitad de la altura.
          shape: StadiumBorder(),
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
