import 'package:flutter/material.dart';
import 'package:hosvi.app/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _loginEmail() async {
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.instance.signInEmail(_email.text, _pass.text);
    } catch (e) {
      setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginAnon() async {
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.instance.signInAnon();
    } catch (e) {
      setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Correo'), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 8),
            TextField(controller: _pass, decoration: const InputDecoration(labelText: 'Contraseña'), obscureText: true),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _loginEmail,
              child: _loading ? const CircularProgressIndicator() : const Text('Entrar (email)'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _loading ? null : _loginAnon, child: const Text('Entrar como invitado')),
          ],
        ),
      ),
    );
  }
}
