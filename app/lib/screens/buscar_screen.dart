import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/comunes.dart';
import 'viaje_detalle_screen.dart';

class BuscarScreen extends StatefulWidget {
  const BuscarScreen({super.key});

  @override
  State<BuscarScreen> createState() => _BuscarScreenState();
}

class _BuscarScreenState extends State<BuscarScreen> {
  final _origen = TextEditingController();
  final _destino = TextEditingController();
  final _focoDestino = FocusNode();
  DateTime? _fecha;
  bool _conOrigen = false;
  List<Viaje>? _viajes;
  List<RutaGuardada> _rutas = [];
  String? _error;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _buscar();
    _cargarRutas();
  }

  @override
  void dispose() {
    _origen.dispose();
    _destino.dispose();
    _focoDestino.dispose();
    super.dispose();
  }

  Future<void> _cargarRutas() async {
    try {
      final r = await context.read<AuthState>().api.misRutas();
      if (mounted) setState(() => _rutas = r);
    } catch (_) {}
  }

  Future<void> _buscar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final viajes = await context.read<AuthState>().api.buscarViajes(
            origen: _origen.text.trim(),
            destino: _destino.text.trim(),
            fecha: _fecha == null ? null : DateFormat('yyyy-MM-dd').format(_fecha!),
          );
      if (mounted) setState(() => _viajes = viajes);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _refrescar() async {
    await Future.wait([_buscar(), _cargarRutas()]);
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final f = await showDatePicker(
      context: context,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: 60)),
      initialDate: _fecha ?? hoy,
    );
    setState(() => _fecha = f);
    _buscar();
  }

  Future<void> _guardarRuta() async {
    final destino = _destino.text.trim();
    if (destino.isEmpty) {
      _focoDestino.requestFocus();
      mostrarMensaje(context, 'Escribe primero a dónde vas', error: true);
      return;
    }
    final origen = _origen.text.trim();
    final ok = await intentar(
      context,
      () => context.read<AuthState>().api.guardarRuta(origen.isEmpty ? null : origen, destino),
      exito: 'Te avisaremos con sonido cuando alguien publique un viaje a "$destino".',
    );
    if (ok) _cargarRutas();
  }

  void _usarRuta(RutaGuardada r) {
    _destino.text = r.destino;
    _origen.text = r.origen ?? '';
    setState(() => _conOrigen = (r.origen ?? '').isNotEmpty);
    _buscar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final viajes = _viajes ?? [];
    return RefreshIndicator(
      color: tema.colorScheme.onSurface,
      onRefresh: _refrescar,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buscador(tema)),
          if (_rutas.isNotEmpty) SliverToBoxAdapter(child: _accesosRapidos(tema)),
          SliverToBoxAdapter(
            child: Seccion(
              _destino.text.trim().isEmpty ? 'Viajes disponibles' : 'Viajes a "${_destino.text.trim()}"',
              accion: TextButton.icon(
                onPressed: _guardarRuta,
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('Avisarme'),
              ),
            ),
          ),
          if (_cargando && _viajes == null)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _mensajeVacio(Icons.wifi_off_rounded, 'No se pudo buscar', _error!),
            )
          else if (viajes.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _mensajeVacio(
                Icons.directions_car_outlined,
                'Sin viajes por ahora',
                'Toca "Avisarme" y sonará una notificación en cuanto alguien publique un viaje a tu destino.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 24),
              sliver: SliverList.builder(
                itemCount: viajes.length,
                itemBuilder: (_, i) {
                  final v = viajes[i];
                  return TarjetaViaje(
                    viaje: v,
                    pie: v.esMio
                        ? Text('Tu viaje', style: TextStyle(color: tema.colorScheme.secondary, fontWeight: FontWeight.w700))
                        : null,
                    onTap: () => abrirYRecargar(context, ViajeDetalleScreen(idViaje: v.id), _buscar),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buscador(ThemeData tema) {
    final esquema = tema.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(children: [
        // Píldora principal "¿A dónde vas?" + selector de fecha
        Container(
          decoration: BoxDecoration(color: esquema.surfaceContainerHigh, borderRadius: BorderRadius.circular(32)),
          padding: const EdgeInsets.only(left: 18, right: 6),
          child: Row(children: [
            const Icon(Icons.search_rounded, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _destino,
                focusNode: _focoDestino,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscar(),
                onChanged: (_) => setState(() {}),
                style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                decoration: InputDecoration(
                  hintText: '¿A dónde vas?',
                  hintStyle: tema.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700, fontSize: 18, color: esquema.onSurfaceVariant),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
            if (_destino.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _destino.clear();
                  _buscar();
                },
              ),
            Material(
              color: esquema.surface,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: _elegirFecha,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.schedule_rounded, size: 18),
                    const SizedBox(width: 6),
                    Text(_fecha == null ? 'Cuándo' : diaRelativo(_fecha!),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  ]),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        // Origen opcional
        if (_conOrigen)
          TextField(
            controller: _origen,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _buscar(),
            decoration: InputDecoration(
              hintText: 'Punto de salida',
              prefixIcon: const Icon(Icons.trip_origin_rounded, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _origen.clear();
                  setState(() => _conOrigen = false);
                  _buscar();
                },
              ),
            ),
          )
        else
          Row(children: [
            Material(
              color: tema.colorScheme.surfaceContainerHigh,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => setState(() => _conOrigen = true),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.trip_origin_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Desde cualquier lugar', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_fecha != null)
              InputChip(
                label: Text(diaRelativo(_fecha!)),
                onDeleted: () {
                  setState(() => _fecha = null);
                  _buscar();
                },
              ),
          ]),
      ]),
    );
  }

  Widget _accesosRapidos(ThemeData tema) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(children: [
        for (final r in _rutas.take(3)) ...[
          ListTile(
            onTap: () => _usarRuta(r),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: tema.colorScheme.surfaceContainerHigh, shape: BoxShape.circle),
              child: const Icon(Icons.access_time_filled_rounded, size: 20),
            ),
            title: Text(r.destino, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(r.origen == null ? 'Ruta guardada · te avisamos' : 'Desde ${r.origen}'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
          const Divider(indent: 72),
        ],
      ]),
    );
  }

  Widget _mensajeVacio(IconData icono, String titulo, String mensaje) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(color: tema.colorScheme.surfaceContainerHigh, shape: BoxShape.circle),
          child: Icon(icono, size: 40),
        ),
        const SizedBox(height: 16),
        Text(titulo, style: tema.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(mensaje,
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}
