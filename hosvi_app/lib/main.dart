import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/voice/tts_service.dart';
import 'ui/home_screen.dart';
import 'ui/debug_points_screen.dart';
import 'ui/map_screen.dart'; // ← tu pantalla de mapa principal

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Inicializa el TTS (versión singleton)
  await TtsService.instance.init(
    preferredLang: 'es-CO',
    rate: 0.42, // más lento y entendible
  );

  runApp(const ProviderScope(child: HosviApp()));
}

class HosviApp extends StatelessWidget {
  const HosviApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HOSVI APP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      initialRoute: "/map", // ← puedes dejar /map para probar directo el mapa
      routes: {
        "/": (_) => const HomeScreen(),
        "/debug": (_) => const DebugPointsScreen(),
        "/map": (_) => const MapScreen(),
      },
    );
  }
}
