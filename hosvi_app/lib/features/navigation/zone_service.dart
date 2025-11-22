// lib/features/navigation/zone_service.dart

import 'dart:math' as math;
import '../../domain/zones.dart';
import '../voice/instructions.dart';

class ZoneService {
  Zone? _lastZone;
  bool _firstCheckDone = false;

  final InstructionSpeaker speaker;
  ZoneService(this.speaker);

  /// Detecta la(s) zona(s) activa(s) y dispara eventos de entrada/salida.
  List<Zone> detectActiveZones({
    required List<Zone> zones,
    required double userLat,
    required double userLon,
  }) {
    // 1. Filtrar zonas donde el usuario está dentro
    final active = <Zone>[];
    for (final z in zones) {
      if (z.contains(userLat, userLon)) {
        active.add(z);
      }
    }

    // 2. No hay zonas activas
    if (active.isEmpty) {
      if (_lastZone != null) {
        speaker.speakExitedZone();
      } else if (!_firstCheckDone) {
        speaker.speakNoZoneAvailable();
      }

      _lastZone = null;
      _firstCheckDone = true;
      return [];
    }

    // 3. Sí hay zonas activas → tomamos la principal
    final primary = active.first;

    // Función auxiliar: hallar centro más cercano
    ZoneCenter nearestCenter(Zone z) {
      return z.centers.reduce((a, b) {
        final da = _haversineM(userLat, userLon, a.lat, a.lon);
        final db = _haversineM(userLat, userLon, b.lat, b.lon);
        return da < db ? a : b;
      });
    }

    // ---- A. Primera detección estando dentro de una zona ----
    if (_lastZone == null && !_firstCheckDone) {
      final n = nearestCenter(primary);
      speaker.speakEnteredZone(n.name ?? primary.name);
    }

    // ---- B. Cambio de zona respecto a la última detectada ----
    if (_lastZone != null && _lastZone!.id != primary.id) {
      final n = nearestCenter(primary);
      speaker.speakEnteredZone(n.name ?? primary.name);
    }

    // ---- C. Caso especial:
    // App ya había hecho el primer check, _lastZone era null (ejemplo:
    // app reiniciada dentro de zona), pero hay una zona activa ahora
    if (_firstCheckDone && _lastZone == null) {
      final n = nearestCenter(primary);
      speaker.speakEnteredZone(n.name ?? primary.name);
    }

    _lastZone = primary;
    _firstCheckDone = true;

    return active;
  }

  bool get isInsideZone => _lastZone != null;
  Zone? get currentZone => _lastZone;

  // --------------------------
  // Construcción de rutas (igual que antes)
  // --------------------------
  List<RouteNode> buildRoute({
    required List<Map<String, dynamic>> points,
    required String hospital,
    required double userLat,
    required double userLon,
  }) {
    final filtered = <Map<String, dynamic>>[];
    for (final p in points) {
      final hs = (p['hospitals'] ?? '').toString().toLowerCase();
      if (hs.split(';').map((e) => e.trim()).any((h) => h == hospital.toLowerCase())) {
        filtered.add(p);
      }
    }
    if (filtered.isEmpty) return [];

    final nodes = filtered.map((p) {
      double parseD(v) => double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
      int? parseI(v) => int.tryParse(v?.toString() ?? '');
      double? parseDNullable(v) =>
          v == null ? null : double.tryParse(v.toString().replaceAll(',', '.'));

      final hospList = (p['hospitals'] ?? '')
          .toString()
          .split(';')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      return RouteNode(
        lat: parseD(p['lat']),
        lon: parseD(p['lon']),
        nombre: p['nombre']?.toString(),
        mensaje: p['mensaje']?.toString(),
        riesgo: p['riesgo']?.toString(),
        radioM: parseDNullable(p['radio_m']),
        orden: parseI(p['orden']),
        hospitals: hospList,
      );
    }).toList();

    nodes.sort((a, b) => (a.orden ?? 0).compareTo(b.orden ?? 0));

    int nearestIdx = 0;
    double best = double.infinity;
    for (int i = 0; i < nodes.length; i++) {
      final d = _haversineM(userLat, userLon, nodes[i].lat, nodes[i].lon);
      if (d < best) {
        best = d;
        nearestIdx = i;
      }
    }

    final keywords =
    RegExp(r'(entrada|and[eé]n|acceso|lobby|recepci[oó]n)', caseSensitive: false);
    int? endIdx;
    for (int i = 0; i < nodes.length; i++) {
      final s = ((nodes[i].nombre ?? '') + ' ' + (nodes[i].mensaje ?? '')).toLowerCase();
      if (keywords.hasMatch(s)) {
        endIdx = i;
        break;
      }
    }
    endIdx ??= nodes.length - 1;

    if (nearestIdx <= endIdx) {
      return nodes.sublist(nearestIdx, endIdx + 1);
    } else {
      final sub = nodes.sublist(endIdx, nearestIdx + 1);
      return sub.reversed.toList();
    }
  }
}

double _haversineM(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

double _deg2rad(double d) => d * (math.pi / 180.0);
