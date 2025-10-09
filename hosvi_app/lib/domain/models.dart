class PointInfo {
  final String id, zona, nombre, tipo, riesgo, mensaje, audioHint, vibroPatron;
  final double lat, lon, radioM;
  final int? orden;

  const PointInfo({
    required this.id,
    required this.zona,
    required this.nombre,
    required this.lat,
    required this.lon,
    required this.tipo,
    required this.riesgo,
    required this.mensaje,
    required this.audioHint,
    required this.vibroPatron,
    required this.radioM,
    required this.orden,
  });
}
