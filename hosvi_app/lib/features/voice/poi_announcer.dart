/*
// lib/features/voice/poi_announcer.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../voice/tts_service.dart';
import '../voice/haptics.dart';
import 'dart:math' as math;

// Ajusta este import al lugar real donde está tu RouteNode
import '../../domain/zones.dart' show RouteNode;

double _haversineM(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000.0;
  final dLat = (lat2 - lat1) * (3.1415926535 / 180.0);
  final dLon = (lon2 - lon1) * (3.1415926535 / 180.0);
  final a = math.sin(dLat/2) * math.sin(dLat/2) +
      math.cos(math.pi * lat1 / 180) * math.cos(math.pi * lat2 / 180) *
          math.sin(dLon/2) * math.sin(dLon/2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

class PoiAnnouncer {
  final TtsService tts;
  final Haptics haptics;
  final _cooldown = <String, DateTime>{};
  final Duration minGap = const Duration(minutes: 2);

  PoiAnnouncer(this.tts, this.haptics);

  /// Llama esto en cada actualización de ubicación
  void checkPois(LatLng user, Iterable<RouteNode> pois) {
    final now = DateTime.now();

    for (final p in pois) {
      // PROPIEDADES: adapta si en tu modelo se llaman diferente
      final String id   = (p as dynamic).id ?? '${p.lat},${p.lon}';
      final String? hint = (p as dynamic).audioHint ?? p.mensaje;
      final String? vib  = (p as dynamic).vibroPatron; // 'corto', 'doble', 'largo'
      final double r     = (p.radioM ?? 12).toDouble();

      final last = _cooldown[id];
      if (last != null && now.difference(last) < minGap) continue;

      final d = _haversineM(user.latitude, user.longitude, p.lat, p.lon);
      if (d <= r) {
        final msg = (hint ?? '').trim();
        if (msg.isNotEmpty) tts.speak(msg);
        if (vib == 'doble')      haptics.double();
        else if (vib == 'largo') haptics.long();
        else                     haptics.short();
        _cooldown[id] = now;
      }
    }
  }
}
*/
// lib/features/voice/poi_announcer.dart
import 'dart:math' as math;

import '../../domain/zones.dart' show RouteNode;
import 'tts_service.dart';
import 'haptics.dart';

double _havM(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000.0;
  final dLat = (lat2 - lat1) * (math.pi / 180.0);
  final dLon = (lon2 - lon1) * (math.pi / 180.0);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * (math.pi / 180.0)) *
          math.cos(lat2 * (math.pi / 180.0)) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

/// Anuncia POIs cercanos con voz + vibración.
/// Se usa así:
///   final _poi = PoiAnnouncer(
///     tts: _tts, haptics: _haptics,
///     getVisiblePois: () => _visiblePois,
///     speakNearMeters: 18,
///     minSpeakGap: const Duration(seconds: 18),
///   );
///   ...
///   _poi.updateUserPos(_userLat!, _userLon!);  // en cada tick del GPS
class PoiAnnouncer {
  final TtsService tts;
  final Haptics haptics;
  final Iterable<RouteNode> Function() getVisiblePois;
  final double speakNearMeters;
  final Duration minSpeakGap;

  // Anti-spam por POI
  final Map<String, DateTime> _cooldown = {};

  PoiAnnouncer({
    required this.tts,
    required this.haptics,
    required this.getVisiblePois,
    this.speakNearMeters = 18,
    this.minSpeakGap = const Duration(seconds: 18),
  });

  double? _uLat, _uLon;

  /// Llama esto en cada actualización de ubicación
  void updateUserPos(double lat, double lon) {
    _uLat = lat;
    _uLon = lon;
    _checkAndAnnounce();
  }

  // --- Interno --------------------------------------------------------------

  void _checkAndAnnounce() {
    if (_uLat == null || _uLon == null) return;

    final now = DateTime.now();
    final pois = getVisiblePois(); // lo que definiste en map_screen

    for (final p in pois) {
      // Campos flexibles (por si tu RouteNode tiene nombres distintos)
      final String id = _safeId(p);
      final String? msg = _safeMsg(p);
      final String? vib = _safeVib(p);
      final double r = _safeRadio(p) ?? speakNearMeters;

      // cooldown por POI
      final last = _cooldown[id];
      if (last != null && now.difference(last) < minSpeakGap) continue;

      final d = _havM(_uLat!, _uLon!, p.lat, p.lon);
      if (d <= r) {
        if (msg != null && msg.trim().isNotEmpty) {
          tts.speak(msg.trim());           // frase corta y clara
        }
        // patrón simple de vibración (ajusta a tu Haptics si usas otros nombres)
        switch ((vib ?? 'corto').toLowerCase()) {
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
  }

  // --- Helpers de adaptación (no rompen si cambian los nombres) -------------

  String _safeId(RouteNode p) {
    // si en tu RouteNode existe un `id`, úsalo; si no, lat/lon como fallback
    try {
      final dyn = (p as dynamic);
      final val = dyn.id?.toString();
      if (val != null && val.isNotEmpty) return val;
    } catch (_) {}
    return '${p.lat},${p.lon}';
  }

  String? _safeMsg(RouteNode p) {
    try {
      final dyn = (p as dynamic);
      if (dyn.audioHint != null && dyn.audioHint.toString().trim().isNotEmpty) {
        return dyn.audioHint.toString();
      }
      if (dyn.mensaje != null && dyn.mensaje.toString().trim().isNotEmpty) {
        return dyn.mensaje.toString();
      }
    } catch (_) {}
    return null;
  }

  String? _safeVib(RouteNode p) {
    try {
      final dyn = (p as dynamic);
      if (dyn.vibroPatron != null) return dyn.vibroPatron.toString();
    } catch (_) {}
    return null; // usa el default "corto"
  }

  double? _safeRadio(RouteNode p) {
    try {
      final dyn = (p as dynamic);
      if (dyn.radioM != null) return (dyn.radioM as num).toDouble();
    } catch (_) {}
    return null;
  }
}
