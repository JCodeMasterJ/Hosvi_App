import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final btnStyle = ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, 64),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text("HOSVI APP")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Spacer(),
            ElevatedButton.icon(
              style: btnStyle,
              //onPressed: () => Navigator.pushNamed(context, "/debug"),
              onPressed: () => Navigator.of(context).pushNamed('/map'),
              icon: const Icon(Icons.navigation), // 👈 el icono va aquí
              label: const Text("Iniciar guía"),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: btnStyle,
              onPressed: () {}, // se activa en Fase 3
              icon: const Icon(Icons.accessible_forward),
              label: const Text("Ver accesos cercanos"),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: btnStyle,
              onPressed: () {}, // se activa en Fase 2
              icon: const Icon(Icons.explore),
              label: const Text("Modo simulación"),
            ),
            const Spacer(),
            Text("Activa TalkBack para probar accesibilidad",
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
