import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hosvi.app/features/auth/login_screen.dart';
import 'package:hosvi.app/services/auth_service.dart';
import 'package:hosvi.app/ui/home_screen.dart'; // tu pantalla actual con 3 botones
import 'package:hosvi.app/features/admin/admin_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authState(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) {
          return const LoginScreen();
        }
        return FutureBuilder<String>(
          future: AuthService.instance.getRoleFor(user),
          builder: (context, roleSnap) {
            if (!roleSnap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final role = roleSnap.data!;
            if (role == 'admin') {
              return const AdminScreen();
            }
            return const HomeScreen(); // usuario normal → tu app de siempre
          },
        );
      },
    );
  }
}
