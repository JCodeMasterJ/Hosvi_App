import 'package:flutter/material.dart';
import 'package:hosvi.app/services/auth_service.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel administrador'),
        actions: [
          IconButton(
            onPressed: () => AuthService.instance.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Salir',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Aquí pondrás lo mínimo para el profe:'),
          SizedBox(height: 8),
          Text('• Ver zonas cargadas'),
          Text('• Botón “Forzar recarga de datos”'),
          Text('• (Opcional) ver feedback / métricas'),
        ],
      ),
    );
  }
}
