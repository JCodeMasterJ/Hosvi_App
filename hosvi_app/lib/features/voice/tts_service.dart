import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  // Singleton (para usar TtsService.instance en cualquier parte)
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  double _rate = 0.42; // 👈 velocidad actual
  String _lang = 'es-CO'; // 👈 idioma activo

  /// Inicializa idioma y parámetros de habla.
  /// Llama una sola vez al inicio de la app.
  Future<void> init({
    String? preferredLang,         // ejemplo: 'es-CO'
    double rate = 0.42,            // más lento para entender mejor
    double pitch = 1.0,
    double volume = 1.0,
  }) async {
    if (_initialized) return;

    _rate = rate; // 👈 guarda el valor inicial de velocidad

    // Idioma: intenta es-CO, es-ES, es-MX, es-US, o cualquier 'es-*' disponible.
    String langToUse = preferredLang ?? 'es-ES';
    final langs = await _tts.getLanguages;
    if (langs is List) {
      final prefs = <String>[
        if (preferredLang != null) preferredLang,
        'es-CO', 'es-ES', 'es-MX', 'es-US'
      ];
      String? found;
      for (final l in prefs) {
        if (langs.contains(l)) { found = l; break; }
      }
      found ??= langs.cast<dynamic>()
          .map((e) => e.toString())
          .firstWhere((e) => e.startsWith('es'), orElse: () => langToUse);
      langToUse = found;
    }

    _lang = langToUse; // 👈 guarda el idioma elegido

    await _tts.setLanguage(langToUse);
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);

    // Que podamos esperar a que termine de hablar para encadenar mensajes
    await _tts.awaitSpeakCompletion(true);

    _initialized = true;
  }

  /// Hablar un texto. Si no se llamó init() antes, lo hace con valores por defecto.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!_initialized) {
      await init(); // inicializa con defaults en caso de olvido
    }
    // Evita solapamiento
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Actualiza la velocidad del habla en tiempo real desde accesibilidad.
  Future<void> updateRate(double rate) async {
    _rate = rate.clamp(0.3, 1.5); // evita valores fuera del rango
    await _tts.setSpeechRate(_rate);
  }

  Future<void> stop() => _tts.stop();
}
