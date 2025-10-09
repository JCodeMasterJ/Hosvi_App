import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../core/result.dart';
import '../domain/models.dart';

class PointsRepository {
  final String assetPath;
  PointsRepository({required this.assetPath});

  // Normaliza encabezados: minúsculas, sin tildes, espacios -> "_"
  String _norm(String s) {
    final lower = s.toLowerCase().trim();
    const accents = {'á':'a','é':'e','í':'i','ó':'o','ú':'u','ñ':'n'};
    var out = lower.split('').map((c)=>accents[c] ?? c).join();
    out = out.replaceAll(RegExp(r'\s+'), '_');
    return out;
  }

  static const Map<String,String> _alias = {
    'id':'id','id_punto':'id','codigo':'id',
    'zona':'zona','zona_hospital':'zona','zona_de_hospital':'zona',
    'nombre':'nombre','descripcion':'nombre','nombre_punto':'nombre',
    'lat':'lat','latitud':'lat','latitude':'lat',
    'lon':'lon','long':'lon','longitud':'lon','longitude':'lon',
    'tipo':'tipo','tipo_punto':'tipo',
    'riesgo':'riesgo','nivel_riesgo':'riesgo',
    'mensaje':'mensaje','mensaje_texto':'mensaje','mensaje_audio':'mensaje',
    'audio_hint':'audio_hint','audio':'audio_hint',
    'vibro_patron':'vibro_patron','vibracion':'vibro_patron','patron_vibracion':'vibro_patron',
    'radio_m':'radio_m','radio':'radio_m','radio_metros':'radio_m',
    'orden':'orden','orden_ruta':'orden','secuencia':'orden',
  };

  // Split CSV line respecting quotes
  List<String> _splitCsvLine(String line, String delimiter) {
    final res = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        // Maneja comillas escapadas "" -> una comilla dentro del texto
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (!inQuotes && ch == delimiter) {
        res.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    res.add(buf.toString());
    return res;
  }

  double? _toD(String? v) {
    if (v == null) return null;
    var s = v.trim();
    if (s.isEmpty) return null;
    if (s.contains(',') && !s.contains('.')) s = s.replaceAll(',', '.');
    return double.tryParse(s);
  }

  int? _toI(String? v) {
    if (v == null) return null;
    final s = v.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  Future<Result<List<PointInfo>>> load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);

      // EOL flexible
      final lines = const LineSplitter().convert(
        raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
      ).where((l) => l.trim().isNotEmpty).toList();

      if (lines.isEmpty) return const Ok([]);

      // Detecta delimitador por la cabecera
      final headLine = lines.first;
      final usesSemicolon = headLine.contains(';') && !headLine.contains(',');
      final delimiter = usesSemicolon ? ';' : ',';

      // Parse header
      final rawHeaders = _splitCsvLine(headLine, delimiter);
      final headers = rawHeaders.map((h) => _alias[_norm(h)] ?? _norm(h)).toList();

      // Depuración útil:
      // ignore: avoid_print
      print("HEADERS FIXED: $headers");

      int idx(String name) => headers.indexOf(name);

      const needed = ["id","zona","nombre","lat","lon","tipo","riesgo","mensaje","audio_hint","vibro_patron","radio_m","orden"];
      for (final n in needed) {
        if (!headers.contains(n)) {
          return Err("Falta la columna requerida: $n (encabezados: $headers)");
        }
      }

      final list = <PointInfo>[];
      for (int i = 1; i < lines.length; i++) {
        var ln = lines[i].trim();

        // ⚠️ Algunas herramientas guardan TODA la línea entre comillas.
        // Si es el caso, retiramos la comilla inicial y final.
        if (ln.length >= 2 && ln.startsWith('"') && ln.endsWith('"')) {
          ln = ln.substring(1, ln.length - 1);
        }

        final cols = _splitCsvLine(ln, delimiter);

        if (cols.length < headers.length) {
          // ignore: avoid_print
          print("WARN: línea ${i+1} con columnas ${cols.length}/${headers.length}: ${lines[i]}");
          continue;
        }

        final lat = _toD(cols[idx("lat")]);
        final lon = _toD(cols[idx("lon")]);
        final radio = _toD(cols[idx("radio_m")]) ?? 12;

        if (lat == null || lon == null) {
          // ignore: avoid_print
          print("SKIP fila ${i+1} por lat/lon inválidos: lat='${cols[idx("lat")]}', lon='${cols[idx("lon")]}'.");
          continue;
        }

        list.add(PointInfo(
          id: cols[idx("id")],
          zona: cols[idx("zona")],
          nombre: cols[idx("nombre")],
          lat: lat,
          lon: lon,
          tipo: cols[idx("tipo")],
          riesgo: cols[idx("riesgo")],
          mensaje: cols[idx("mensaje")],
          audioHint: cols[idx("audio_hint")],
          vibroPatron: cols[idx("vibro_patron")],
          radioM: radio,
          orden: _toI(cols[idx("orden")]),
        ));
      }


      return Ok(list);
    } catch (e) {
      return Err("Error cargando CSV: $e");
    }
  }
}
