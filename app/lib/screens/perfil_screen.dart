import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../widgets/comunes.dart';
import '../services/alertas.dart';
import 'admin_screen.dart';
import 'notificaciones_screen.dart';
import 'rutas_screen.dart';
import 'vehiculos_screen.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final u = auth.usuario!;
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return RefreshIndicator(
      color: esquema.onSurface,
      onRefresh: () => auth.refrescarPerfil().catchError((_) {}),
      child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        // Encabezado: nombre grande + calificación + avatar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.nombre, style: tema.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: esquema.surfaceContainerHigh, borderRadius: BorderRadius.circular(20)),
                  child: Calificacion(u.calificacion, tamano: 14),
                ),
                const SizedBox(height: 6),
                Text(u.correo, style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant)),
              ]),
            ),
            _FotoPerfil(usuarioNombre: u.nombre, fotoUrl: u.fotoUrl),
          ]),
        ),
        // Accesos en cuadros
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            _Cuadro(icono: Icons.directions_car_rounded, texto: 'Vehículos',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehiculosScreen()))),
            _Cuadro(icono: Icons.route_rounded, texto: 'Rutas',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RutasScreen()))),
            _Cuadro(icono: Icons.notifications_rounded, texto: 'Avisos',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacionesScreen()))),
          ]),
        ),
        const SizedBox(height: 12),
        // Estadísticas
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: esquema.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            _Stat(valor: u.viajesComoChofer, etiqueta: 'como chofer'),
            _Stat(valor: u.viajesComoPasajero, etiqueta: 'como pasajero'),
            _Stat(valor: u.totalResenas, etiqueta: 'reseñas'),
          ]),
        ),
        const SizedBox(height: 8),
        const Divider(height: 24, thickness: 8),
        ListTile(
          leading: const Icon(Icons.volume_up_rounded),
          title: const Text('Notificaciones y sonido'),
          subtitle: const Text('Activar permisos y probar la alerta'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final ok = await Alertas.pedirPermiso() || await Alertas.permisoConcedido();
            await Alertas.sonar();
            if (context.mounted) {
              mostrarMensaje(context, ok
                  ? 'Notificaciones activadas. Así sonarán tus avisos.'
                  : 'Activa las notificaciones de UniRaite en los ajustes de tu teléfono.',
                  error: !ok);
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.person_outline_rounded),
          title: const Text('Editar perfil'),
          subtitle: const Text('Nombre, teléfono y contraseña'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _editarPerfil(context),
        ),
        if (u.esAdmin)
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Panel de administrador'),
            subtitle: const Text('Validar y suspender cuentas'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
          ),
        const Divider(indent: 16, endIndent: 16),
        ListTile(
          leading: Icon(Icons.logout_rounded, color: esquema.error),
          title: Text('Cerrar sesión', style: TextStyle(color: esquema.error)),
          onTap: () async {
            if (await confirmar(context, '¿Cerrar sesión?', 'Dejarás de recibir avisos en este teléfono.',
                accion: 'Cerrar sesión', destructivo: true)) {
              auth.cerrarSesion();
            }
          },
        ),
      ]),
    );
  }

  Future<void> _editarPerfil(BuildContext context) async {
    final auth = context.read<AuthState>();
    final u = auth.usuario!;
    final nombre = TextEditingController(text: u.nombre);
    final telefono = TextEditingController(text: u.telefono ?? '');
    final actual = TextEditingController();
    final nueva = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(c).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Editar perfil', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre completo')),
          const SizedBox(height: 12),
          TextField(
            controller: telefono,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono'),
          ),
          const SizedBox(height: 20),
          Text('Cambiar contraseña (opcional)', style: Theme.of(c).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(controller: actual, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña actual')),
          const SizedBox(height: 12),
          TextField(controller: nueva, obscureText: true, decoration: const InputDecoration(labelText: 'Nueva contraseña')),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              final ok = await intentar(c, () async {
                await auth.api.actualizarPerfil({
                  'nombre_completo': nombre.text.trim(),
                  'telefono': telefono.text.trim(),
                  if (nueva.text.isNotEmpty) 'password_actual': actual.text,
                  if (nueva.text.isNotEmpty) 'password_nueva': nueva.text,
                });
                await auth.refrescarPerfil();
              }, exito: 'Perfil actualizado');
              if (ok && c.mounted) Navigator.pop(c);
            },
            child: const Text('Guardar'),
          ),
        ]),
      ),
    );
  }
}

/// Foto de perfil con botón de cámara; al tocarla permite cambiarla o quitarla.
class _FotoPerfil extends StatefulWidget {
  const _FotoPerfil({required this.usuarioNombre, this.fotoUrl});
  final String usuarioNombre;
  final String? fotoUrl;

  @override
  State<_FotoPerfil> createState() => _FotoPerfilState();
}

class _FotoPerfilState extends State<_FotoPerfil> {
  bool _subiendo = false;

  Future<void> _elegir(ImageSource origen) async {
    final auth = context.read<AuthState>();
    try {
      // Se reduce en el teléfono para que suba rápido (máx. 800 px, calidad 82).
      final archivo = await ImagePicker().pickImage(source: origen, maxWidth: 800, maxHeight: 800, imageQuality: 82);
      if (archivo == null) return;
      setState(() => _subiendo = true);
      final bytes = await archivo.readAsBytes();
      await auth.api.subirFoto(bytes);
      await auth.refrescarPerfil();
      if (mounted) mostrarMensaje(context, 'Foto de perfil actualizada');
    } catch (e) {
      if (mounted) mostrarMensaje(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<void> _quitar() async {
    final auth = context.read<AuthState>();
    setState(() => _subiendo = true);
    await intentar(context, () async {
      await auth.api.quitarFoto();
      await auth.refrescarPerfil();
    }, exito: 'Foto eliminada');
    if (mounted) setState(() => _subiendo = false);
  }

  void _opciones() {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Foto de perfil', style: Theme.of(c).textTheme.headlineSmall),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto'),
            onTap: () {
              Navigator.pop(c);
              _elegir(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de la galería'),
            onTap: () {
              Navigator.pop(c);
              _elegir(ImageSource.gallery);
            },
          ),
          if (widget.fotoUrl != null)
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Theme.of(c).colorScheme.error),
              title: Text('Quitar foto', style: TextStyle(color: Theme.of(c).colorScheme.error)),
              onTap: () {
                Navigator.pop(c);
                _quitar();
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _subiendo ? null : _opciones,
      child: Stack(clipBehavior: Clip.none, children: [
        Avatar(widget.usuarioNombre, radio: 38, fotoUrl: widget.fotoUrl),
        if (_subiendo)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              child: Center(
                child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
              ),
            ),
          ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: esquema.primary,
              shape: BoxShape.circle,
              border: Border.all(color: esquema.surface, width: 3),
            ),
            child: Icon(Icons.photo_camera_rounded, size: 15, color: esquema.onPrimary),
          ),
        ),
      ]),
    );
  }
}

class _Cuadro extends StatelessWidget {
  const _Cuadro({required this.icono, required this.texto, required this.onTap});
  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: tema.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(children: [
                Icon(icono, size: 28),
                const SizedBox(height: 8),
                Text(texto, style: tema.textTheme.labelLarge),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.valor, required this.etiqueta});
  final int valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Expanded(
      child: Column(children: [
        Text('$valor', style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(etiqueta, style: tema.textTheme.bodySmall),
      ]),
    );
  }
}
