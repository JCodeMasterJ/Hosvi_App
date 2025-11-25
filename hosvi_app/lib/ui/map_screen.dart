// lib/ui/map_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/result.dart';
import '../data/points_repository.dart';
import '../domain/models.dart';
import '../services/directions_service.dart';

import '../features/voice/tts_service.dart';
import '../features/voice/haptics.dart';
import '../features/a11y/a11y_settings.dart';
import '../features/voice/instructions.dart';
import '../features/voice/poi_announcer.dart';
import '../features/voice/route_progress.dart';
import '../domain/zones.dart';
import '../features/navigation/zone_service.dart';

/// =====================
/// Modelos internos zona
/// =====================

class _ZoneCenter {
  final String? name; // opcional
  final double lat;
  final double lon;
  final double radiusM;

  const _ZoneCenter({
    this.name,
    required this.lat,
    required this.lon,
    required this.radiusM,
  });

  factory _ZoneCenter.fromJson(Map<String, dynamic> j) => _ZoneCenter(
    name: j['name'] as String?,
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

// Turn-by-turn global sencillo
int _currentStepIdx = 0;
const double _stepAdvanceRadius = 25; // m para “consumir” un step

/// =======================
/// Provider de puntos CSV
/// =======================

final pointsProvider = FutureProvider<List<PointInfo>>((ref) async {
  const String _assetPath =
  //'assets/data/PUNTOS_TOTALES_ACTUALIZADOS.csv';
      'assets/data/POIS_FINAL.csv';
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

  late final TtsService _tts;
  late final Haptics _haptics;
  late final InstructionSpeaker _speaker;
  late final PoiAnnouncer _poi;
  late final ZoneService _zoneService;
  late final RouteProgress _prog;

  // Nav: anti-spam y muteo temporal cuando habla un POI
  DateTime _lastTts = DateTime(0);
  bool _navMuted = false;
  Timer? _navMuteTimer;

  StreamSubscription<Position>? _posSub;

  bool _followMe = true;
  MapType _mapType = MapType.normal;
  bool _ready = false;

  // Control de frecuencia para redibujar rutas
  DateTime _lastRouteUpdate =
  DateTime.fromMillisecondsSinceEpoch(0);
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

  // Rutas (Google Directions)
  DirectionsRoute? _currentRoute;
  final PolylineId _routePolylineId =
  const PolylineId('g_directions');
  String _navMode = 'walking'; // 'walking' o 'driving'

  // Círculos de zonas
  bool _debugShowZonesAlways = true;
  final Set<Circle> _circles = {};

  // Paleta (por si la quieres usar luego)
  final List<Color> _zoneColors = [
    Colors.teal,
    Colors.deepPurple,
    Colors.orange,
    Colors.blueGrey,
    Colors.pinkAccent,
  ];

  // Puntos CSV
  List<PointInfo> _allPoints = [];
  final List<RouteNode> _allPois = [];

  // ======================
  // POIs visibles
  // ======================

  String _safeHospitalsOf(RouteNode p) {
    try {
      final dyn = (p as dynamic);
      final val = dyn.hospitals;
      if (val is String) return val;
      if (val is List && val.isNotEmpty) return val.join(' ');
    } catch (_) {}
    return '';
  }

  Iterable<RouteNode> get _visiblePois sync* {
    for (final p in _allPois) {
      // 1) Filtrado por zona activa (se mantiene igual)
      if (_activeZone != null &&
          !_activeZone!.centers.any(
                (c) => _isInside(p.lat, p.lon, c),
          )) {
        continue;
      }

      // 2) Filtrado por hospital (solo si el POI TIENE hospital asignado)
      if (_selectedHospital != null) {
        final hosp = _safeHospitalsOf(p); // '' si no tiene nada

        // 👉 Si el POI no tiene hospital (string vacío), lo tratamos como GLOBAL:
        // no lo filtramos aunque haya hospital seleccionado.
        if (hosp.isNotEmpty &&
            !hosp.toLowerCase().contains(_selectedHospital!.toLowerCase())) {
          continue; // solo filtro si tiene hospital y no coincide
        }
      }

      // 3) Si pasó filtros → es visible
      yield p;
    }
  }


  // =====================
  // Ciclo de vida
  // =====================

  @override
  void initState() {
    super.initState();
    _tts = TtsService.instance;
    _haptics = Haptics();
    _speaker = InstructionSpeaker(_tts, _haptics);
    _zoneService = ZoneService(_speaker);

    _poi = PoiAnnouncer(
      tts: _tts,
      haptics: _haptics,
      getVisiblePois: () => _visiblePois,
      // 🔥 Siempre que hable un POI, silenciamos navegación un rato
      onInterruptNavigation: (dur) => _muteNavFor(dur),
      speakNearMeters: 25,
      minSpeakGap: const Duration(seconds: 18),
    );

    _prog = RouteProgress(advanceRadiusM: 8); // “Ahora” ~8m
    _init();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _ctrl?.dispose();
    _navMuteTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _ensureLocationPermission();
    await _loadZones();

    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      _userLat = p.latitude;
      _userLon = p.longitude;
    } catch (_) {}

    _rebuildZonesCircles();
    _recalcActiveZone();

    if (mounted) {
      setState(() => _ready = true);
    }

    // Iniciamos el seguimiento de posición apenas
    // tenemos permisos y (si es posible) la primera ubicación.
    _startFollowMe();
  }

  // =====================
  // Zonas
  // =====================

  Future<void> _loadZones() async {
    try {
      final raw =
      await rootBundle.loadString('assets/data/zones.json');
      final data = jsonDecode(raw) as List;
      _zones = data
          .map((e) => _Zone.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error cargando zones.json: $e');
    }
  }

  void _rebuildZonesCircles() {
    _circles.clear();
    int i = 0;

    for (final z in _zones) {
      for (final c in z.centers) {
        final col = _colorForHospital(c.name);
        _circles.add(
          Circle(
            circleId: CircleId('zone_${z.id}_$i'),
            center: LatLng(c.lat, c.lon),
            radius: c.radiusM,
            strokeWidth: 2,
            strokeColor: col.withOpacity(0.9),
            fillColor: col.withOpacity(0.15),
          ),
        );
        i++;
      }
    }
    if (mounted) setState(() {});
  }

  bool _isInside(double lat, double lon, _ZoneCenter c) {
    const R = 6371000.0;
    final dLat = (lat - c.lat) * (math.pi / 180);
    final dLon = (lon - c.lon) * (math.pi / 180);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(c.lat * (math.pi / 180)) *
            math.cos(lat * (math.pi / 180)) *
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

  void _clearRoute() {
    setState(() {
      _selectedHospital = null;
      _dest = null;
      _remainingMeters = null;
      _currentRoute = null;
      _currentStepIdx = 0;
      _polylines.clear();
    });
  }

  void _recalcActiveZone() {
    if (_userLat == null ||
        _userLon == null ||
        _zones.isEmpty) return;

    final found =
    _detectActiveZone(_userLat!, _userLon!);
    if (found?.id != _activeZone?.id) {
      _activeZone = found;
      _clearRoute();
      setState(() {});
    }
  }

  _ZoneCenter? _findHospitalCenter(String hospitalName) {
    final z = _activeZone;
    if (z == null || z.centers.isEmpty) return null;

    // 1) Coincidencia exacta por nombre
    final byName = z.centers.firstWhere(
          (c) =>
      c.name != null &&
          c.name!.toLowerCase() ==
              hospitalName.toLowerCase(),
      orElse: () =>
      const _ZoneCenter(lat: 0, lon: 0, radiusM: 0),
    );
    if (byName.lat != 0 || byName.lon != 0) return byName;

    // 2) Centro más cercano al usuario
    if (_userLat != null && _userLon != null) {
      z.centers.sort((a, b) {
        final da = _distMeters(
            _userLat!, _userLon!, a.lat, a.lon);
        final db = _distMeters(
            _userLat!, _userLon!, b.lat, b.lon);
        return da.compareTo(db);
      });
      return z.centers.first;
    }

    // 3) fallback
    return z.centers.first;
  }

  // =====================
  // Permisos / ubicación
  // =====================

  Future<void> _ensureLocationPermission() async {
    final serviceEnabled =
    await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  void _startFollowMe() {
    debugPrint('[HOSVI][MAP] _startFollowMe()');
    _posSub?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
    );

    // Estado interno para anti-spam de instrucciones
    DateTime __lastStepCue =
    DateTime.fromMillisecondsSinceEpoch(0);
    String? __lastBucket; // 'prep' | 'near' | 'now'
    int? __lastAnnouncedStepIdx;

    _posSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((pos) async {
      debugPrint('[HOSVI][MAP] GPS update: '
          'lat=${pos.latitude}, lon=${pos.longitude}');
      const double _prepM = 40; //60
      const double _nearM = 18; //25
      const double _nowM = 6; //8
      const Duration _cueGap = Duration(seconds: 6);

      _userLat = pos.latitude;
      _userLon = pos.longitude;

      // POIs primero (pueden mutear la nav)
      if (_userLat != null && _userLon != null) {
        debugPrint('[HOSVI][POI] updateUserPos($_userLat,$_userLon)');
        _poi.updateUserPos(_userLat!, _userLon!);
      }

      // 1) Zona activa (usando ZoneService)
      if (_userLat != null && _userLon != null) {
        final activeZones = _zoneService.detectActiveZones(
          zones: _zones
              .map((z) {
            final centers = z.centers
                .map(
                  (c) => ZoneCenter(
                name: c.name,
                lat: c.lat,
                lon: c.lon,
                radiusM: c.radiusM,
              ),
            )
                .toList();
            return Zone(
              id: z.id,
              name: z.name,
              centers: centers,
              hospitals: z.hospitals,
            );
          })
              .toList(),
          userLat: _userLat!,
          userLon: _userLon!,
        );

        if (activeZones.isNotEmpty) {
          final primary = activeZones.first;
          _activeZone = _zones.firstWhere(
                (zz) => zz.id == primary.id,
            orElse: () => _zones.first,
          );
        } else {
          _activeZone = null;
        }

        if (mounted) setState(() {});
      }

      // 2) Navegación por ruta
      if (_dest != null) {
        if (_currentRoute == null &&
            _userLat != null &&
            _userLon != null) {
          await _buildGoogleRoute(
            LatLng(_userLat!, _userLon!),
            _dest!,
          );
        } else if (_currentRoute != null) {
          final distToDest = _distMeters(
            _userLat!,
            _userLon!,
            _dest!.latitude,
            _dest!.longitude,
          );

          // --- Re-ruta REAL: solo si te saliste DEL CAMINO, no por distancia al destino ---
          final now = DateTime.now();

          // Distancia máxima permitida desde la polyline real
          const double offRouteTolerance = 35; // metros (ajústalo si quieres)

          // 1. Distancia mínima del usuario a la ruta
          double? minDistToPolyline;
          for (final p in _currentRoute!.path) {
            final d = _distMeters(_userLat!, _userLon!, p.latitude, p.longitude);
            if (minDistToPolyline == null || d < minDistToPolyline!) {
              minDistToPolyline = d;
            }
          }

          // 2. Haz reruta solo si ESTÁS FUERA del camino un buen tramo
          final bool isOffRoute =
              minDistToPolyline != null && minDistToPolyline! > offRouteTolerance;

          // 3. Control de frecuencia
          final bool enoughTimePassed =
              now.difference(_lastRouteUpdate) > const Duration(seconds: 12);

          debugPrint('[HOSVI][ROUTE] distToPolyline='
              '${minDistToPolyline?.toStringAsFixed(1)}m, '
              'offRoute=$isOffRoute');

          if (isOffRoute && enoughTimePassed) {
            _lastRouteUpdate = now;

            await _tts.speakBlocking('Te has desviado. Recalculando ruta.');
            await _buildGoogleRoute(
              LatLng(_userLat!, _userLon!),
              _dest!,
            );

            __lastBucket = null;
            __lastAnnouncedStepIdx = null;
          }

          _remainingMeters = distToDest;

          final steps = _currentRoute!.steps;
          if (steps.isNotEmpty &&
              _currentStepIdx < steps.length) {
            final step = steps[_currentStepIdx];
            final LatLng endPoint = step.endLocation;
            final dStep = _distMeters(
              _userLat!,
              _userLon!,
              endPoint.latitude,
              endPoint.longitude,
            );

            // Buckets de aviso
            String? bucket;
            if (dStep <= _nowM) {
              bucket = 'now';
            } else if (dStep <= _nearM) {
              bucket = 'near';
            } else if (dStep <= _prepM) {
              bucket = 'prep';
            }

            // 👀 LOG de navegación
            debugPrint('[HOSVI][NAV] dStep=${dStep.toStringAsFixed(1)} '
                'bucket=$bucket muted=$_navMuted');

            if (bucket != null && !_navMuted) {
              // Solo aplicamos cooldown si es el mismo step y la misma fase
              final sameBucket = (__lastAnnouncedStepIdx == _currentStepIdx &&
                  __lastBucket == bucket);

              final tooSoonSameBucket = sameBucket &&
                  DateTime.now().difference(__lastStepCue) < _cueGap;

              debugPrint('[HOSVI][NAV] stepIdx=$_currentStepIdx '
                  'dStep=${dStep.toStringAsFixed(1)} '
                  'bucket=$bucket sameBucket=$sameBucket '
                  'tooSoonSameBucket=$tooSoonSameBucket');

              if (!tooSoonSameBucket) {
                final msg = step.toSpeech(phase: bucket);

                switch (bucket) {
                  case 'prep':
                    HapticFeedback.selectionClick();
                    _tts.speak(msg);
                    break;
                  case 'near':
                    HapticFeedback.mediumImpact();
                    _tts.speak(msg);
                    break;
                  case 'now':
                    HapticFeedback.heavyImpact();
                    _tts.speak(msg);
                    break;
                }

                __lastStepCue = DateTime.now();
                __lastBucket = bucket;
                __lastAnnouncedStepIdx = _currentStepIdx;
              }
            }


            // Avance de step
            if (dStep <= _stepAdvanceRadius) {
              debugPrint('[HOSVI][NAV] advancing to stepIdx='
                  '$_currentStepIdx (dStep=${dStep.toStringAsFixed(1)})');
              _currentStepIdx =
                  (_currentStepIdx + 1)
                      .clamp(0, steps.length - 1);
              if (_currentStepIdx < steps.length) {
                HapticFeedback.mediumImpact();
                _say(steps[_currentStepIdx]);
                __lastBucket = null;
                __lastAnnouncedStepIdx = null;
              }
            }
          }

          if (_remainingMeters! < 20) {
            HapticFeedback.heavyImpact();
            _currentRoute = null;
            _clearRoute();
          } else if (mounted) {
            setState(() {});
          }
        }
      }

      // 3) Cámara siguiendo
      if (_followMe && _ctrl != null) {
        await _ctrl!.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(_userLat!, _userLon!),
          ),
        );
      }
    });
  }

  // =====================
  // Utilidades
  // =====================

  Future<void> _fitToPoints(Iterable<LatLng> pts) async {
    if (_ctrl == null || pts.isEmpty) return;
    final swLat =
    pts.map((e) => e.latitude).reduce((a, b) => a < b ? a : b);
    final swLng =
    pts.map((e) => e.longitude).reduce((a, b) => a < b ? a : b);
    final neLat =
    pts.map((e) => e.latitude).reduce((a, b) => a > b ? a : b);
    final neLng =
    pts.map((e) => e.longitude).reduce((a, b) => a > b ? a : b);

    final bounds = LatLngBounds(
      southwest: LatLng(swLat, swLng),
      northeast: LatLng(neLat, neLng),
    );
    await _ctrl!
        .animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  double _distMeters(
      double la1, double lo1, double la2, double lo2) {
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

  void _muteNavFor(Duration d) {
    _navMuted = true;
    _navMuteTimer?.cancel();
    _navMuteTimer = Timer(d, () {
      _navMuted = false;
    });
  }

  void _updateDestPolyline() {
    if (_userLat == null ||
        _userLon == null ||
        _dest == null) {
      _polylines.remove(_destPolylineId);
      setState(() {});
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastRouteUpdate) <
        _routeMinInterval) return;
    _lastRouteUpdate = now;

    final p1 = LatLng(_userLat!, _userLon!);
    final p2 = _dest!;

    _remainingMeters = _distMeters(
      _userLat!,
      _userLon!,
      _dest!.latitude,
      _dest!.longitude,
    );

    final poly = Polyline(
      polylineId: _destPolylineId,
      points: [p1, p2],
      width: 6,
      color: Colors.teal,
    );

    setState(() {
      _polylines[_destPolylineId] = poly;
    });
  }

  Future<void> _buildGoogleRoute(
      LatLng origin, LatLng destination) async {
    _currentRoute = null;
    _polylines.remove(_routePolylineId);
    setState(() {});

    final apiKey =
    const String.fromEnvironment('MAPS_API_KEY', defaultValue: '');
    final svc = DirectionsService(apiKey);
    debugPrint('[HOSVI][ROUTE] Solicitando ruta a Directions API...');
    final route = await svc.getRoute(
      origin: origin,
      destination: destination,
      mode: _navMode,
    );
    if (route == null) {
      debugPrint(
          '[HOSVI][ROUTE][ERROR] route == null. Revisa MAPS_API_KEY y la conectividad.');
      return;
    }

    _currentRoute = route;
    debugPrint('[HOSVI][ROUTE] Ruta recibida con '
        '${_currentRoute!.steps.length} pasos y '
        '${_currentRoute!.path.length} puntos en la polyline.');
    _prog.setRoute(_currentRoute);

    if (_userLat != null &&
        _userLon != null &&
        _dest != null) {
      _remainingMeters = _distMeters(
        _userLat!,
        _userLon!,
        _dest!.latitude,
        _dest!.longitude,
      );
    }

    _polylines.remove(_destPolylineId);

    _currentStepIdx = 0;
    if (_currentRoute!.steps.isNotEmpty) {
      final first = _currentRoute!.steps.first;
      final msg = first.toSpeech(phase: 'prep');
      await _tts.speak('Ruta calculada. $msg');
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
    if (_navMuted) return;
    final msg = s.toSpeech();
    if (msg.isEmpty) return;

    final now = DateTime.now();
    if (now.difference(_lastTts) <
        const Duration(seconds: 2)) return;
    _lastTts = now;

    _tts.speak(msg);
  }

  Future<void> _askHospital(_Zone z) async {
    if (z.hospitals.isEmpty) return;

    final selected =
    await showModalBottomSheet<String>(
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
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final h in z.hospitals)
              Padding(
                padding:
                const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    _colorForHospital(h)
                        .withOpacity(0.9),
                    foregroundColor: Colors.white,
                    minimumSize:
                    const Size.fromHeight(56),
                    shape: const StadiumBorder(),
                    elevation: 2,
                  ),
                  onPressed: () =>
                      Navigator.of(context).pop(h),
                  child: Text(
                    h,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (selected == null) return;

    await _tts.speakBlocking(
        'Destino seleccionado: $selected');

    _polylines.clear();
    _currentRoute = null;
    _currentStepIdx = 0;
    _lastRouteUpdate = DateTime(0);
    setState(() => _selectedHospital = selected);

    if (_userLat == null || _userLon == null) return;
    final targetCenter =
    _findHospitalCenter(selected);
    if (targetCenter == null) return;

    _dest = LatLng(targetCenter.lat, targetCenter.lon);

    if (_userLat != null && _userLon != null) {
      _remainingMeters = _distMeters(
        _userLat!,
        _userLon!,
        _dest!.latitude,
        _dest!.longitude,
      );
      if (mounted) setState(() {});
    }

    if (_userLat != null && _userLon != null) {
      await _buildGoogleRoute(
        LatLng(_userLat!, _userLon!),
        _dest!,
      );
      _poi.updateUserPos(_userLat!, _userLon!);
    }

    if (_ctrl != null &&
        _userLat != null &&
        _userLon != null) {
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

  String shortHospitalLabel(String name) {
    final m =
    RegExp(r'\(([^)]+)\)').firstMatch(name);
    if (m != null &&
        m.group(1)!.trim().isNotEmpty) {
      return m.group(1)!.trim();
    }

    final firstPart =
    name.split(' - ').first.trim();

    final cleaned = firstPart
        .replaceAll(
      RegExp(
        r'\b(Clínica|Hospital|Centro|M[eé]dico|Universitario|de|del|la|el)\b',
        caseSensitive: false,
      ),
      '',
    )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final candidate =
    cleaned.isNotEmpty ? cleaned : firstPart;
    const max = 22;
    return candidate.length <= max
        ? candidate
        : '${candidate.substring(0, max)}…';
  }

  Color _colorForHospital(String? name) {
    final n = (name ?? '').toLowerCase();
    if (n.contains('foscal')) {
      return Colors.indigo.shade400;
    }
    if (n.contains('cardiovascular') ||
        n.contains('icv')) {
      return Colors.deepOrange.shade400;
    }
    if (n.contains('ardila')) {
      return Colors.green.shade500;
    }
    if (n.contains('fosunab')) {
      return Colors.purple.shade400;
    }
    if (n.contains('hus')) {
      return Colors.teal.shade400;
    }
    if (n.contains('usta')) {
      return Colors.brown.shade400;
    }
    return Colors.grey.shade500;
  }

  // =====================
  // UI
  // =====================

  Widget _actionFab({
    required String tag,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool primary = false,
    double width = 190,
    double height = 44,
    Color? customColor,
  }) {
    return Consumer(builder: (context, ref, _) {
      final a11y = ref.watch(a11yProvider);

      final bg = customColor ??
          (primary
              ? Colors.teal.shade600
              : Colors.teal.shade200);
      const fg = Colors.white;

      final h =
      a11y.bigTargets ? height + 14 : height;
      final iconSize = 18 * a11y.iconScale;

      return ConstrainedBox(
        constraints: BoxConstraints.tightFor(
          width: width,
          height: h,
        ),
        child: FloatingActionButton.extended(
          heroTag: tag,
          onPressed: onPressed,
          label: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontSize: 16 * a11y.textScale,
              fontWeight: FontWeight.w600,
            ),
            semanticsLabel: label,
          ),
          icon: Icon(icon, size: iconSize),
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 2,
          extendedPadding:
          const EdgeInsets.symmetric(horizontal: 12),
          shape: const StadiumBorder(),
          materialTapTargetSize:
          MaterialTapTargetSize.shrinkWrap,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final pointsAsync = ref.watch(pointsProvider);
    final a11y = ref.watch(a11yProvider);

    final child = Scaffold(
      appBar: AppBar(
        title: const Text('Mapa'),
        actions: [
          IconButton(
            tooltip: 'Accesibilidad',
            onPressed: _openA11ySheet,
            icon: const Icon(Icons.accessibility_new),
          ),
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
        loading: () =>
        const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Error: $e')),
        data: (points) {
          // dedup por id
          final Map<String, PointInfo> uniqueById = {
            for (final p in points) p.id: p,
          };
          final uniquePoints =
          uniqueById.values.toList();
          _allPoints = uniquePoints;

          // Construye RouteNode para POIs
          _allPois
            ..clear()
            ..addAll(
              uniquePoints.map((p) {
                String hospitalsStr = '';
                try {
                  final dyn = (p as dynamic);
                  final h = dyn.hospitals;
                  if (h is String) hospitalsStr = h;
                  if (h is List && h.isNotEmpty) {
                    hospitalsStr = h.join(' ');
                  }
                } catch (_) {}

                return RouteNode(
                  lat: p.lat,
                  lon: p.lon,
                  nombre: p.nombre,
                  mensaje: p.mensaje,
                  riesgo: p.riesgo,
                  // Usamos al menos 25 m de radio si el CSV viene vacío o muy pequeño
                  radioM: math.max((p.radioM ?? 0).toDouble(), 25),
                  orden: p.orden,
                  hospitals: hospitalsStr.isEmpty
                      ? const []
                      : [hospitalsStr],
                );
              }),
            );

          _markers
            ..clear()
            ..addAll(uniquePoints.map((p) {
              final latLng =
              LatLng(p.lat, p.lon);
              return Marker(
                markerId: MarkerId(p.id),
                position: latLng,
                infoWindow: InfoWindow(
                  title: '${p.nombre} • ${p.zona}',
                  snippet:
                  '${p.tipo} • ${p.riesgo} • r=${p.radioM}m',
                ),
              );
            }));

          final initialTarget =
          uniquePoints.isNotEmpty
              ? LatLng(
            uniquePoints.first.lat,
            uniquePoints.first.lon,
          )
              : const LatLng(6.2442, -75.5812);

          return FutureBuilder(
            future: _ensureLocationPermission(),
            builder: (_, __) {
              return Stack(
                children: [
                  GoogleMap(
                    mapType: _mapType,
                    initialCameraPosition:
                    CameraPosition(
                      target: initialTarget,
                      zoom: 15,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    markers: _markers,
                    circles: _debugShowZonesAlways
                        ? _circles
                        : <Circle>{},
                    polylines:
                    Set<Polyline>.from(
                        _polylines.values),
                    onMapCreated: (c) async {
                      _ctrl = c;
                      if (_ready) {
                        await _fitToPoints(
                          uniquePoints.map(
                                (e) => LatLng(
                              e.lat,
                              e.lon,
                            ),
                          ),
                        );
                        _startFollowMe();
                      }
                    },
                  ),

                  // Banner de zona activa
                  if (_activeZone != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Material(
                        elevation: 2,
                        borderRadius:
                        BorderRadius.circular(12),
                        color: Colors.teal.shade50,
                        child: Padding(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                size: 18,
                                color: Colors.teal,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Builder(
                                  builder: (_) {
                                    final nearestCenter =
                                    _activeZone!
                                        .centers
                                        .reduce((a, b) {
                                      final da =
                                      _distMeters(
                                        _userLat!,
                                        _userLon!,
                                        a.lat,
                                        a.lon,
                                      );
                                      final db =
                                      _distMeters(
                                        _userLat!,
                                        _userLon!,
                                        b.lat,
                                        b.lon,
                                      );
                                      return da < db
                                          ? a
                                          : b;
                                    });

                                    return Text(
                                      'Zona activa: ${nearestCenter.name}',
                                      textAlign:
                                      TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.teal,
                                        fontWeight:
                                        FontWeight.w600,
                                      ),
                                    );
                                  },
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
        crossAxisAlignment:
        CrossAxisAlignment.end,
        children: [
          if (_dest != null &&
              _remainingMeters != null) ...[
            _actionFab(
              tag: 'dist',
              label:
              'Faltan ${_remainingMeters!.toStringAsFixed(0)} m',
              icon: Icons.straighten,
              onPressed: () {},
              primary: true,
              width: 210,
              height: 44,
            ),
            const SizedBox(height: 10),
          ],
          if (_activeZone != null) ...[
            _actionFab(
              tag: 'choose-h',
              label: _selectedHospital == null
                  ? 'Elegir hospital'
                  : shortHospitalLabel(
                  _selectedHospital!),
              icon: Icons.local_hospital,
              onPressed: () =>
                  _askHospital(_activeZone!),
              primary: false,
              width: 190,
              height: 44,
              customColor: _colorForHospital(
                  _selectedHospital),
            ),
            const SizedBox(height: 10),
          ],
          _actionFab(
            tag: 'fit',
            label: 'Ver puntos',
            icon: Icons.center_focus_strong,
            onPressed: () {
              final pts =
              _markers.map((m) => m.position);
              _fitToPoints(pts);
            },
            primary: false,
            width: 190,
            height: 44,
          ),
          const SizedBox(height: 10),
          _actionFab(
            tag: 'follow',
            label: _followMe
                ? 'Siguiéndote'
                : 'No seguir',
            icon: _followMe
                ? Icons.location_searching
                : Icons.location_disabled,
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

    const invert = <double>[
      -1, 0, 0, 0, 255,
      0, -1, 0, 0, 255,
      0, 0, -1, 0, 255,
      0, 0, 0, 1, 0,
    ];

    return a11y.highContrast
        ? ColorFiltered(
      colorFilter:
      const ColorFilter.matrix(invert),
      child: child,
    )
        : child;
  }

  // ACCESIBILIDAD
  void _openA11ySheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          Consumer(builder: (context, ref, __) {
            final a11y = ref.watch(a11yProvider);
            final ctrl =
            ref.read(a11yProvider.notifier);

            return Padding(
              padding: const EdgeInsets.fromLTRB(
                  16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Accesibilidad',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: a11y.highContrast,
                    onChanged: ctrl.setHighContrast,
                    title: const Text(
                        'Alto contraste (invertido)'),
                  ),
                  SwitchListTile(
                    value: a11y.bigTargets,
                    onChanged: ctrl.setBigTargets,
                    title: const Text(
                        'Botones y controles más grandes'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Tamaño de texto'),
                      Expanded(
                        child: Slider(
                          value: a11y.textScale,
                          min: 1.0,
                          max: 1.8,
                          label: a11y.textScale
                              .toStringAsFixed(1),
                          onChanged: ctrl.setTextScale,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Tamaño de iconos'),
                      Expanded(
                        child: Slider(
                          value: a11y.iconScale,
                          min: 1.0,
                          max: 1.8,
                          label: a11y.iconScale
                              .toStringAsFixed(1),
                          onChanged: ctrl.setIconScale,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Velocidad de voz'),
                      Expanded(
                        child: Slider(
                          value: a11y.ttsRate,
                          min: 0.5,
                          max: 1.25,
                          label: a11y.ttsRate
                              .toStringAsFixed(2),
                          onChanged: (v) {
                            ctrl.setTtsRate(v);
                            _tts.updateRate(v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          }),
    );
  }
}

// --- Helpers turn-by-turn ---
String _stripHtml(String s) =>
    s.replaceAll(RegExp(r'<[^>]+>'), '');

extension DirectionsStepSpeech on DirectionsStep {
  /// phase: 'prep' | 'near' | 'now'
  String toSpeech({String phase = 'prep'}) {
    final raw =
    _stripHtml(instruction).toLowerCase();
    final dist =
        (distanceMeters ~/ 10) * 10; // redondeo

    final hasRight =
        raw.contains('derecha') ||
            raw.contains('right');
    final hasLeft =
        raw.contains('izquierda') ||
            raw.contains('left');
    final hasContinue = raw.contains('contin') ||
        raw.contains('recto') ||
        raw.contains('sigue') ||
        raw.contains('straight');
    final hasRoundabout =
        raw.contains('glorieta') ||
            raw.contains('rotonda') ||
            raw.contains('roundabout');

    if (hasRight || hasLeft) {
      final lado = hasRight ? 'derecha' : 'izquierda';
      switch (phase) {
        case 'prep':
          return 'Prepárate, en $dist metros gira a la $lado.';
        case 'near':
          return 'En $dist metros gira a la $lado.';
        case 'now':
          return 'Ahora gira a la $lado.';
        default:
          return 'Gira a la $lado en $dist metros.';
      }
    }

    if (hasContinue && !hasRoundabout) {
      switch (phase) {
        case 'prep':
          return 'Prepárate para seguir derecho.';
        case 'near':
          return 'En $dist metros sigue derecho.';
        case 'now':
          return 'Sigue derecho ahora.';
        default:
          return 'Sigue derecho unos $dist metros.';
      }
    }

    if (hasRoundabout) {
      switch (phase) {
        case 'prep':
          return 'Prepárate, se acerca una glorieta.';
        case 'near':
          return 'En $dist metros entra a la glorieta.';
        case 'now':
          return 'Ahora entra a la glorieta y sigue las indicaciones.';
        default:
          return 'Entra a la glorieta en $dist metros.';
      }
    }

    switch (phase) {
      case 'prep':
        return 'Prepárate para avanzar.';
      case 'near':
        return 'En $dist metros avanza.';
      case 'now':
        return 'Avanza ahora.';
      default:
        return 'Avanza unos $dist metros.';
    }
  }
}
