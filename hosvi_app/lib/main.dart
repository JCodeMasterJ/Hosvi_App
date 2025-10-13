// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'features/voice/tts_service.dart';
import 'features/auth/auth_gate.dart'; // login + admin + invitado
import 'ui/home_screen.dart';
import 'ui/debug_points_screen.dart';
import 'ui/map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1️⃣ Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2️⃣ Revisar sesión anterior
  final prefs = await SharedPreferences.getInstance();

  final wasGuest = prefs.getBool('last_login_guest') ?? false;
  final rememberAdmin = prefs.getBool('remember_admin') ?? false;
  final currentUser = FirebaseAuth.instance.currentUser;

  // 🔹 Si el último ingreso fue como invitado → cerrar sesión
  if (wasGuest && currentUser != null) {
    await FirebaseAuth.instance.signOut();
    await prefs.remove('last_login_guest');
  }

  // 🔹 Si había un admin logeado y no marcó “Recordarme” → cerrar sesión también
  if (!rememberAdmin && currentUser != null && !currentUser.isAnonymous) {
    await FirebaseAuth.instance.signOut();
  }

  // 3️⃣ Inicializar TTS
  await TtsService.instance.init(
    preferredLang: 'es-CO',
    rate: 0.42,
  );

  // 4️⃣ Ejecutar la app
  runApp(const ProviderScope(child: HosviApp()));
}

class HosviApp extends StatelessWidget {
  const HosviApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ==== Temas ====
    final light = ThemeData(
      colorSchemeSeed: Colors.teal,
      brightness: Brightness.light,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final dark = ThemeData(
      colorSchemeSeed: Colors.teal,
      brightness: Brightness.dark,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final highContrastLight = light.copyWith(
      colorScheme: light.colorScheme.copyWith(
        primary: Colors.black,
        secondary: Colors.black87,
        surface: Colors.white,
      ),
      textTheme: light.textTheme.apply(
        bodyColor: Colors.black,
        displayColor: Colors.black,
      ),
    );

    final highContrastDark = dark.copyWith(
      colorScheme: dark.colorScheme.copyWith(
        primary: Colors.white,
        secondary: Colors.white70,
        surface: Colors.black,
      ),
      textTheme: dark.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );

    // ==== App ====
    return MaterialApp(
      title: 'HOSVI APP',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      highContrastTheme: highContrastLight,
      highContrastDarkTheme: highContrastDark,
      themeMode: ThemeMode.system,

      // ✅ Punto de entrada principal con lógica de sesión
      home: const AuthGate(),

      // Rutas opcionales
      routes: {
        "/home": (_) => const HomeScreen(),
        "/debug": (_) => const DebugPointsScreen(),
        "/map": (_) => const MapScreen(),
      },
    );
  }
}
