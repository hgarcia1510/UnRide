import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/comunes.dart';

/// Panel del Administrador: validación manual de cuentas (muro de confianza)
/// y bloqueo de infractores.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const _filtros = {null: 'Todos', 'Pendiente': 'Pendientes', 'Activo': 'Activos', 'Suspendido': 'Suspendidos'};

  String? _filtro = 'Pendiente';
  String _busqueda = '';
  Map<String, dynamic>? _stats;
  final _cargador = GlobalKey<CargadorState<List<Usuario>>>();

  @override
  void initState() {
    super.initState();
    _cargarStats();
  }

  Future<void> _cargarStats() async {
    try {
      final s = await context.read<AuthState>().api.estadisticasAdmin();
      if (mounted) setState(() => _stats = s);
    } catch (_) {}
  }

  Future<void> _cambiar(Usuario u, String estado) async {
    final api = context.read<AuthState>().api;
    final verbo = estado == 'Activo' ? (u.estadoCuenta == 'Pendiente' ? 'Validar' : 'Reactivar') : 'Suspender';
    if (!await confirmar(context, '$verbo cuenta', '¿$verbo a ${u.nombre}?', accion: verbo)) return;
    if (!mounted) return;
    await intentar(context, () => api.cambiarEstadoCuenta(u.id, estado), exito: 'Cuenta actualizada');
    _cargador.currentState?.recargar();
    _cargarStats();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthState>().api;
    final yo = context.read<AuthState>().usuario!.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Administración')),
      body: Column(children: [
        if (_stats != null)
          SizedBox(
            height: 86,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _tile('Usuarios', _stats!['usuarios']),
                _tile('Pendientes', _stats!['pendientes']),
                _tile('Suspendidos', _stats!['suspendidos']),
                _tile('Vehículos', _stats!['vehiculos']),
                _tile('Viajes activos', _stats!['viajes_programados']),
                _tile('Finalizados', _stats!['viajes_finalizados']),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Buscar por nombre o correo', prefixIcon: Icon(Icons.search), isDense: true),
            onSubmitted: (v) {
              _busqueda = v.trim();
              _cargador.currentState?.recargar();
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            for (final e in _filtros.entries)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: _filtro == e.key,
                  onSelected: (_) {
                    setState(() => _filtro = e.key);
                    _cargador.currentState?.recargar();
                  },
                ),
              ),
          ]),
        ),
        Expanded(
          child: Cargador<List<Usuario>>(
            key: _cargador,
            cargar: () => api.usuariosAdmin(estado: _filtro, q: _busqueda),
            builder: (context, usuarios, _) => usuarios.isEmpty
                ? const Vacio(icono: Icons.people_outline, titulo: 'Sin resultados')
                : ListView.builder(
                    itemCount: usuarios.length,
                    itemBuilder: (_, i) {
                      final u = usuarios[i];
                      return Card(
                        child: ListTile(
                          title: Text(u.nombre),
                          subtitle: Text('${u.correo}${u.esAdmin ? '\nAdministrador' : ''}'),
                          isThreeLine: u.esAdmin,
                          leading: EstadoChip(u.estadoCuenta),
                          trailing: u.id == yo
                              ? null
                              : PopupMenuButton<String>(
                                  onSelected: (estado) => _cambiar(u, estado),
                                  itemBuilder: (_) => [
                                    if (u.estadoCuenta != 'Activo')
                                      PopupMenuItem(
                                        value: 'Activo',
                                        child: Text(u.estadoCuenta == 'Pendiente' ? 'Validar cuenta' : 'Reactivar'),
                                      ),
                                    if (u.estadoCuenta != 'Suspendido')
                                      const PopupMenuItem(value: 'Suspendido', child: Text('Suspender')),
                                  ],
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _tile(String etiqueta, dynamic valor) {
    final tema = Theme.of(context);
    return Container(
      width: 108,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('$valor', style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        Text(etiqueta, style: tema.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
