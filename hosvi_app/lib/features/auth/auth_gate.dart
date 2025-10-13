// lib/features/auth/auth_gate.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:hosvi.app/features/auth/login_screen.dart';
import 'package:hosvi.app/features/admin/admin_screen.dart';
import 'package:hosvi.app/services/auth_service.dart';
import 'package:hosvi.app/ui/home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<String> _roleWithTimeout(User u) async {
    try {
      return await AuthService.instance
          .getRoleFor(u)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return 'user';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authState(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }

        final user = snap.data;

        // Sin sesión -> Login
        if (user == null) return const LoginScreen();

        // Invitado -> directo a Home (esta sesión)
        if (user.isAnonymous) return const HomeScreen();

        // Usuario con email -> resolver rol y rutear
        return FutureBuilder<String>(
          future: _roleWithTimeout(user),
          builder: (context, roleSnap) {
            if (!roleSnap.hasData) return const _Loading();
            final role = (roleSnap.data ?? 'user').toLowerCase();
            return role == 'admin' ? const AdminScreen() : const HomeScreen();
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
