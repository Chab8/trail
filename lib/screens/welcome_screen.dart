import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_service.dart';
import 'main_navigation_screen.dart';

// ─── Auth view state ────────────────────────────────────────────────────────
enum _AuthView { welcome, login, register }

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  _AuthView _view = _AuthView.welcome;

  // ── Login state ─────────────────────────────────────────────────────────
  final _loginIdCtrl = TextEditingController();
  final _loginPwCtrl = TextEditingController();
  bool _loginLoading = false;
  String? _loginError;

  // ── Register state ───────────────────────────────────────────────────────
  final _regUserCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPwCtrl = TextEditingController();
  final _profileService = ProfileService();
  bool _regLoading = false;
  String? _regError;

  @override
  void dispose() {
    _loginIdCtrl.dispose();
    _loginPwCtrl.dispose();
    _regUserCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPwCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loginIdCtrl.addListener(_refreshLogin);
    _loginPwCtrl.addListener(_refreshLogin);
    _regUserCtrl.addListener(_refreshRegister);
    _regEmailCtrl.addListener(_refreshRegister);
    _regPwCtrl.addListener(_refreshRegister);
  }

  void _refreshLogin() => setState(() {});

  void _refreshRegister() => setState(() {});

  bool get _canLogin =>
      _loginIdCtrl.text.trim().isNotEmpty && _loginPwCtrl.text.length >= 8;

  bool get _canRegister =>
      _regUserCtrl.text.trim().isNotEmpty &&
      _regEmailCtrl.text.trim().isNotEmpty &&
      _regPwCtrl.text.length >= 8;

  // ── Navigation helper ────────────────────────────────────────────────────
  void _switchTo(_AuthView view) {
    FocusScope.of(context).unfocus();
    setState(() {
      _view = view;
      _loginError = null;
      _regError = null;
    });
  }

  Widget _buildPrimaryAuthButton({
    required VoidCallback? onPressed,
    required bool enabled,
    required Widget child,
  }) {
    return ElevatedButton(
      onPressed: (enabled && onPressed != null) ? onPressed : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled
                ? const [Color(0xFF7635FF), Color(0xFF4227C3)]
                : const [Color(0xFF9C9C9C), Color(0xFF9C9C9C)],
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(child: child),
      ),
    );
  }

  // ── Login logic (unchanged from original LoginScreen) ────────────────────
  Future<void> _login() async {
    final identifier = _loginIdCtrl.text.trim();
    final password = _loginPwCtrl.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      setState(
        () => _loginError = 'Completá tu email o usuario, y la contraseña.',
      );
      return;
    }
    setState(() {
      _loginLoading = true;
      _loginError = null;
    });

    try {
      String email;
      if (identifier.contains('@')) {
        email = identifier;
      } else {
        final resolved = await Supabase.instance.client.rpc(
          'get_email_for_username',
          params: {'p_username': identifier},
        );
        if (resolved == null) {
          setState(
            () => _loginError =
                'No encontramos ninguna cuenta con ese nombre de usuario.',
          );
          return;
        }
        email = resolved as String;
      }
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    } on AuthException catch (e) {
      setState(() => _loginError = e.message);
    } catch (_) {
      setState(() => _loginError = 'Ocurrió un error inesperado.');
    } finally {
      if (mounted) setState(() => _loginLoading = false);
    }
  }

  // ── Register logic (unchanged from original RegisterScreen) ──────────────
  Future<void> _register() async {
    final username = _regUserCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final password = _regPwCtrl.text.trim();

    if (username.length < 3) {
      setState(
        () => _regError =
            'El nombre de usuario debe tener al menos 3 caracteres.',
      );
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      setState(() => _regError = 'Completá el email y la contraseña.');
      return;
    }
    setState(() {
      _regLoading = true;
      _regError = null;
    });

    try {
      final taken = await _profileService.isUsernameTaken(username);
      if (taken) {
        setState(
          () => _regError =
              'Ese nombre de usuario ya está en uso. Probá con otro.',
        );
        return;
      }
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      final user = authResponse.user;
      if (user == null) {
        setState(() => _regError = 'No se pudo crear la cuenta.');
        return;
      }
      try {
        await _profileService.createProfile(
          userId: user.id,
          username: username,
        );
      } on PostgrestException catch (e) {
        if (e.code == '23505') {
          setState(
            () => _regError = 'Ese nombre de usuario ya está en uso. Probá con otro (tu cuenta de email/contraseña ya quedó creada).',
          );
        } else {
          setState(
            () => _regError =
                'La cuenta se creó, pero falló el perfil: ${e.message}',
          );
        }
        return;
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    } on AuthException catch (e) {
      setState(() => _regError = e.message);
    } catch (_) {
      setState(() => _regError = 'Ocurrió un error inesperado.');
    } finally {
      if (mounted) setState(() => _regLoading = false);
    }
  }

  // ─── UI Helpers ──────────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      width: 293,
      height: 44,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFFFEFEFE),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF9C9C9C),
          ),
          filled: true,
          fillColor: const Color(0xFF5B5A5F).withOpacity(0.5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ─── Welcome view ────────────────────────────────────────────────────────

  Widget _buildWelcomeContent() {
    return Column(
      key: const ValueKey(_AuthView.welcome),
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 350,
          height: 62,
          child: ElevatedButton(
            onPressed: () => _switchTo(_AuthView.login),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEFEFE),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text(
              'Log In',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 28,
                color: Color(0xFF09080B),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 350,
          height: 62,
          child: ElevatedButton(
            onPressed: () => _switchTo(_AuthView.register),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF242424),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text(
              'Sign Up',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 28,
                color: Color(0xFFFEFEFE),
              ),
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  // ─── Login card ──────────────────────────────────────────────────────────

  Widget _buildLoginCard() {
    return Align(
      key: const ValueKey(_AuthView.login),
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              width: 350,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1920),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title
                  const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFEFEFE),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Email
                  _buildTextField(
                    controller: _loginIdCtrl,
                    hint: 'example@gmail.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  // Password
                  _buildTextField(
                    controller: _loginPwCtrl,
                    hint: 'password',
                    obscureText: true,
                  ),
                  const SizedBox(height: 10),

                  // Forgot password
                  SizedBox(
                    width: 293,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFFEFEFE),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Error message
                  if (_loginError != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 293,
                      child: Text(
                        _loginError!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else
                    const SizedBox(height: 20),

                  // Login button
                  SizedBox(
                    width: 293,
                    height: 44,
                    child: _buildPrimaryAuthButton(
                      onPressed: _loginLoading ? null : _login,
                      enabled: !_loginLoading && _canLogin,
                      child: _loginLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFEFEFE),
                              ),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFEFEFE),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Don't have account
                  GestureDetector(
                    onTap: () => _switchTo(_AuthView.register),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFFEFEFE),
                        ),
                        children: [
                          TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF654CDD),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Google
                  SizedBox(
                    width: 293,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFFFFF),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/components/Google Logo.svg',
                            height: 20,
                            width: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Login with Google',
                            style: GoogleFonts.roboto(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Colors.black.withOpacity(0.54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Apple
                  SizedBox(
                    width: 293,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000000),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/components/Apple Logo.svg',
                            height: 20,
                            width: 20,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFFFFFFFF),
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Login with Apple',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Register card ───────────────────────────────────────────────────────

  Widget _buildRegisterCard() {
    return Align(
      key: const ValueKey(_AuthView.register),
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              width: 350,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1920),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title
                  const Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFEFEFE),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Username
                  _buildTextField(
                    controller: _regUserCtrl,
                    hint: 'name',
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 14),

                  // Email
                  _buildTextField(
                    controller: _regEmailCtrl,
                    hint: 'example@gmail.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  // Password
                  _buildTextField(
                    controller: _regPwCtrl,
                    hint: 'password',
                    obscureText: true,
                  ),

                  // Error message
                  if (_regError != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 293,
                      child: Text(
                        _regError!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else
                    const SizedBox(height: 24),

                  // Sign Up button
                  SizedBox(
                    width: 293,
                    height: 44,
                    child: _buildPrimaryAuthButton(
                      onPressed: _regLoading ? null : _register,
                      enabled: !_regLoading && _canRegister,
                      child: _regLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFEFEFE),
                              ),
                            )
                          : const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFEFEFE),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Have account
                  GestureDetector(
                    onTap: () => _switchTo(_AuthView.login),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFFEFEFE),
                        ),
                        children: [
                          TextSpan(text: 'Have an account? '),
                          TextSpan(
                            text: 'Log In',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF654CDD),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Google
                  SizedBox(
                    width: 293,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFFFFF),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/components/Google Logo.svg',
                            height: 20,
                            width: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Sign Up with Google',
                            style: GoogleFonts.roboto(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Colors.black.withOpacity(0.54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Apple
                  SizedBox(
                    width: 293,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF000000),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/components/Apple Logo.svg',
                            height: 20,
                            width: 20,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFFFFFFFF),
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Sign Up with Apple',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Main build ──────────────────────────────────────────────────────────

  Widget _buildCurrentView() {
    switch (_view) {
      case _AuthView.welcome:
        return _buildWelcomeContent();
      case _AuthView.login:
        return _buildLoginCard();
      case _AuthView.register:
        return _buildRegisterCard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back button en login/register → vuelve a welcome en vez de salir de la app
      canPop: _view == _AuthView.welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _switchTo(_AuthView.welcome);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF09080B),
        // El teclado NO mueve el layout
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: [
              // ── Logo — siempre fijo en el mismo lugar ──────────────────
              const SizedBox(height: 60),
              Center(
                child: SvgPicture.asset(
                  'assets/components/trail_logo_text_white.svg',
                  height: 48,
                ),
              ),

              // ── Contenido animado — solo esto cambia ──────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  // Alinea el contenido al top para que la tarjeta no salte
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  ),
                  child: _buildCurrentView(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
