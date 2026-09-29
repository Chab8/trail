import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/profile_service.dart';
import 'main_navigation_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _profileService = ProfileService();

  static const _fieldStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );
  static const _labelStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_refresh);
    _emailController.addListener(_refresh);
    _passwordController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  bool get _canRegister =>
      _usernameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.length >= 8;

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (username.length < 3) {
      setState(
        () => _errorMessage =
            'El nombre de usuario debe tener al menos 3 caracteres.',
      );
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Completá el email y la contraseña.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Chequeamos ANTES de crear la cuenta si el username ya está tomado,
      // para no dejar una cuenta de auth "huérfana" sin perfil.
      final taken = await _profileService.isUsernameTaken(username);
      if (taken) {
        setState(
          () => _errorMessage =
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
        setState(() => _errorMessage = 'No se pudo crear la cuenta.');
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
            () => _errorMessage = 'Ese nombre de usuario ya está en uso. Probá con otro (tu cuenta de email/contraseña ya quedó creada).',
          );
        } else {
          setState(
            () => _errorMessage =
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
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Ocurrió un error inesperado.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Crear cuenta',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _usernameController,
                  style: _fieldStyle,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de usuario',
                    labelStyle: _labelStyle,
                    helperText: 'Mínimo 3 caracteres. Tiene que ser único.',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  style: _fieldStyle,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: _labelStyle,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  style: _fieldStyle,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    labelStyle: _labelStyle,
                  ),
                  obscureText: true,
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : (_canRegister ? _register : null),
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
                          colors: !_isLoading && _canRegister
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
                                ),
                              )
                            : const Text(
                                'Registrarme',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
