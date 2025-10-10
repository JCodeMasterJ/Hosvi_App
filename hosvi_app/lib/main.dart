import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/voice/tts_service.dart';
import 'ui/home_screen.dart';
import 'ui/debug_points_screen.dart';
import 'ui/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TTS (singleton) en español, más pausado
  await TtsService.instance.init(
    preferredLang: 'es-CO',
    rate: 0.42,
  );

  runApp(const ProviderScope(child: HosviApp()));
}

class HosviApp extends StatelessWidget {
  const HosviApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Tema base claro
    final ThemeData light = ThemeData(
      colorSchemeSeed: Colors.teal,
      brightness: Brightness.light,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    // Tema base oscuro
    final ThemeData dark = ThemeData(
      colorSchemeSeed: Colors.teal,
      brightness: Brightness.dark,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    // Variantes de alto contraste (se activarán cuando las pidamos)
    final ThemeData highContrastLight = light.copyWith(
      colorScheme: light.colorScheme.copyWith(
        primary: Colors.black,
        secondary: Colors.black87,
        surface: Colors.white,
      ),
      textTheme: light.textTheme.apply(
        // más “peso” para legibilidad
        bodyColor: Colors.black,
        displayColor: Colors.black,
      ),
    );

    final ThemeData highContrastDark = dark.copyWith(
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

      // Temas preparados (por ahora se verán como siempre;
      // más adelante prenderemos el alto contraste desde la UI)
      theme: light,
      darkTheme: dark,
      highContrastTheme: highContrastLight,
      highContrastDarkTheme: highContrastDark,
      themeMode: ThemeMode.system,

      // Si quisieras fijar un factor global de texto más adelante,
      // lo haremos en `builder` con MediaQuery (por ahora default).
      builder: (context, child) => child!,

      initialRoute: "/map",
      routes: {
        "/": (_) => const HomeScreen(),
        "/debug": (_) => const DebugPointsScreen(),
        "/map": (_) => const MapScreen(),
      },
    );
  }
}
