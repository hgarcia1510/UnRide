import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/comunes.dart';
import 'viaje_detalle_screen.dart';

/// Reservas del usuario cuando actúa como Pasajero.
class MisReservasScreen extends StatelessWidget {
  const MisReservasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Cargador<List<Reserva>>(
      cargar: () => context.read<AuthState>().api.misReservas(),
      builder: (context, reservas, recargar) => reservas.isEmpty
          ? const Vacio(
              icono: Icons.event_seat_outlined,
              titulo: 'Aún no tienes reservas',
              mensaje: 'Busca un viaje hacia tu destino y solicita un asiento.',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: reservas.length,
              itemBuilder: (_, i) {
                final r = reservas[i];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => abrirYRecargar(context, ViajeDetalleScreen(idViaje: r.idViaje), recargar),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(fechaHora(r.salida), style: tema.textTheme.titleMedium)),
                          EstadoChip(r.estadoViaje == 'Programado' ? r.estado : r.estadoViaje),
                        ]),
                        const SizedBox(height: 12),
                        RutaVisual(origen: r.origen, destino: r.destino),
                        const Divider(height: 24),
                        Row(children: [
                          Avatar(r.choferNombre, radio: 14, fotoUrl: r.choferFoto),
                          const SizedBox(width: 8),
                          Flexible(child: Text(r.choferNombre, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 6),
                          Calificacion(r.choferCalificacion, totalResenas: r.choferTotalResenas),
                          const Spacer(),
                          Text(r.placas, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ]),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
