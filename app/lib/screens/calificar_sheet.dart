import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/comunes.dart';

/// Hoja inferior para calificar (1–5 estrellas) a un participante del viaje.
Future<bool> mostrarCalificar(BuildContext context, int idViaje, Participante p) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CalificarSheet(idViaje: idViaje, participante: p),
  );
  return r ?? false;
}

class _CalificarSheet extends StatefulWidget {
  const _CalificarSheet({required this.idViaje, required this.participante});
  final int idViaje;
  final Participante participante;

  @override
  State<_CalificarSheet> createState() => _CalificarSheetState();
}

class _CalificarSheetState extends State<_CalificarSheet> {
  int _estrellas = 5;
  final _comentario = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    final ok = await intentar(
      context,
      () => context.read<AuthState>().api.calificar(
            widget.idViaje,
            widget.participante.id,
            _estrellas,
            _comentario.text.trim().isEmpty ? null : _comentario.text.trim(),
          ),
      exito: '¡Gracias por tu reseña!',
    );
    if (!mounted) return;
    setState(() => _enviando = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Califica a ${widget.participante.nombre}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                iconSize: 40,
                onPressed: () => setState(() => _estrellas = i),
                icon: Icon(i <= _estrellas ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber.shade700),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _comentario,
          maxLength: 255,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Comentario (opcional)'),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: _enviando ? null : _enviar, child: const Text('Enviar reseña')),
      ]),
    );
  }
}
