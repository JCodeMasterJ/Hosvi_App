// lib/features/admin/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:hosvi.app/services/auth_service.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  void _goHome(BuildContext context) {
    // Lleva a la app “normal” (tus 3 botones)
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel administrador'),
        actions: [
          IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.instance.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Acciones rápidas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // 👉 Botón clave: continuar a la app normal
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continuar a la app'),
            onPressed: () => _goHome(context),
          ),
          const SizedBox(height: 8),

          // Navegar a vistas que ya tienes
          OutlinedButton.icon(
            icon: const Icon(Icons.map_outlined),
            label: const Text('Abrir mapa'),
            onPressed: () => Navigator.of(context).pushNamed('/map'),
          ),
          const SizedBox(height: 8),

          OutlinedButton.icon(
            icon: const Icon(Icons.layers),
            label: const Text('Ver zonas cargadas (debug)'),
            onPressed: () => Navigator.of(context).pushNamed('/debug'),
          ),

          const SizedBox(height: 24),
          const Divider(height: 32),

          const Text('Pendientes para el profe (mínimos):'),
          const SizedBox(height: 8),
          const Text('• Ver zonas cargadas'),
          const Text('• Botón “Forzar recarga de datos” (opcional)'),
          const Text('• (Opcional) ver feedback / métricas'),
        ],
      ),
    );
  }
}