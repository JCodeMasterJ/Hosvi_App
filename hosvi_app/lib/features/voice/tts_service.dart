import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  // Singleton
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  double _rate = 0.42;
  String _lang = 'es-CO';

  // 🔒 Control para evitar interrupciones
  bool _isBlocking = false;

  /// Inicialización
  Future<void> init({
    String? preferredLang,
    double rate = 0.42,
    double pitch = 1.0,
    double volume = 1.0,
  }) async {
    if (_initialized) return;

    _rate = rate;

    // Selección automática del mejor español disponible
    String langToUse = preferredLang ?? 'es-ES';
    final langs = await _tts.getLanguages;
    if (langs is List) {
      final prefs = <String>[
        if (preferredLang != null) preferredLang,
        'es-CO', 'es-ES', 'es-MX', 'es-US'
      ];
      String? found;

      for (final l in prefs) {
        if (langs.contains(l)) {
          found = l;
          break;
        }
      }

      found ??= langs.cast<dynamic>()
          .map((e) => e.toString())
          .firstWhere((e) => e.startsWith('es'), orElse: () => langToUse);

      langToUse = found;
    }

    _lang = langToUse;

    await _tts.setLanguage(langToUse);
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);

    // Permite saber cuando termina una reproducción
    await _tts.awaitSpeakCompletion(true);

    _initialized = true;
  }

  // -------------------------------------------------------
  // 🔊 speak normal (puede ser interrumpido por otros speak)
  // -------------------------------------------------------
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    if (!_initialized) {
      await init();
    }

    await _tts.stop();   // evita solapamiento
    await _tts.speak(text);
  }

  // -------------------------------------------------------
  // 🟦 speakBlocking → NO permite interrupciones
  //    (ideal para "Destino seleccionado", "Zona activa", etc.)
  // -------------------------------------------------------
  Future<void> speakBlocking(String text) async {
    if (text.trim().isEmpty) return;

    if (_isBlocking) return; // evita que lo interrumpan
    _isBlocking = true;

    if (!_initialized) {
      await init();
    }

    await _tts.stop();
    await _tts.speak(text);

    // Espera a que termine de hablar realmente
    // Puedes ajustar esto dependiendo del largo del mensaje
    await Future.delayed(const Duration(seconds: 2));

    _isBlocking = false;
  }

  // -------------------------------------------------------
  // 🛑 detener voz
  // -------------------------------------------------------
  Future<void> stop() => _tts.stop();

  // -------------------------------------------------------
  // 🔧 actualizar velocidad desde Accesibilidad
  // -------------------------------------------------------
  Future<void> updateRate(double rate) async {
    _rate = rate.clamp(0.3, 1.5);
    await _tts.setSpeechRate(_rate);
  }
}
