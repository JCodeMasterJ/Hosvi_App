// lib/features/navigation/zone_service.dart
import 'dart:math' as math;
import '../../domain/zones.dart';

class ZoneService {
  Zone? _lastZone;

  Zone? detectActiveZone({
    required List<Zone> zones,
    required double userLat,
    required double userLon,
  }) {
    for (final z in zones) {
      if (z.contains(userLat, userLon)) {
        _lastZone = z;
        return z;
      }
    }
    // Si estaba en zona y salió, _lastZone se queda por si necesitas evento de salida
    return null;
  }

  bool get wasInZone => _lastZone != null;

  /// Construye una ruta v1:
  ///  - Filtra puntos por hospital elegido (columna 'hospitals' que trae valores separados por ';')
  ///  - Ordena por 'orden'
  ///  - Elige un start cercano al usuario y un end candidato por heurística (palabras clave)
  ///  - Devuelve sublista desde start -> end (o viceversa) según cuál quede más natural
  List<RouteNode> buildRoute({
    required List<Map<String, dynamic>> points, // puntos ya cargados de tu CSV
    required String hospital,
    required double userLat,
    required double userLon,
  }) {
    // 1) Filtrar por hospital
    final filtered = <Map<String, dynamic>>[];
    for (final p in points) {
      final hs = (p['hospitals'] ?? '').toString().toLowerCase();
      if (hs.split(';').map((e) => e.trim()).any((h) => h == hospital.toLowerCase())) {
        filtered.add(p);
      }
    }
    if (filtered.isEmpty) return [];

    // 2) Parse + ordenar por 'orden'
    final nodes = filtered.map((p) {
      double parseD(v) => double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
      int? parseI(v) => int.tryParse(v?.toString() ?? '');
      double? parseDNullable(v) => v == null ? null : double.tryParse(v.toString().replaceAll(',', '.'));

      final hospList = (p['hospitals'] ?? '').toString().split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

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

    nodes.sort((a, b) {
      final ai = a.orden ?? 0;
      final bi = b.orden ?? 0;
      return ai.compareTo(bi);
    });

    // 3) Elegir start cercano al usuario
    int nearestIdx = 0;
    double best = double.infinity;
    for (int i = 0; i < nodes.length; i++) {
      final d = _haversineM(userLat, userLon, nodes[i].lat, nodes[i].lon);
      if (d < best) {
        best = d;
        nearestIdx = i;
      }
    }

    // 4) Elegir candidato a destino (heurística por keywords)
    final keywords = RegExp(r'(entrada|and[eé]n|acceso|lobby|recepci[oó]n)', caseSensitive: false);
    int? endIdx;
    for (int i = 0; i < nodes.length; i++) {
      final s = ((nodes[i].nombre ?? '') + ' ' + (nodes[i].mensaje ?? '')).toLowerCase();
      if (keywords.hasMatch(s)) {
        endIdx = i;
        break;
      }
    }
    endIdx ??= nodes.length - 1; // fallback último

    // 5) Subruta desde nearest -> end (o al revés si end está "antes")
    if (nearestIdx <= endIdx) {
      return nodes.sublist(nearestIdx, endIdx + 1);
    } else {
      final sub = nodes.sublist(endIdx, nearestIdx + 1);
      return sub.reversed.toList();
    }
  }
}

/// Haversine (metros)
double _haversineM(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

double _deg2rad(double d) => d * (math.pi / 180.0);
