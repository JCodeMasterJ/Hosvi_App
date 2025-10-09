import 'package:vibration/vibration.dart';
import 'dart:async';

/// Patrones: "corto", "largo", separados por coma.
/// Ej: "corto,corto,largo"
Future<void> vibraPatron(String patron) async {
  final parts = patron.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
  for (final p in parts) {
    await Vibration.vibrate(duration: p == "largo" ? 300 : 120);
    await Future.delayed(const Duration(milliseconds: 120));
  }
}
