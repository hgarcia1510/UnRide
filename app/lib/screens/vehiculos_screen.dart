import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/comunes.dart';

class VehiculosScreen extends StatefulWidget {
  const VehiculosScreen({super.key});

  @override
  State<VehiculosScreen> createState() => _VehiculosScreenState();
}

class _VehiculosScreenState extends State<VehiculosScreen> {
  final _cargador = GlobalKey<CargadorState<List<Vehiculo>>>();

  Future<void> _agregar() async {
    final creado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NuevoVehiculoSheet(),
    );
    if (creado == true) _cargador.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthState>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis vehículos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: Cargador<List<Vehiculo>>(
        key: _cargador,
        cargar: api.misVehiculos,
        builder: (context, vehiculos, recargar) => vehiculos.isEmpty
            ? const Vacio(
                icono: Icons.directions_car_outlined,
                titulo: 'Sin vehículos',
                mensaje: 'Registra tu auto para poder ofrecer viajes como chofer.',
              )
            : ListView(padding: const EdgeInsets.only(top: 8, bottom: 96), children: [
                for (final v in vehiculos)
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.directions_car)),
                      title: Text(v.modeloColor),
                      subtitle: Text('${v.placas} · ${v.capacidad} pasajeros'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirmar(context, 'Eliminar vehículo', '¿Quitar ${v.placas} de tu cuenta?',
                              accion: 'Eliminar')) {
                            if (!context.mounted) return;
                            await intentar(context, () => api.eliminarVehiculo(v.id));
                            recargar();
                          }
                        },
                      ),
                    ),
                  ),
              ]),
      ),
    );
  }
}

class _NuevoVehiculoSheet extends StatefulWidget {
  const _NuevoVehiculoSheet();

  @override
  State<_NuevoVehiculoSheet> createState() => _NuevoVehiculoSheetState();
}

class _NuevoVehiculoSheetState extends State<_NuevoVehiculoSheet> {
  final _form = GlobalKey<FormState>();
  final _placas = TextEditingController();
  final _modelo = TextEditingController();
  int _capacidad = 4;
  bool _enviando = false;

  @override
  void dispose() {
    _placas.dispose();
    _modelo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _enviando = true);
    final ok = await intentar(
      context,
      () => context.read<AuthState>().api.crearVehiculo(_placas.text.trim(), _modelo.text.trim(), _capacidad),
      exito: 'Vehículo registrado',
    );
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Nuevo vehículo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextFormField(
            controller: _placas,
            textCapitalization: TextCapitalization.characters,
            maxLength: 15,
            decoration: const InputDecoration(labelText: 'Placas', prefixIcon: Icon(Icons.pin_outlined)),
            validator: (v) => (v == null || v.trim().length < 3) ? 'Placas inválidas' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _modelo,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Modelo y color',
              hintText: 'Ej. Chevy 2010 - Blanco',
              prefixIcon: Icon(Icons.palette_outlined),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Capacidad de pasajeros'),
            const Spacer(),
            IconButton.outlined(
              onPressed: _capacidad > 1 ? () => setState(() => _capacidad--) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 40,
              child: Text('$_capacidad', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton.outlined(
              // Regla de negocio: máximo 8 pasajeros.
              onPressed: _capacidad < 8 ? () => setState(() => _capacidad++) : null,
              icon: const Icon(Icons.add),
            ),
          ]),
          const SizedBox(height: 20),
          FilledButton(onPressed: _enviando ? null : _guardar, child: const Text('Guardar')),
        ]),
      ),
    );
  }
}
