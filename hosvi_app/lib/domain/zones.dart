// lib/domain/zones.dart
import 'dart:math' as math;

/// Centro de una subzona circular que compone una zona (union de círculos)
class ZoneCenter {
  final double lat;
  final double lon;
  final double radiusM;

  const ZoneCenter({required this.lat, required this.lon, required this.radiusM});

  factory ZoneCenter.fromJson(Map<String, dynamic> j) => ZoneCenter(
    lat: (j['lat'] as num).toDouble(),
    lon: (j['lon'] as num).toDouble(),
    radiusM: (j['radius_m'] as num).toDouble(),
  );
}

/// Zona compuesta por uno o varios [ZoneCenter]
class Zone {
  final String id;
  final String name;
  final List<ZoneCenter> centers;
  final List<String> hospitals; // nombres "humanos" a mostrar

  const Zone({
    required this.id,
    required this.name,
    required this.centers,
    required this.hospitals,
  });

  factory Zone.fromJson(Map<String, dynamic> j) => Zone(
    id: j['id'] as String,
    name: j['name'] as String,
    centers: (j['centers'] as List).map((e) => ZoneCenter.fromJson(e)).toList(),
    hospitals: (j['hospitals'] as List).map((e) => e.toString()).toList(),
  );

  /// ¿El punto [lat,lon] está dentro de la unión de círculos de la zona?
  bool contains(double lat, double lon) {
    for (final c in centers) {
      final d = _haversineM(lat, lon, c.lat, c.lon);
      if (d <= c.radiusM) return true;
    }
    return false;
  }
}

/// Haversine simple (metros)
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

/// Nodo de ruta (waypoint) muy simple
class RouteNode {
  final double lat;
  final double lon;
  final String? nombre;
  final String? mensaje;
  final String? riesgo;
  final double? radioM;
  final int? orden;
  final List<String> hospitals;

  const RouteNode({
    required this.lat,
    required this.lon,
    this.nombre,
    this.mensaje,
    this.riesgo,
    this.radioM,
    this.orden,
    this.hospitals = const [],
  });
}
