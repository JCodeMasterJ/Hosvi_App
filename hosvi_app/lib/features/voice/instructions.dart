// lib/features/voice/instructions.dart
import '../voice/tts_service.dart';
import '../voice/haptics.dart';

class InstructionSpeaker {
  final TtsService tts;
  final Haptics haptics;

  InstructionSpeaker(this.tts, this.haptics);

  // ============================================================
  // TRADUCCIÓN DE MANIOBRAS (para navegación paso a paso)
  // ============================================================
  String actionText(String m, {int? exit}) {
    switch (m) {
      case 'turn-left':
        return 'gira a la izquierda';
      case 'turn-right':
        return 'gira a la derecha';
      case 'straight':
        return 'continúa recto';
      case 'slight-left':
        return 'desvío leve a la izquierda';
      case 'slight-right':
        return 'desvío leve a la derecha';
      case 'uturn-left':
      case 'uturn-right':
        return 'retorno';
      case 'roundabout-right':
      case 'roundabout-left':
        return 'glorieta, toma la salida ${exit ?? 1}';
      default:
        return 'continúa recto';
    }
  }

  // ============================================================
  // NAVEGACIÓN (Prep - Near - Now)
  // ============================================================

  /// 1. Preparación (distancia mayor)
  void speakPrep(String maneuver, {int? exit}) {
    tts.speak('Prepararse para girar. ${actionText(maneuver, exit: exit)}');
    haptics.short(); // vibración suave
  }

  /// 2. Aviso cercano
  void speakNear(String maneuver, {int? exit}) {
    tts.speak('Prepárate. En unos metros, ${actionText(maneuver, exit: exit)}');
    haptics.double(); // vibración media
  }

  /// 3. Acción inmediata
  void speakNow(String maneuver, {int? exit}) {
    tts.speak('Ahora, ${actionText(maneuver, exit: exit)}');
    haptics.long(); // vibración fuerte
  }

  /// Mensaje de navegación continua
  void speakCruising() {
    tts.speak('Mantente en el camino indicado');
  }

  /// Mensaje de ruta recalculada
  void speakRecalculated() {
    tts.speak('Ruta recalculada');
    haptics.short();
  }

  /// Llegada al destino
  void speakArrived(String d) {
    tts.speak('Has llegado a tu destino: $d');
    haptics.long();
  }

  // ============================================================
  // ZONAS (entrada, salida, no disponible)
  // ============================================================

  /// Usuario entra a una zona
  void speakEnteredZone(String zoneName) {
    tts.speak('Entraste a la zona $zoneName');
    haptics.short();
  }

  /// Usuario sale de la zona
  void speakExitedZone() {
    tts.speak('Saliste de la zona');
    haptics.short();
  }

  /// No hay zona disponible en su ubicación
  void speakNoZoneAvailable() {
    tts.speak('Actualmente no estás en una zona cubierta');
    haptics.short();
  }

  // ============================================================
  // DESTINO / RUTA
  // ============================================================

  /// Selección de hospital o destino
  void speakSelectedDestination(String name) {
    tts.speak('Destino seleccionado: $name');
    haptics.short();
  }

  /// Mensaje antes de llamar Directions API
  void speakCalculatingRoute() {
    tts.speak('Calculando ruta');
  }
}
