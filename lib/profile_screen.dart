import 'package:flutter/material.dart';

import 'auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.usuario});

  final String usuario;

  @override
  Widget build(BuildContext context) {
    final Duration? duracion = AuthService.instance.sessionDuration;
    final bool puedeEscribir = AuthService.instance.hasPermission('write');
    final bool puedeEliminar = AuthService.instance.hasPermission('delete');
    final bool esAdmin = AuthService.instance.hasPermission('admin');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de usuario'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  usuario.isNotEmpty
                      ? usuario[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 40, color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                usuario,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (esAdmin) ...<Widget>[
              const SizedBox(height: 4),
              const Center(
                child: Chip(
                  label: Text('Administrador'),
                  backgroundColor: Colors.amber,
                ),
              ),
            ],
            const SizedBox(height: 32),
            _SectionTitle(title: 'Informacion de sesion'),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.access_time,
              label: 'Duracion de sesion',
              value: duracion != null
                  ? '${duracion.inMinutes} min ${duracion.inSeconds % 60} s'
                  : 'No disponible',
            ),
            _InfoRow(
              icon: Icons.person,
              label: 'ID de usuario',
              value: usuario,
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: 'Permisos'),
            const SizedBox(height: 8),
            _PermissionRow(label: 'Lectura', granted: true),
            _PermissionRow(label: 'Escritura', granted: puedeEscribir),
            _PermissionRow(label: 'Eliminacion', granted: puedeEliminar),
            _PermissionRow(label: 'Administracion', granted: esAdmin),
            const SizedBox(height: 32),
            _SectionTitle(title: 'Seguridad'),
            const SizedBox(height: 8),
            const _InfoRow(
              icon: Icons.lock,
              label: 'Almacenamiento',
              value: 'Cifrado AES-256',
            ),
            const _InfoRow(
              icon: Icons.shield,
              label: 'Pantalla segura',
              value: 'Activa',
            ),
            const _InfoRow(
              icon: Icons.location_off,
              label: 'Deteccion GPS falso',
              value: 'Activa',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.label, required this.granted});

  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            size: 20,
            color: granted ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}
