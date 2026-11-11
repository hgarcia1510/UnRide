import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import '../widgets/mapa_en_vivo.dart';
import 'calificar_sheet.dart';

class ViajeDetalleScreen extends StatefulWidget {
  const ViajeDetalleScreen({super.key, required this.idViaje});
  final int idViaje;

  @override
  State<ViajeDetalleScreen> createState() => _ViajeDetalleScreenState();
}

class _ViajeDetalleScreenState extends State<ViajeDetalleScreen> {
  final _cargador = GlobalKey<CargadorState<Viaje>>();
  bool _ocupado = false;

  ApiClient get _api => context.read<AuthState>().api;

  Future<void> _accion(Future<void> Function() fn, {String? exito}) async {
    setState(() => _ocupado = true);
    final ok = await intentar(context, fn, exito: exito);
    if (ok) HapticFeedback.mediumImpact();
    await _cargador.currentState?.recargar();
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu viaje')),
      body: Cargador<Viaje>(
        key: _cargador,
        cargar: () => _api.detalleViaje(widget.idViaje),
        builder: (context, v, _) {
          final boton = _botonPrincipal(v);
          return Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                if (v.estado == 'En Curso')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: MapaEnVivo(viaje: v),
                  ),
                _encabezado(v),
                const SizedBox(height: 8),
                _chofer(v),
                if (v.notas != null && v.notas!.isNotEmpty) _notas(v),
                if (v.solicitudes.isNotEmpty) _pasajeros(v),
                if (v.porCalificar.isNotEmpty) _calificar(v),
              ]),
            ),
            if (boton != null)
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, -4))],
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: SafeArea(top: false, child: AbsorbPointer(absorbing: _ocupado, child: boton)),
              ),
          ]);
        },
      ),
    );
  }

  Widget _encabezado(Viaje v) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final falta = v.estado == 'Programado' ? faltaPara(v.salida) : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(hora(v.salida), style: tema.textTheme.headlineLarge?.copyWith(fontSize: 44)),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(diaRelativo(v.salida),
                style: tema.textTheme.titleMedium?.copyWith(color: esquema.onSurfaceVariant)),
          ),
          const Spacer(),
          Padding(padding: const EdgeInsets.only(bottom: 8), child: EstadoChip(v.estado)),
        ]),
        if (falta != null)
          Text('Sale $falta', style: tema.textTheme.titleMedium?.copyWith(color: esquema.secondary)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: esquema.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
          child: RutaVisual(origen: v.origen, destino: v.destino, grande: true),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _dato(Icons.event_seat_rounded, v.asientosDisponibles == 0 ? 'Lleno' : '${v.asientosDisponibles}', 'libres'),
          const SizedBox(width: 10),
          if (v.capacidad != null) _dato(Icons.groups_rounded, '${v.capacidad}', 'capacidad'),
        ]),
      ]),
    );
  }

  Widget _dato(IconData icono, String valor, String etiqueta) {
    final tema = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: tema.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icono, size: 22),
          const SizedBox(width: 10),
          Text(valor, style: tema.textTheme.titleLarge),
          const SizedBox(width: 6),
          Text(etiqueta, style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }

  Widget _chofer(Viaje v) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Avatar(v.choferNombre ?? '?', radio: 26, fotoUrl: v.choferFoto),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.esMio ? 'Tú conduces' : (v.choferNombre ?? 'Chofer'), style: tema.textTheme.titleMedium),
                const SizedBox(height: 2),
                if (v.choferCalificacion != null)
                  Calificacion(v.choferCalificacion!, totalResenas: v.choferTotalResenas),
              ]),
            ),
            if (v.choferTelefono != null)
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: esquema.surfaceContainerHigh, foregroundColor: esquema.onSurface),
                icon: const Icon(Icons.phone_rounded),
                tooltip: 'Copiar teléfono',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: v.choferTelefono!));
                  mostrarMensaje(context, 'Teléfono copiado: ${v.choferTelefono}');
                },
              ),
          ]),
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider()),
          Row(children: [
            const Icon(Icons.directions_car_rounded),
            const SizedBox(width: 14),
            Expanded(child: Text(v.modeloColor ?? '', style: tema.textTheme.bodyLarge)),
            // Placa estilo matrícula
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: esquema.surface,
                border: Border.all(color: esquema.onSurface, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(v.placas ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 15)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _notas(Viaje v) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.chat_bubble_outline_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nota del chofer', style: tema.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(v.notas!, style: tema.textTheme.bodyLarge),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _pasajeros(Viaje v) {
    final puedeResponder = v.esMio && v.estado == 'Programado';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Seccion(v.esMio ? 'Solicitudes' : 'Compañeros de viaje'),
      for (final s in v.solicitudes)
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Avatar(s.pasajeroNombre, radio: 22, fotoUrl: s.pasajeroFoto),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.pasajeroNombre, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Row(children: [
                    Calificacion(s.pasajeroCalificacion, tamano: 12, totalResenas: s.pasajeroTotalResenas),
                    if (s.pasajeroTelefono != null && s.estado == 'Aceptada') ...[
                      const SizedBox(width: 10),
                      Flexible(child: Text(s.pasajeroTelefono!, overflow: TextOverflow.ellipsis)),
                    ],
                  ]),
                ]),
              ),
              if (puedeResponder && s.estado == 'Pendiente') ...[
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  tooltip: 'Rechazar',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => _accion(() => _api.responderSolicitud(s.id, 'Rechazada')),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Paleta.verde, foregroundColor: Colors.white),
                  tooltip: 'Aceptar',
                  icon: const Icon(Icons.check_rounded),
                  onPressed: v.asientosDisponibles == 0
                      ? null
                      : () => _accion(() => _api.responderSolicitud(s.id, 'Aceptada'), exito: 'Pasajero aceptado'),
                ),
              ] else
                EstadoChip(s.estado),
            ]),
          ),
        ),
    ]);
  }

  Widget _calificar(Viaje v) {
    final tema = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Seccion('¿Cómo te fue?'),
      for (final p in v.porCalificar)
        Card(
          child: ListTile(
            leading: Avatar(p.nombre, fotoUrl: p.fotoUrl),
            title: Text('Califica a ${p.nombre}'),
            subtitle: Row(children: [
              for (var i = 0; i < 5; i++) Icon(Icons.star_rounded, size: 18, color: tema.colorScheme.outline),
            ]),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final ok = await mostrarCalificar(context, v.id, p);
              if (ok) await _cargador.currentState?.recargar();
            },
          ),
        ),
    ]);
  }

  Widget? _botonPrincipal(Viaje v) {
    final cargando = _ocupado
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
        : null;

    if (v.esMio) {
      switch (v.estado) {
        case 'Programado':
          return Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  if (await confirmar(context, '¿Cancelar el viaje?',
                      'Avisaremos a los pasajeros confirmados.', accion: 'Sí, cancelar viaje', destructivo: true)) {
                    await _accion(() => _api.cambiarEstadoViaje(v.id, 'Cancelado'), exito: 'Viaje cancelado');
                  }
                },
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => _accion(() => _api.cambiarEstadoViaje(v.id, 'En Curso'), exito: '¡Buen viaje!'),
                icon: cargando ?? const Icon(Icons.navigation_rounded),
                label: const Text('Iniciar viaje'),
              ),
            ),
          ]);
        case 'En Curso':
          return FilledButton.icon(
            onPressed: () => _accion(() => _api.cambiarEstadoViaje(v.id, 'Finalizado'), exito: 'Viaje finalizado'),
            icon: cargando ?? const Icon(Icons.flag_rounded),
            label: const Text('Finalizar viaje'),
          );
        default:
          return null;
      }
    }

    final estado = v.miSolicitudEstado;
    if (v.estado != 'Programado') return null;

    if (estado == 'Pendiente' || estado == 'Aceptada') {
      final aceptada = estado == 'Aceptada';
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(aceptada ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
              color: aceptada ? Paleta.verde : const Color(0xFFB27C00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              aceptada ? 'Tienes lugar confirmado' : 'Esperando respuesta del chofer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () async {
            if (await confirmar(context, '¿Cancelar tu reserva?', 'Se liberará tu lugar para alguien más.',
                accion: 'Sí, cancelar', destructivo: true)) {
              await _accion(() => _api.responderSolicitud(v.miSolicitudId!, 'Cancelada'), exito: 'Reserva cancelada');
            }
          },
          child: const Text('Cancelar mi reserva'),
        ),
      ]);
    }
    if (estado == 'Rechazada') {
      return const FilledButton(onPressed: null, child: Text('Tu solicitud fue rechazada'));
    }
    if (v.asientosDisponibles == 0) {
      return const FilledButton(onPressed: null, child: Text('Viaje lleno'));
    }
    return FilledButton(
      onPressed: () => _accion(() => _api.solicitarAsiento(v.id), exito: 'Solicitud enviada. Te avisaremos con sonido.'),
      child: cargando ??
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Solicitar asiento'),
            const SizedBox(width: 8),
            Text('· ${v.asientosDisponibles} libres', style: const TextStyle(fontWeight: FontWeight.w500)),
          ]),
    );
  }
}
