import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/comunes.dart';
import 'publicar_viaje_screen.dart';
import 'viaje_detalle_screen.dart';

/// Viajes publicados por el usuario cuando actúa como Chofer.
class MisViajesScreen extends StatefulWidget {
  const MisViajesScreen({super.key});

  @override
  State<MisViajesScreen> createState() => _MisViajesScreenState();
}

class _MisViajesScreenState extends State<MisViajesScreen> {
  final _cargador = GlobalKey<CargadorState<List<Viaje>>>();

  Future<void> _recargar() async => _cargador.currentState?.recargar();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirYRecargar(context, const PublicarViajeScreen(), _recargar),
        icon: const Icon(Icons.add_road),
        label: const Text('Publicar viaje'),
      ),
      body: Cargador<List<Viaje>>(
        key: _cargador,
        cargar: () => context.read<AuthState>().api.misViajes(),
        builder: (context, viajes, recargar) => viajes.isEmpty
            ? const Vacio(
                icono: Icons.directions_car_outlined,
                titulo: '¿Tienes auto y lugares libres?',
                mensaje: 'Publica tu viaje y los compañeros que van a tu destino recibirán una notificación.',
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: viajes.length,
                itemBuilder: (_, i) {
                  final v = viajes[i];
                  return TarjetaViaje(
                    viaje: v,
                    pie: v.solicitudesPendientes > 0
                        ? Row(children: [
                            Icon(Icons.person_add_alt_1, size: 18, color: tema.colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              v.solicitudesPendientes == 1
                                  ? '1 solicitud por responder'
                                  : '${v.solicitudesPendientes} solicitudes por responder',
                              style: TextStyle(color: tema.colorScheme.primary, fontWeight: FontWeight.w600),
                            ),
                          ])
                        : null,
                    onTap: () => abrirYRecargar(context, ViajeDetalleScreen(idViaje: v.id), recargar),
                  );
                },
              ),
      ),
    );
  }
}
