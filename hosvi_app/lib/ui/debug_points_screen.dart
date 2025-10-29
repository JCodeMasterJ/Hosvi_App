import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/result.dart';
import '../domain/models.dart';
import '../data/points_repository.dart';

// 🔁 Cambia aquí sample ↔ full para probar
//const String _assetPath = 'assets/data/puntos_full_normalized_arreglado.csv';
// const String _assetPath = 'assets/data/puntos_sample.csv';

//const String _assetPath = 'assets/data/puntos_hospitales.csv';
const String _assetPath = 'assets/data/PUNTOS_TOTALES_ACTUALIZADOS.csv';

final pointsProvider = FutureProvider<List<PointInfo>>((ref) async {
  final repo = PointsRepository(assetPath: _assetPath);
  final res = await repo.load();

  // ✅ Patron matching con el nombre de campo correcto: 'data'
  return switch (res) {
    Ok(data: final data) => data,
    Err(message: final m) => throw Exception(m),
    _ => throw Exception('Resultado inesperado'),
  };
});

class DebugPointsScreen extends ConsumerWidget {
  const DebugPointsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync = ref.watch(pointsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Debug puntos')),
      body: pointsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            "Error cargando $_assetPath\n\n$e\n\n"
                "Verifica:\n"
                "• Que el archivo exista en assets/\n"
                "• Que esté declarado en pubspec.yaml\n"
                "• `flutter pub get` ejecutado\n",
          ),
        ),
        data: (points) {
          if (points.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "No hay puntos para mostrar.\n\nVerifica:\n"
                    "• $_assetPath tiene filas válidas (lat/lon no vacíos)\n",
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  "Fuente: $_assetPath\nTotal: ${points.length} puntos",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: points.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = points[i];
                    return ListTile(
                      dense: true,
                      title: Text("${p.nombre} • ${p.zona}"),
                      subtitle: Text(
                        "(${p.lat.toStringAsFixed(6)}, ${p.lon.toStringAsFixed(6)})"
                            " • ${p.tipo} • ${p.riesgo} • r=${(p.radioM ?? 12)}m\n"
                            "msg: ${p.mensaje}\n"
                            "hint: ${p.audioHint}\n"
                            "vibro: ${p.vibroPatron}",
                      ),
                      trailing: Text("#${p.orden ?? 0}"),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
