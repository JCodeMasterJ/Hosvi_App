// lib/features/voice/route_progress.dart
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Ajusta el import a donde tengas estas clases
import '../../services/directions_service.dart'; // DirectionsRoute, DirectionsStep

class RouteProgress {
  /// Radio para "consumir" un step y pasar al siguiente (m).
  final double advanceRadiusM;

  DirectionsRoute? _route;
  int _idx = 0;
  double _distToNext = double.infinity;

  RouteProgress({this.advanceRadiusM = 8});

  /// Carga / resetea ruta
  void setRoute(DirectionsRoute? r) {
    _route = r;
    _idx = 0;
    _distToNext = double.infinity;
  }

  /// Paso actual (o null si no hay)
  DirectionsStep? get step {
    if (_route == null) return null;
    final steps = _route!.steps;
    if (steps.isEmpty) return null;
    if (_idx < 0 || _idx >= steps.length) return null;
    return steps[_idx];
  }

  /// Distancia actual al punto final del paso (m)
  double get distToNextM => _distToNext;

  /// ¿Terminó la ruta?
  bool get isFinished {
    if (_route == null) return true;
    final steps = _route!.steps;
    return steps.isEmpty || _idx >= steps.length - 1 && _distToNext <= advanceRadiusM;
  }

  /// Llamar en cada actualización de ubicación
  void update(LatLng user) {
    final s = step;
    if (s == null) {
      _distToNext = double.infinity;
      return;
    }
    final e = s.endLocation;
    _distToNext = _haversineM(user.latitude, user.longitude, e.latitude, e.longitude);

    // Avanza al siguiente step cuando llegas al punto de giro
    if (_distToNext <= advanceRadiusM && _route != null) {
      if (_idx < _route!.steps.length - 1) {
        _idx++;
        // recalcular de inmediato con el nuevo step para no “quedarse pegado”
        final ns = step;
        if (ns != null) {
          final ne = ns.endLocation;
          _distToNext = _haversineM(user.latitude, user.longitude, ne.latitude, ne.longitude);
        }
      }
    }
  }

  // Helpers
  static double _haversineM(double la1, double lo1, double la2, double lo2) {
    const R = 6371000.0;
    final dLat = _deg2rad(la2 - la1);
    final dLon = _deg2rad(lo2 - lo1);
    final a = math.sin(dLat/2)*math.sin(dLat/2) +
        math.cos(_deg2rad(la1))*math.cos(_deg2rad(la2))*
            math.sin(dLon/2)*math.sin(dLon/2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double d) => d * (math.pi / 180.0);
}
