// lib/features/admin/admin_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hosvi.app/services/auth_service.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  void _goHome(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel administrador'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.instance.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null) ...[
            Row(
              children: [
                const Icon(Icons.person, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user.email ?? '(sin correo)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
          ],
          const Text(
            'Acciones rápidas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Continuar a la app'),
            onPressed: () => _goHome(context),
          ),
          const SizedBox(height: 8),
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
          const Text('• Botón “Forzar recarga de datos”'),
          const Text('• (Opcional) ver feedback / métricas'),
        ],
      ),
    );
  }
}
