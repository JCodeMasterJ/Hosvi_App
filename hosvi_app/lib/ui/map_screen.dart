// lib/ui/map_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/result.dart';
import '../data/points_repository.dart';
import '../domain/models.dart';
import '../services/directions_service.dart';

import '../features/voice/tts_service.dart';
import '../features/voice/haptics.dart';
import 'package:flutter/services.dart' show HapticFeedback;


/// =====================
/// Modelos internos zona
/// =====================

class _ZoneCenter {
  final String? name;        // ← opcional
  final double lat;
  final double lon;
  final double radiusM;
  const _ZoneCenter({
    this.name, // <-- no requiere valor, por eso no da error
    required this.lat,
    required this.lon,
    required this.radiusM,
  });

  factory _ZoneCenter.fromJson(Map<String, dynamic> j) => _ZoneCenter(
    name: j['name'] as String?,                    // ← nuevo
    lat: (j['lat'] as num).toDouble(),
    lon: (j['lon'] as num).toDouble(),
    radiusM: (j['radius_m'] as num).toDouble(),
  );
}

class _Zone {
  final String id;
  final String name;
  final List<_ZoneCenter> centers;
  final List<String> hospitals;

  const _Zone({
    required this.id,
    required this.name,
    required this.centers,
    required this.hospitals,
  });

  factory _Zone.fromJson(Map<String, dynamic> j) => _Zone(
    id: j['id'] as String,
    name: j['name'] as String,
    centers: (j['centers'] as List)
        .map((e) => _ZoneCenter.fromJson(e as Map<String, dynamic>))
        .toList(),
    hospitals:
    (j['hospitals'] as List).map((e) => e as String).toList(),
  );
}

// Turn-by-turn
int _currentStepIdx = 0;
const double _stepAdvanceRadius = 25; // m para "consumir" un step
//final _tts = TtsService();                   // o TtsService.instance si lo usas como singleton
final _tts = TtsService.instance;
DateTime _lastTts = DateTime(0);


/// =======================
/// Provider de puntos CSV
/// =======================

final pointsProvider = FutureProvider<List<PointInfo>>((ref) async {
  const String _assetPath = 'assets/data/puntos_hospitales.csv';
  final repo = PointsRepository(assetPath: _assetPath);
  final res = await repo.load();
  return switch (res) {
    Ok(data: final data) => data,
    Err(message: final m) => throw Exception(m),
    _ => throw Exception('Resultado inesperado del repositorio'),
  };
});

/// ==============
/// MapScreen UI
/// ==============

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _ctrl;
  final _markers = <Marker>{};
  final Map<PolylineId, Polyline> _polylines = {};

  StreamSubscription<Position>? _posSub;

  bool _followMe = true;
  MapType _mapType = MapType.normal;

  // Control de frecuencia para redibujar la línea
  DateTime _lastRouteUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  static const _routeMinInterval = Duration(seconds: 2);


  // Zonas
  List<_Zone> _zones = [];
  _Zone? _activeZone;
  String? _selectedHospital;

  // Usuario / destino
  double? _userLat, _userLon;
  LatLng? _dest;
  double? _remainingMeters;
  final _destPolylineId = const PolylineId('dest_line');

  // ==== Rutas (Google Directions) ====
  DirectionsRoute? _currentRoute;                         // última ruta con steps
  final PolylineId _routePolylineId = const PolylineId('g_directions');
  String _navMode = 'walking';                            // 'walking' o 'driving'
  // ===================================

  // Círculos de depuración
  bool _debugShowZonesAlways = true;
  final Set<Circle> _circles = {};

  // --------------------
  // Ciclo de vida
  // --------------------


  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _ensureLocationPermission();
    await _loadZones();
    _rebuildZonesCircles();
    _startFollowMe();
  }

  // --------------------
  // Zonas
  // --------------------

  Future<void> _loadZones() async {
    try {
      final raw = await rootBundle.loadString('assets/data/zones.json');
      final data = jsonDecode(raw) as List;
      _zones = data
          .map((e) => _Zone.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {});
    } catch (e) {
      debugPrint('Error cargando zones.json: $e');
    }
  }

  void _rebuildZonesCircles() {
    _circles.clear();
    int i = 0;
    for (final z in _zones) {
      for (final c in z.centers) {
        _circles.add(
          Circle(
            circleId: CircleId('zone_${z.id}_$i'),
            center: LatLng(c.lat, c.lon),
            radius: c.radiusM,
            strokeWidth: 2,
            strokeColor: Colors.teal.withOpacity(0.9),
            fillColor: Colors.tealAccent.withOpacity(0.15),
          ),
        );
        i++;
      }
    }
    if (mounted) setState(() {});
  }

  bool _isInside(double lat1, double lon1, _ZoneCenter c) {
    const R = 6371000.0;
    final dLat = (lat1 - c.lat) * (math.pi / 180);
    final dLon = (lon1 - c.lon) * (math.pi / 180);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(c.lat * (math.pi / 180)) *
            math.cos(lat1 * (math.pi / 180)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final d = 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return d <= c.radiusM;
  }

  _Zone? _detectActiveZone(double lat, double lon) {
    for (final z in _zones) {
      for (final c in z.centers) {
        if (_isInside(lat, lon, c)) return z;
      }
    }
    return null;
  }

  // --- Helpers de ruta/selección ---
  void _clearRoute() {
    setState(() {
      _selectedHospital = null;
      _dest = null;
      _remainingMeters = null;
      _currentRoute = null;      // <-- limpia ruta
      _currentStepIdx = 0;       // <-- resetea turn-by-turn
      _polylines.clear();
    });
  }


  void _recalcActiveZone() {
    if (_userLat == null || _userLon == null || _zones.isEmpty) return;
    final found = _detectActiveZone(_userLat!, _userLon!);
    if (found?.id != _activeZone?.id) {
      _activeZone = found;
      _clearRoute();           // ← resetea destino/ruta al cambiar de zona
      setState(() {});
    }
  }

  _ZoneCenter? _findHospitalCenter(String hospitalName) {
    final z = _activeZone;
    if (z == null || z.centers.isEmpty) return null;

    // 1) Coincidencia exacta por nombre del centro
    final byName = z.centers.firstWhere(
          (c) => c.name != null && c.name!.toLowerCase() == hospitalName.toLowerCase(),
      orElse: () => const _ZoneCenter(lat: 0, lon: 0, radiusM: 0), // sentinel
    );
    if (byName.lat != 0 || byName.lon != 0) return byName;

    // 2) Si no hay nombre, tomamos el centro más cercano al usuario
    if (_userLat != null && _userLon != null) {
      z.centers.sort((a, b) {
        final da = _distMeters(_userLat!, _userLon!, a.lat, a.lon);
        final db = _distMeters(_userLat!, _userLon!, b.lat, b.lon);
        return da.compareTo(db);
      });
      return z.centers.first;
    }

    // 3) Último recurso: el primero de la lista
    return z.centers.first;
  }



  // --------------------
  // Permisos / ubicación
  // --------------------

  Future<void> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  void _startFollowMe() {
    _posSub?.cancel();

    // Mejores updates para navegación
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3, // redibuja cada ~3m
    );

    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) async {
      _userLat = pos.latitude;
      _userLon = pos.longitude;
      // debug: print('📍 pos: $_userLat, $_userLon');

      // 1) Detecta zona
      _recalcActiveZone();

      // 2) Navegación
      if (_dest != null) {
        // Si aún NO hay ruta de Google, constrúyela apenas tengamos fix:
        if (_currentRoute == null && _userLat != null && _userLon != null) {
          await _buildGoogleRoute(LatLng(_userLat!, _userLon!), _dest!);
        } else if (_currentRoute != null) {
          // Re‐ruta simple si “te sales” o cada ~5s
          final distToDest = _distMeters(_userLat!, _userLon!, _dest!.latitude, _dest!.longitude);
          final now = DateTime.now();
          final shouldReroute = distToDest > 50 && now.difference(_lastRouteUpdate) > const Duration(seconds: 5);
          if (shouldReroute) {
            _lastRouteUpdate = now;
            await _buildGoogleRoute(LatLng(_userLat!, _userLon!), _dest!);
          }

          _remainingMeters = distToDest;

          final steps = _currentRoute!.steps;
          if (steps.isNotEmpty && _currentStepIdx < steps.length) {
            final step = steps[_currentStepIdx];

            // Usamos el punto final del step
            final LatLng endPoint = step.endLocation;

            // Distancia del usuario al fin del step
            final dStep = _distMeters(
              _userLat!, _userLon!, endPoint.latitude, endPoint.longitude,
            );

            if (dStep <= _stepAdvanceRadius) {
              _currentStepIdx = (_currentStepIdx + 1).clamp(0, steps.length - 1);
              if (_currentStepIdx < steps.length) {
                //Haptics.medium();
                HapticFeedback.mediumImpact();

                _say(steps[_currentStepIdx]);
              }
            }
          }


          if (_remainingMeters! < 20) {
            // TODO: TTS("Has llegado")
            _currentRoute = null;
            _clearRoute(); // limpia _dest, _polylines, etc.
          } else if (mounted) {
            setState(() {}); // refresca pill de distancia
          }
        }
      }


      // 3) Seguir cámara
      if (_followMe && _ctrl != null) {
        await _ctrl!.animateCamera(
          CameraUpdate.newLatLng(LatLng(_userLat!, _userLon!)),
        );
      }
    });
  }


  // --------------------
  // Utilidades
  // --------------------

  Future<void> _fitToPoints(Iterable<LatLng> pts) async {
    if (_ctrl == null || pts.isEmpty) return;
    final swLat = pts.map((e) => e.latitude).reduce((a, b) => a < b ? a : b);
    final swLng = pts.map((e) => e.longitude).reduce((a, b) => a < b ? a : b);
    final neLat = pts.map((e) => e.latitude).reduce((a, b) => a > b ? a : b);
    final neLng = pts.map((e) => e.longitude).reduce((a, b) => a > b ? a : b);
    final bounds = LatLngBounds(
      southwest: LatLng(swLat, swLng),
      northeast: LatLng(neLat, neLng),
    );
    await _ctrl!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  double _distMeters(double la1, double lo1, double la2, double lo2) {
    const R = 6371000.0;
    final dLat = (la2 - la1) * (math.pi / 180.0);
    final dLon = (lo2 - lo1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1 * (math.pi / 180.0)) *
            math.cos(la2 * (math.pi / 180.0)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  void _updateDestPolyline() {
    if (_userLat == null || _userLon == null || _dest == null) {
      _polylines.remove(_destPolylineId);
      setState(() {});
      return;
    }

    // Control de frecuencia: actualiza cada 2s
    final now = DateTime.now();
    if (now.difference(_lastRouteUpdate) < _routeMinInterval) return;
    _lastRouteUpdate = now;

    final p1 = LatLng(_userLat!, _userLon!);
    final p2 = _dest!;

    _remainingMeters = _distMeters(
      p1.latitude, p1.longitude, p2.latitude, p2.longitude,
    );

    final poly = Polyline(
      polylineId: _destPolylineId,     // <-- usa SIEMPRE el MISMO id
      points: [p1, p2],
      width: 6,
      color: Colors.teal,
    );

    setState(() {
      _polylines[_destPolylineId] = poly;  // <-- y guarda con el mismo id
    });
  }

  Future<void> _buildGoogleRoute(LatLng origin, LatLng destination) async {
    // Limpia lo previo
    _currentRoute = null;
    _polylines.remove(_routePolylineId);
    setState(() {});

    //final apiKey = const String.fromEnvironment('MAPS_API_KEY', defaultValue: '');
    // O simplemente pega tu key directa si prefieres:
     final apiKey = 'AIzaSyDR2cMaHbbnYIy0aABq7Umq2_b8xivo8lI';

    final svc = DirectionsService(apiKey);
    final route = await svc.getRoute(origin: origin, destination: destination, mode: _navMode);
    if (route == null) return;

    _currentRoute = route;

    // Limpiar línea recta si existía
    _polylines.remove(_destPolylineId);

// Primer step de la ruta
    _currentStepIdx = 0;
    if (_currentRoute!.steps.isNotEmpty) {
      _say(_currentRoute!.steps.first);
    }

    final poly = Polyline(
      polylineId: _routePolylineId,
      points: route.path,
      width: 6,
      color: Colors.teal,
    );

    setState(() {
      _polylines[_routePolylineId] = poly;
    });
  }

  void _say(DirectionsStep s) {
    final msg = s.toSpeech();
    if (msg.isEmpty) return;

    // Anti-spam para que no repita muy seguido
    if (DateTime.now().difference(_lastTts) < const Duration(seconds: 2)) return;
    _lastTts = DateTime.now();

    _tts.speak(msg);
  }




  Future<void> _askHospital(_Zone z) async {
    if (z.hospitals.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isDismissible: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              'Selecciona hospital en\n${z.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (final h in z.hospitals)
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: () => Navigator.of(context).pop(h),
                  child: Text(h),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (selected == null) return;
    _polylines.clear(); // ← limpia la anterior
    _currentRoute = null;          // <-- limpia lo previo
    _currentStepIdx = 0;
    _lastRouteUpdate = DateTime(0);            // permite dibujar ya mismo
    setState(() => _selectedHospital = selected);

    if (_userLat == null || _userLon == null) return;

    final targetCenter = _findHospitalCenter(selected);
    if (targetCenter == null) return;

    _dest = LatLng(targetCenter.lat, targetCenter.lon);
    //_updateDestPolyline();
    _dest = LatLng(targetCenter.lat, targetCenter.lon);

// si tenemos ubicación del usuario:
    if (_userLat != null && _userLon != null) {
      await _buildGoogleRoute(
        LatLng(_userLat!, _userLon!),
        _dest!,
      );
    }


    if (_ctrl != null && _userLat != null && _userLon != null) {
      final sw = LatLng(
        math.min(_userLat!, _dest!.latitude),
        math.min(_userLon!, _dest!.longitude),
      );
      final ne = LatLng(
        math.max(_userLat!, _dest!.latitude),
        math.max(_userLon!, _dest!.longitude),
      );
      await _ctrl!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: sw, northeast: ne),
          80,
        ),
      );
    }
  }

  Set<Circle> _buildZoneCircles() {
    final z = _activeZone;
    if (z == null) return {};
    return z.centers
        .map(
          (c) => Circle(
        circleId: CircleId('${z.id}_${c.lat}_${c.lon}'),
        center: LatLng(c.lat, c.lon),
        radius: c.radiusM,
        strokeColor: Colors.teal,
        strokeWidth: 2,
        fillColor: Colors.teal.withOpacity(0.08),
      ),
    )
        .toSet();
  }

  String shortHospitalLabel(String name) {
    // Si trae sigla entre paréntesis, úsala (p. ej., "(HUS)")
    final m = RegExp(r'\(([^)]+)\)').firstMatch(name);
    if (m != null && m.group(1)!.trim().isNotEmpty) {
      return m.group(1)!.trim();
    }

    // Si tiene separador con guiones, usa la primera parte
    final firstPart = name.split(' - ').first.trim();

    // Limpia palabras comunes para acortar
    final cleaned = firstPart
        .replaceAll(RegExp(r'\b(Clínica|Hospital|Centro|M[eé]dico|Universitario|de|del|la|el)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final candidate = cleaned.isNotEmpty ? cleaned : firstPart;

    // Limita a 22 chars con puntos suspensivos
    const max = 22;
    return candidate.length <= max ? candidate : '${candidate.substring(0, max)}…';
  }

  // --------------------
  // UI
  // --------------------




  Widget _actionFab({
    required String tag,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool primary = false,
    double width = 190,   // ajusta si quieres más angosto (p. ej. 200)
    double height = 44,   // 40–44 es buen tamaño accesible sin ser gigante
  }) {
    final bg = primary ? Colors.teal.shade600 : Colors.teal.shade200;
    final fg = primary ? Colors.white : Colors.teal.shade900;

    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(width: width, height: height),
      child: FloatingActionButton.extended(
        heroTag: tag,
        onPressed: onPressed,
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        icon: Icon(icon, size: 18),
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 2,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: const StadiumBorder(),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pointsAsync = ref.watch(pointsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa'),
        actions: [
          IconButton(
            tooltip: 'Cambiar tipo de mapa',
            onPressed: () {
              setState(() {
                _mapType = _mapType == MapType.normal
                    ? MapType.hybrid
                    : MapType.normal;
              });
            },
            icon: const Icon(Icons.layers_outlined),
          ),
        ],
      ),
      body: pointsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (points) {
          // dedup por id
          final Map<String, PointInfo> uniqueById = {
            for (final p in points) p.id: p,
          };
          final uniquePoints = uniqueById.values.toList();

          _markers
            ..clear()
            ..addAll(uniquePoints.map((p) {
              final latLng = LatLng(p.lat, p.lon);
              return Marker(
                markerId: MarkerId(p.id),
                position: latLng,
                infoWindow: InfoWindow(
                  title: '${p.nombre} • ${p.zona}',
                  snippet: '${p.tipo} • ${p.riesgo} • r=${p.radioM}m',
                ),
              );
            }));

          final initialTarget = uniquePoints.isNotEmpty
              ? LatLng(uniquePoints.first.lat, uniquePoints.first.lon)
              : const LatLng(6.2442, -75.5812);

          return FutureBuilder(
            future: _ensureLocationPermission(),
            builder: (_, __) {
              return Stack(
                children: [
                  GoogleMap(
                    mapType: _mapType,
                    initialCameraPosition: CameraPosition(
                      target: initialTarget,
                      zoom: 15,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    markers: _markers,
                    circles: _debugShowZonesAlways ? _circles : <Circle>{},
                    polylines: Set<Polyline>.from(_polylines.values),
                    onMapCreated: (c) async {
                      _ctrl = c;
                      await _fitToPoints(
                        uniquePoints.map((e) => LatLng(e.lat, e.lon)),
                      );
                      _startFollowMe();
                    },
                  ),

                  // Banner zona activa
                  if (_activeZone != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.teal.shade50,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shield_outlined,
                                  size: 18, color: Colors.teal),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Zona activa: ${_activeZone!.name}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_dest != null && _remainingMeters != null) ...[
            _actionFab(
              tag: 'dist',
              label: 'Faltan ${_remainingMeters!.toStringAsFixed(0)} m',
              icon: Icons.straighten,
              onPressed: () {},
              primary: true,            // píldora dark (resalta)
              width: 210,               // esta puede ir un pelín más ancha si quieres
              height: 44,
            ),
            const SizedBox(height: 10),
          ],

          if (_activeZone != null) ...[
            _actionFab(
              tag: 'choose-h',
              label: _selectedHospital == null
                  ? 'Elegir hospital'
                  : shortHospitalLabel(_selectedHospital!),
              icon: Icons.local_hospital,
              onPressed: () => _askHospital(_activeZone!),
              primary: false,
              width: 190,
              height: 44,
            ),
            const SizedBox(height: 10),
          ],

          _actionFab(
            tag: 'fit',
            label: 'Ver puntos',
            icon: Icons.center_focus_strong,
            onPressed: () {
              final pts = _markers.map((m) => m.position);
              _fitToPoints(pts);
            },
            primary: false,
            width: 190,
            height: 44,
          ),
          const SizedBox(height: 10),

          _actionFab(
            tag: 'follow',
            label: _followMe ? 'Siguiéndote' : 'No seguir',
            icon: _followMe ? Icons.location_searching : Icons.location_disabled,
            onPressed: () {
              setState(() => _followMe = !_followMe);
              if (_followMe) _startFollowMe();
            },
            primary: false,
            width: 190,
            height: 44,
          ),
        ],
      ),
    );
  }
}

// --- Helpers turn-by-turn ---

// --- Helpers turn-by-turn ---
/*extension DirectionsStepSpeech on DirectionsStep {
  String toSpeech() {
    final txt = instruction.trim();   // ← ya viene sin HTML desde el service
    if (txt.isNotEmpty) return txt;

    // Fallback por si no hay instruction y sí hay maneuver
    switch ((maneuver ?? '').toLowerCase()) {
      case 'turn-right':
        return 'Gira a la derecha';
      case 'turn-left':
        return 'Gira a la izquierda';
      case 'straight':
      case 'continue':
        return 'Sigue recto';
      case 'uturn-right':
      case 'uturn-left':
        return 'Haz un retorno';
      default:
        return 'Sigue recto';
    }
  }
}*/

extension DirectionsStepSpeech on DirectionsStep {
  String toSpeech() {
    final dir = instruction.toLowerCase();

    // patrones comunes en español
    if (dir.contains('gira a la derecha')) return 'Gira a la derecha.';
    if (dir.contains('gira a la izquierda')) return 'Gira a la izquierda.';
    if (dir.contains('continúa recto') || dir.contains('sigue recto')) {
      return 'Sigue derecho unos ${distanceMeters ~/ 10 * 10} metros.';
    }
    if (dir.contains('incorpórate')) return 'Incorpórate a la vía principal.';
    if (dir.contains('mantente')) return 'Mantente en esta vía.';

    // fallback genérico
    return 'Avanza unos ${distanceMeters ~/ 10 * 10} metros.';
  }
}



//String _stripHtml(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '');
