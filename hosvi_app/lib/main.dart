// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'features/voice/tts_service.dart';

// 👇 imports RELATIVOS para evitar problemas de nombre de paquete
import 'features/auth/auth_gate.dart';          // el gate
import 'ui/home_screen.dart';                   // tu pantalla de 3 botones
import 'ui/debug_points_screen.dart';
import 'ui/map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase primero
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2) TTS
  await TtsService.instance.init(
    preferredLang: 'es-CO',
    rate: 0.42,
  );

  // 3) Riverpod + App
  runApp(const ProviderScope(child: HosviApp()));
}

class HosviApp extends StatelessWidget {
  const HosviApp({super.key});

  @override
  Widget build(BuildContext context) {
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

    return MaterialApp(
      title: 'HOSVI APP',
      debugShowCheckedModeBanner: false,
      theme: light,
      darkTheme: dark,
      highContrastTheme: highContrastLight,
      highContrastDarkTheme: highContrastDark,
      themeMode: ThemeMode.system,

      // 👉 IMPORTANTÍSIMO: arrancamos por el AuthGate
      home: const AuthGate(),

      // Rutas auxiliares (puedes seguir navegando por nombre si quieres)
      routes: {
        "/home": (_) => const HomeScreen(),
        "/debug": (_) => const DebugPointsScreen(),
        "/map": (_) => const MapScreen(),
      },
    );
  }
}
