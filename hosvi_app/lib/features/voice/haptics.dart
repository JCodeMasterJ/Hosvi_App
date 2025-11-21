import 'package:vibration/vibration.dart';
import 'dart:async';

/// Servicio centralizado de vibración (Haptics)
/// Compatible con llamadas directas desde toda la app.
class Haptics {
  /// Verifica si el dispositivo puede vibrar
  Future<bool> get canVibrate async => await Vibration.hasVibrator() ?? false;

  /// Vibración corta (≈100 ms)
  Future<void> short() async {
    if (await canVibrate) {
      await Vibration.vibrate(duration: 100);
    }
  }

  /// Vibración doble (2 pulsos cortos)
  Future<void> double() async {
    if (await canVibrate) {
      await Vibration.vibrate(pattern: [0, 80, 100, 80]);
    }
  }

  /// Vibración larga (≈300 ms)
  Future<void> long() async {
    if (await canVibrate) {
      await Vibration.vibrate(duration: 300);
    }
  }

  /// Patrón personalizado, ejemplo: "corto,corto,largo"
  Future<void> fromPattern(String? patron) async {
    if (patron == null || patron.trim().isEmpty) return;
    final parts = patron
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    for (final p in parts) {
      if (p == 'largo') {
        await long();
      } else {
        await short();
      }
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }
}
