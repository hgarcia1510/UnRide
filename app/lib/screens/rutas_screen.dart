import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/comunes.dart';

/// Rutas guardadas: el usuario recibe una notificación cuando un chofer
/// publica un viaje cuyo destino coincide.
class RutasScreen extends StatefulWidget {
  const RutasScreen({super.key});

  @override
  State<RutasScreen> createState() => _RutasScreenState();
}

class _RutasScreenState extends State<RutasScreen> {
  final _cargador = GlobalKey<CargadorState<List<RutaGuardada>>>();

  Future<void> _agregar() async {
    final origen = TextEditingController();
    final destino = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nueva ruta'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: destino, decoration: const InputDecoration(labelText: 'Destino *')),
          const SizedBox(height: 12),
          TextField(controller: origen, decoration: const InputDecoration(labelText: 'Origen (opcional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true && destino.text.trim().isNotEmpty && mounted) {
      await intentar(
        context,
        () => context.read<AuthState>().api.guardarRuta(
              origen.text.trim().isEmpty ? null : origen.text.trim(),
              destino.text.trim(),
            ),
      );
      _cargador.currentState?.recargar();
    }
    origen.dispose();
    destino.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthState>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Rutas guardadas')),
      floatingActionButton: FloatingActionButton(onPressed: _agregar, child: const Icon(Icons.add)),
      body: Cargador<List<RutaGuardada>>(
        key: _cargador,
        cargar: api.misRutas,
        builder: (context, rutas, recargar) => rutas.isEmpty
            ? const Vacio(
                icono: Icons.notifications_none,
                titulo: 'Sin rutas guardadas',
                mensaje: 'Guarda tu destino frecuente (ej. "Villas de San Juan") y te avisaremos cuando alguien publique un viaje.',
              )
            : ListView(padding: const EdgeInsets.only(top: 8, bottom: 96), children: [
                for (final r in rutas)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: Text(r.destino),
                      subtitle: Text(r.origen == null ? 'Desde cualquier origen' : 'Desde ${r.origen}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await intentar(context, () => api.eliminarRuta(r.id));
                          recargar();
                        },
                      ),
                    ),
                  ),
              ]),
      ),
    );
  }
}
