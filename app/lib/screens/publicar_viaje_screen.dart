import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/comunes.dart';
import 'vehiculos_screen.dart';

class PublicarViajeScreen extends StatefulWidget {
  const PublicarViajeScreen({super.key});

  @override
  State<PublicarViajeScreen> createState() => _PublicarViajeScreenState();
}

class _PublicarViajeScreenState extends State<PublicarViajeScreen> {
  final _form = GlobalKey<FormState>();
  final _origen = TextEditingController(text: nombreCampus);
  final _destino = TextEditingController();
  final _notas = TextEditingController();
  List<Vehiculo>? _vehiculos;
  Vehiculo? _vehiculo;
  int? _asientos;
  DateTime _salida = DateTime.now().add(const Duration(hours: 1));
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cargarVehiculos();
  }

  @override
  void dispose() {
    _origen.dispose();
    _destino.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _cargarVehiculos() async {
    try {
      final vs = await context.read<AuthState>().api.misVehiculos();
      if (!mounted) return;
      setState(() {
        _vehiculos = vs;
        if (vs.isNotEmpty) {
          _vehiculo = vs.firstWhere((v) => v.id == _vehiculo?.id, orElse: () => vs.first);
          _asientos = _vehiculo!.capacidad;
        }
      });
    } catch (e) {
      if (mounted) mostrarMensaje(context, e.toString(), error: true);
    }
  }

  Future<void> _elegirFechaHora() async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      firstDate: DateTime(ahora.year, ahora.month, ahora.day),
      lastDate: ahora.add(const Duration(days: 30)),
      initialDate: _salida,
    );
    if (fecha == null || !mounted) return;
    final h = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_salida));
    if (h == null) return;
    setState(() => _salida = DateTime(fecha.year, fecha.month, fecha.day, h.hour, h.minute));
  }

  Future<void> _publicar() async {
    if (!_form.currentState!.validate()) return;
    if (_vehiculo == null) {
      mostrarMensaje(context, 'Primero registra un vehículo', error: true);
      return;
    }
    if (_salida.isBefore(DateTime.now())) {
      mostrarMensaje(context, 'La hora de salida ya pasó', error: true);
      return;
    }
    setState(() => _enviando = true);
    try {
      final viaje = await context.read<AuthState>().api.publicarViaje(
            idVehiculo: _vehiculo!.id,
            origen: _origen.text.trim(),
            destino: _destino.text.trim(),
            salida: _salida,
            asientos: _asientos,
            notas: _notas.text.trim().isEmpty ? null : _notas.text.trim(),
          );
      if (!mounted) return;
      final n = viaje.notificados ?? 0;
      mostrarMensaje(context, n > 0 ? 'Viaje publicado. Avisamos a $n compañero(s) con esta ruta.' : 'Viaje publicado');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) mostrarMensaje(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar viaje')),
      body: _vehiculos == null
          ? const Center(child: CircularProgressIndicator())
          : _vehiculos!.isEmpty
              ? Vacio(
                  icono: Icons.no_crash_outlined,
                  titulo: 'Necesitas un vehículo',
                  mensaje: 'Registra tu auto (placas, modelo y capacidad) para poder publicar viajes.',
                  accion: FilledButton.icon(
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const VehiculosScreen()));
                      _cargarVehiculos();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Registrar vehículo'),
                  ),
                )
              : _formulario(),
    );
  }

  Widget _formulario() {
    final tema = Theme.of(context);
    return Form(
      key: _form,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        TextFormField(
          controller: _origen,
          decoration: const InputDecoration(labelText: 'Punto de origen', prefixIcon: Icon(Icons.trip_origin)),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _destino,
          decoration: const InputDecoration(
            labelText: 'Destino',
            hintText: 'Ej. Villas de San Juan',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
        ),
        const SizedBox(height: 14),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: tema.colorScheme.outline),
          ),
          leading: const Icon(Icons.schedule),
          title: const Text('Salida'),
          subtitle: Text(fechaHora(_salida), style: tema.textTheme.titleMedium),
          trailing: const Icon(Icons.edit_calendar),
          onTap: _elegirFechaHora,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          initialValue: _vehiculo?.id,
          decoration: const InputDecoration(labelText: 'Vehículo', prefixIcon: Icon(Icons.directions_car)),
          items: [
            for (final v in _vehiculos!)
              DropdownMenuItem(value: v.id, child: Text('${v.modeloColor} · ${v.placas}', overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (id) => setState(() {
            _vehiculo = _vehiculos!.firstWhere((v) => v.id == id);
            _asientos = _vehiculo!.capacidad;
          }),
        ),
        const SizedBox(height: 18),
        Text('Asientos que ofreces', style: tema.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (var i = 1; i <= (_vehiculo?.capacidad ?? 1); i++)
            ChoiceChip(
              label: Text('$i'),
              selected: _asientos == i,
              onSelected: (_) => setState(() => _asientos = i),
            ),
        ]),
        const SizedBox(height: 18),
        TextFormField(
          controller: _notas,
          maxLength: 255,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Notas (opcional)',
            hintText: 'Ej. Salgo por la puerta 3, paso por Av. Universidad',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _enviando ? null : _publicar,
          icon: const Icon(Icons.send),
          label: const Text('Publicar'),
        ),
      ]),
    );
  }
}
