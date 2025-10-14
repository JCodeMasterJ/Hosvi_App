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
        title: const Text('Panel de administración'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService.instance.signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // CABECERA
            if (user != null) ...[
              Row(
                children: [
                  const Icon(Icons.person_outline, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user.email ?? '(sin correo)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
            ],

            // SECCIÓN 1: GESTIÓN DE DATOS
            const Text(
              'Gestión de datos',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Agregar punto de accesibilidad'),
              onPressed: () {
                // Aquí luego abres un formulario pequeño
                // o importas desde CSV
              },
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Forzar recarga de zonas'),
              onPressed: () {
                // luego conectamos con tu servicio de zonas
              },
            ),
            const SizedBox(height: 24),

            // SECCIÓN 2: VISUALIZACIÓN
            const Text(
              'Visualización',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.map_outlined),
              label: const Text('Abrir mapa general'),
              onPressed: () => Navigator.of(context).pushNamed('/map'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.layers),
              label: const Text('Ver zonas cargadas (debug)'),
              onPressed: () => Navigator.of(context).pushNamed('/debug'),
            ),
            const SizedBox(height: 24),

            // SECCIÓN 3: APP
            const Text(
              'App HOSVI',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continuar a la app'),
              onPressed: () => _goHome(context),
            ),
          ],
        ),
      ),
    );
  }
}
