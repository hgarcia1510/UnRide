import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/alertas.dart';
import '../state/auth_state.dart';
import '../widgets/banner_notificacion.dart';
import '../widgets/comunes.dart';
import 'viaje_detalle_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  Future<List<Notificacion>> _cargar() async {
    final api = context.read<AuthState>().api;
    final lista = await api.notificaciones();
    if (lista.any((n) => !n.leida)) api.marcarNotificacionesLeidas().catchError((_) {});
    return lista;
  }

  Future<void> _probar() async {
    if (!await Alertas.permisoConcedido()) await Alertas.pedirPermiso();
    await Alertas.sonar();
    mostrarBannerNotificacion(Notificacion(
      id: -1,
      titulo: 'Así sonarán tus avisos',
      mensaje: 'Te avisaremos cuando haya viajes en tu ruta o respondan tu solicitud.',
      leida: false,
      fecha: DateTime.now(),
    ));
  }

  String _hace(DateTime f) {
    final d = DateTime.now().difference(f);
    if (d.inMinutes < 1) return 'ahora';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    if (d.inDays < 7) return 'hace ${d.inDays} d';
    return fechaHora(f);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          TextButton.icon(
            onPressed: _probar,
            icon: const Icon(Icons.volume_up_rounded, size: 20),
            label: const Text('Probar sonido'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Cargador<List<Notificacion>>(
        cargar: _cargar,
        builder: (context, lista, _) {
          if (lista.isEmpty) {
            return const Vacio(
              icono: Icons.notifications_none_rounded,
              titulo: 'Todo al día',
              mensaje: 'Aquí verás nuevos viajes en tus rutas, solicitudes y confirmaciones.',
            );
          }
          final nuevas = lista.where((n) => !n.leida).toList();
          final anteriores = lista.where((n) => n.leida).toList();
          return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            if (nuevas.isNotEmpty) ...[
              const Seccion('Nuevas'),
              for (final n in nuevas) _item(n),
            ],
            if (anteriores.isNotEmpty) ...[
              const Seccion('Anteriores'),
              for (final n in anteriores) _item(n),
            ],
          ]);
        },
      ),
    );
  }

  Widget _item(Notificacion n) {
    final tema = Theme.of(context);
    final color = colorNotificacion(n.titulo);
    return InkWell(
      onTap: n.idViaje == null
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ViajeDetalleScreen(idViaje: n.idViaje!)),
              ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
            child: Icon(iconoNotificacion(n.titulo), color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(n.titulo,
                      style: tema.textTheme.titleMedium?.copyWith(fontWeight: n.leida ? FontWeight.w600 : FontWeight.w800)),
                ),
                Text(_hace(n.fecha), style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
              ]),
              const SizedBox(height: 3),
              Text(n.mensaje, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
            ]),
          ),
          if (!n.leida)
            Container(
              margin: const EdgeInsets.only(left: 8, top: 6),
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: tema.colorScheme.secondary, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }
}
