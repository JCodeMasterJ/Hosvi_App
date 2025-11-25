// lib/features/voice/poi_announcer.dart

import 'dart:math' as math;
import '../../domain/zones.dart' show RouteNode;
import 'tts_service.dart';
import 'haptics.dart';

double _distM(double aLat, double aLon, double bLat, double bLon) {
  const R = 6371000.0;
  final dLat = (bLat - aLat) * (math.pi / 180);
  final dLon = (bLon - aLon) * (math.pi / 180);
  final x = math.sin(dLat / 2);
  final y = math.sin(dLon / 2);
  final h = x * x +
      math.cos(aLat * (math.pi / 180)) *
          math.cos(bLat * (math.pi / 180)) *
          y * y;
  return R * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

/// ---------------------------------------------------------------------------
///  POI ANNOUNCER – VERSIÓN PRO
///  - Prioriza POIs sobre navegación
///  - Pausa navegación mientras anuncia
///  - Anti-spam seguro
/// ---------------------------------------------------------------------------
class PoiAnnouncer {
  final TtsService tts;
  final Haptics haptics;

  /// Devuelve POIs visibles filtrados por zona + hospital
  final Iterable<RouteNode> Function() getVisiblePois;

  /// Radio estándar si el POI no trae radio
  final double speakNearMeters;

  /// Mínimo tiempo entre anuncios del mismo POI
  final Duration minSpeakGap;

  /// Si está muteado (p. ej., mientras anuncia navegación)
  bool isMuted = false;

  /// Si debemos bloquear navegación mientras se anuncia un POI
  final void Function(Duration) onInterruptNavigation;

  /// Registro de última vez que se habló cada POI
  final Map<String, DateTime> _cooldown = {};

  PoiAnnouncer({
    required this.tts,
    required this.haptics,
    required this.getVisiblePois,
    required this.onInterruptNavigation,
    this.speakNearMeters = 16,
    this.minSpeakGap = const Duration(seconds: 15),
  });

  double? _uLat, _uLon;

  // ---------------------------------------------------------------------------
  // Se llama en cada update de GPS
  // ---------------------------------------------------------------------------
  void updateUserPos(double lat, double lon) {
    _uLat = lat;
    _uLon = lon;

    if (!isMuted) _checkPois();
  }

  // ---------------------------------------------------------------------------
  // Mute externo para navegación (turn-by-turn)
  // ---------------------------------------------------------------------------
  void muteFor(Duration d) {
    isMuted = true;
    Future.delayed(d, () => isMuted = false);
  }

  // ---------------------------------------------------------------------------
  // Lógica principal
  // ---------------------------------------------------------------------------
  void _checkPois() {
    if (_uLat == null || _uLon == null) return;

    final now = DateTime.now();
    final pois = getVisiblePois();

    // Log global
    // ignore: avoid_print
    print('[HOSVI][POI] visibles=${pois.length} user=($_uLat,$_uLon)');

    for (final p in pois) {
      final id = _safeId(p);
      final msg = _safeMsg(p);
      final vib = _safeVib(p);
      final r = _safeRadius(p);

      // Anti-spam
      final last = _cooldown[id];
      if (last != null && now.difference(last) < minSpeakGap) {
        // ignore: avoid_print
        print('[HOSVI][POI] skip cooldown id=$id');
        continue;
      }

      // Distancia
      final d = _distM(_uLat!, _uLon!, p.lat, p.lon);

      // ignore: avoid_print
      print('[HOSVI][POI] id=$id dist=${d.toStringAsFixed(1)} '
          'r=$r msg=${msg ?? "(sin msg)"} vib=$vib');

      if (d > r) continue;

      // ---------------------------------------------------------------------
      // ANUNCIAR POI
      // ---------------------------------------------------------------------
      if (msg != null && msg.isNotEmpty) {
        onInterruptNavigation(const Duration(seconds: 2)); // 🔥 PÁRATE NAVEGACIÓN
        // ignore: avoid_print
        print('[HOSVI][POI] 🎧 hablando id=$id: $msg');
        tts.speak(msg);
      }

      // Vibración
      switch (vib) {
        case 'doble':
        case 'double':
          haptics.double();
          break;
        case 'largo':
          haptics.long();
          break;
        default:
          haptics.short();
      }

      _cooldown[id] = now;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers seguros para campos opcionales en el CSV
  // ---------------------------------------------------------------------------

  String _safeId(RouteNode p) {
    try {
      final dyn = (p as dynamic);
      if (dyn.id != null) return dyn.id.toString();
    } catch (_) {}
    return '${p.lat},${p.lon}';
  }

  /// Prioridad:
  /// 1. mensaje
  /// 2. audioHint / audio_hint
  /// 3. msg
  /// 4. campos dentro de maps extra/extras/props
  String? _safeMsg(RouteNode p) {
    String _clean(dynamic v) =>
        v == null ? '' : v.toString().trim();

    try {
      final dyn = p as dynamic;

      // 1) Campos directos en el objeto
      final directCandidates = <String>[
        _clean(_tryField(dyn, 'mensaje')),
        _clean(_tryField(dyn, 'audioHint')),
        _clean(_tryField(dyn, 'audio_hint')),
        _clean(_tryField(dyn, 'msg')),
      ];

      for (final c in directCandidates) {
        if (c.isNotEmpty) return c;
      }

      // 2) Campos dentro de mapas tipo extra/extras/props
      dynamic extra;
      try {
        extra = _tryField(dyn, 'extra') ??
            _tryField(dyn, 'extras') ??
            _tryField(dyn, 'props');
      } catch (_) {}

      if (extra is Map) {
        final fromMap = <String>[
          _clean(extra['mensaje']),
          _clean(extra['audio_hint']),
          _clean(extra['audioHint']),
        ];
        for (final c in fromMap) {
          if (c.isNotEmpty) return c;
        }
      }
    } catch (_) {}

    return null;
  }

  // Intenta acceder a un campo concreto, pero sin reventar si no existe
  dynamic _tryField(dynamic dyn, String fieldName) {
    try {
      switch (fieldName) {
        case 'mensaje':
          return dyn.mensaje;
        case 'audioHint':
          return dyn.audioHint;
        case 'audio_hint':
          return dyn.audio_hint;
        case 'msg':
          return dyn.msg;
        case 'extra':
          return dyn.extra;
        case 'extras':
          return dyn.extras;
        case 'props':
          return dyn.props;
      }
    } catch (_) {}
    return null;
  }

  String? _safeVib(RouteNode p) {
    try {
      final dyn = (p as dynamic);
      if (dyn.vibroPatron != null &&
          dyn.vibroPatron.toString().trim().isNotEmpty) {
        return dyn.vibroPatron.toString();
      }

      // Si viene en algún mapa extra
      final extra =
          _tryField(dyn, 'extra') ?? _tryField(dyn, 'extras') ?? _tryField(dyn, 'props');
      if (extra is Map && extra['vibro_patron'] != null) {
        return extra['vibro_patron'].toString();
      }
    } catch (_) {}
    return 'corto';
  }

  double _safeRadius(RouteNode p) {
    try {
      final dyn = (p as dynamic);
      if (dyn.radioM != null) return (dyn.radioM as num).toDouble();

      final extra =
          _tryField(dyn, 'extra') ?? _tryField(dyn, 'extras') ?? _tryField(dyn, 'props');
      if (extra is Map && extra['radio_m'] != null) {
        return (extra['radio_m'] as num).toDouble();
      }
    } catch (_) {}
    return speakNearMeters;
  }
}
