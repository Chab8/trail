import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'register_screen.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _identifierController.addListener(_refresh);
    _passwordController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  bool get _canLogin => _identifierController.text.trim().isNotEmpty &&
      _passwordController.text.length >= 8;

  Future<void> _login() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      setState(
        () => _errorMessage = 'Completá tu email o usuario, y la contraseña.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String email;

      if (identifier.contains('@')) {
        email = identifier;
      } else {
        // Es un nombre de usuario: le pedimos a Supabase el email asociado.
        final resolved = await Supabase.instance.client.rpc(
          'get_email_for_username',
          params: {'p_username': identifier},
        );

        if (resolved == null) {
          setState(
            () => _errorMessage = 'Wrong username or password, try again',
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
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Ocurrió un error inesperado.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

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
        style: const TextStyle(fontSize: 15, color: Color(0xFFFEFEFE)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09080B),
      body: SafeArea(
        child: Column(
          children: [
            // ── Logo ──────────────────────────────────────────────────────
            const SizedBox(height: 60),
            Center(
              child: SvgPicture.asset(
                'assets/components/trail_logo_text_white.svg',
                height: 48,
              ),
            ),

            const Spacer(),

            // ── Card ──────────────────────────────────────────────────────
            Container(
              width: 350,
              height: 460,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1920),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title
                  const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFEFEFE),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Email field
                  _buildTextField(
                    controller: _identifierController,
                    hint: 'example@gmail.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  // Password field
                  _buildTextField(
                    controller: _passwordController,
                    hint: 'password',
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),

                  // Forgot Password — alineado a la derecha del campo (293px)
                  SizedBox(
                    width: 293,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {}, // sin funcionalidad por ahora
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFFFEFEFE),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 293,
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else
                    const SizedBox(height: 24),

                  // Login button
                  SizedBox(
                    width: 293,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : (_canLogin ? _login : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: !_isLoading && _canLogin
                                ? const [Color(0xFF7635FF), Color(0xFF4227C3)]
                                : const [Color(0xFF9C9C9C), Color(0xFF9C9C9C)],
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Center(
                          child: _isLoading
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
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFEFEFE),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Don't have an account?
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
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
                  const SizedBox(height: 40),

                  // Login with Google
                  SizedBox(
                    width: 293,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {}, // sin funcionalidad por ahora
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
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: Colors.black.withOpacity(0.54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Login with Apple
                  SizedBox(
                    width: 293,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {}, // sin funcionalidad por ahora
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
                              fontSize: 17,
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

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
