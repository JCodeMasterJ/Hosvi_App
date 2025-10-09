// lib/services/directions_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DirectionsStep {
  final String instruction; // texto plano (sin HTML)
  final int distanceMeters;
  final LatLng endLocation; // ← esta es la “meta” del step
  final String? maneuver; // e.g., "turn-right"

  DirectionsStep({
    required this.instruction,
    required this.distanceMeters,
    required this.endLocation,
    this.maneuver,
  });
}

class DirectionsRoute {
  final List<LatLng> path;
  final int totalDistanceMeters;
  final int totalDurationSec;
  final List<DirectionsStep> steps;

  DirectionsRoute({
    required this.path,
    required this.totalDistanceMeters,
    required this.totalDurationSec,
    required this.steps,
  });
}

class DirectionsService {
  final String apiKey;
  DirectionsService(this.apiKey);

  Future<DirectionsRoute?> getRoute({
    required LatLng origin,
    required LatLng destination,
    String mode = 'walking', // 'walking' | 'driving'
  }) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=$mode'
          '&language=es'
          '&units=metric'
          '&alternatives=false'
          '&key=$apiKey',
    );

    final resp = await http.get(url);
    if (resp.statusCode != 200) return null;

    final data = jsonDecode(resp.body);
    if (data['status'] != 'OK') {
      debugPrint('Directions error: ${data['status']} - ${data['error_message']}');
      return null;
    }

    final route = data['routes'][0];
    final overview = route['overview_polyline']['points'] as String;

    final points = PolylinePoints().decodePolyline(overview);
    final path = points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    final leg = route['legs'][0];
    final totalDistance = leg['distance']['value'] as int; // meters
    final totalDuration = leg['duration']['value'] as int; // seconds

    final stepsJson = (leg['steps'] as List);
    final steps = stepsJson.map((s) {
      String html = (s['html_instructions'] as String?) ?? '';
      final text = html
          .replaceAll(RegExp(r'<[^>]+>'), '') // quitar etiquetas HTML
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&');
      final dist = (s['distance']?['value'] as int?) ?? 0;
      final end = s['end_location'];
      final man = s['maneuver'] as String?;
      return DirectionsStep(
        instruction: text,
        distanceMeters: dist,
        endLocation: LatLng((end['lat'] as num).toDouble(), (end['lng'] as num).toDouble()),
        maneuver: man,
      );
    }).toList();

    return DirectionsRoute(
      path: path,
      totalDistanceMeters: totalDistance,
      totalDurationSec: totalDuration,
      steps: steps,
    );
  }
}
