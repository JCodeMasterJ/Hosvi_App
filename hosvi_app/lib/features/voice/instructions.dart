// lib/features/voice/instructions.dart
import '../voice/tts_service.dart';
import '../voice/haptics.dart';

class InstructionSpeaker {
  final TtsService tts;
  final Haptics haptics;
  InstructionSpeaker(this.tts, this.haptics);

  String actionText(String m, {int? exit}) {
    switch (m) {
      case 'turn-left': return 'gira a la izquierda';
      case 'turn-right': return 'gira a la derecha';
      case 'straight': return 'sigue recto';
      case 'slight-left': return 'desvío leve a la izquierda';
      case 'slight-right': return 'desvío leve a la derecha';
      case 'uturn-left':
      case 'uturn-right': return 'retorno';
      case 'roundabout-right':
      case 'roundabout-left': return 'glorieta, salida ${exit ?? 1}';
      default: return 'sigue recto';
    }
  }

  void speakPrep(String maneuver, {int? exit}) {
    tts.speak('Prepárate. En 60 metros, ${actionText(maneuver, exit: exit)}');
    haptics.short();
  }
  void speakNear(String maneuver, {int? exit}) {
    tts.speak('En 25 metros, ${actionText(maneuver, exit: exit)}');
    haptics.double();
  }
  void speakNow(String maneuver, {int? exit}) {
    tts.speak('Ahora, ${actionText(maneuver, exit: exit)}');
    haptics.long();
  }
  void speakCruising() => tts.speak('Sigue por esta vía');
  void speakArrived(String d) => tts.speak('Llegaste a $d');
}
