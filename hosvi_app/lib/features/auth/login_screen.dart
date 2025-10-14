// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passCtrl  = TextEditingController();
  bool rememberMe = false;
  bool loading = false;
  bool _obscure = true; // <-- agrégalo arriba del build dentro del State
  String? errorText; // se muestra abajo del form

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  // Mapea los errores de Firebase a textos entendibles
  String _authErrorText(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'El correo no tiene un formato válido.';
        case 'user-not-found':
          return 'No existe una cuenta con ese correo.';
        case 'wrong-password':
          return 'Contraseña incorrecta.';
        case 'user-disabled':
          return 'Esta cuenta está deshabilitada.';
        case 'too-many-requests':
          return 'Demasiados intentos. Intenta de nuevo más tarde.';
        case 'network-request-failed':
          return 'Sin conexión. Verifica tu internet.';
        default:
          return 'No se pudo iniciar sesión. (${e.code})';
      }
    }
    return 'Ocurrió un error inesperado.';
  }

  Future<void> _loginEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { loading = true; errorText = null; });
    try {
      await AuthService.instance.signInEmail(
        emailCtrl.text.trim(),
        passCtrl.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setBool('remember_admin', true);
      } else {
        await prefs.remove('remember_admin');
      }
      // No navegamos aquí: AuthGate decide la pantalla.
    } catch (e) {
      setState(() => errorText = _authErrorText(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loginGuest() async {
    setState(() { loading = true; errorText = null; });
    try {
      await AuthService.instance.signInAnon();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('last_login_guest', true);
      // AuthGate se encargará del resto
    } catch (e) {
      setState(() => errorText = 'No se pudo entrar como invitado.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      hintText: 'tucorreo@dominio.com',
                    ),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return 'Escribe tu correo.';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(text)) {
                        return 'El correo no es válido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                        tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                      ),
                    ),
                    validator: (v) {
                      final text = v ?? '';
                      if (text.isEmpty) return 'Escribe tu contraseña.';
                      if (text.length < 6) return 'Mínimo 6 caracteres.';
                      return null;
                    },
                    onFieldSubmitted: (_) => _loginEmail(),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: rememberMe,
                    onChanged: loading ? null : (v) => setState(() => rememberMe = v ?? false),
                    title: const Text('Recordarme (solo administradores)'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(errorText!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : _loginEmail,
                      icon: const Icon(Icons.lock_open),
                      label: loading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Entrar (email)'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: loading ? null : _loginGuest,
                    child: const Text('Entrar como invitado'),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    '¿Eres profe y necesitas acceso de administrador?\n'
                        'Inicia sesión con tu correo institucional. Si no tienes cuenta, contáctanos para habilitarla.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
