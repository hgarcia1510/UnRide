import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../widgets/comunes.dart';

class VerificarCorreoScreen extends StatefulWidget {
  const VerificarCorreoScreen({super.key, required this.correo});

  final String correo;

  @override
  State<VerificarCorreoScreen> createState() => _VerificarCorreoScreenState();
}

class _VerificarCorreoScreenState extends State<VerificarCorreoScreen> {
  final _codigo = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (_codigo.text.trim().length != 6) {
      mostrarMensaje(context, 'Escribe el código de 6 dígitos.', error: true);
      return;
    }
    setState(() => _enviando = true);
    try {
      final pendiente = await context.read<AuthState>().verificarCorreo(widget.correo, _codigo.text.trim());
      if (!mounted) return;
      if (pendiente != null) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            icon: const Icon(Icons.hourglass_top_rounded),
            title: const Text('Correo verificado'),
            content: Text(pendiente),
            actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido'))],
          ),
        );
        if (mounted) Navigator.pop(context, false);
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) mostrarMensaje(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _reenviar() async {
    setState(() => _enviando = true);
    try {
      await context.read<AuthState>().reenviarVerificacion(widget.correo);
      if (mounted) mostrarMensaje(context, 'Código reenviado. Revisa también la carpeta de correo no deseado.');
    } catch (e) {
      if (mounted) mostrarMensaje(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Verifica tu correo')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: tema.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.mark_email_unread_outlined, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Enviamos un código a ${widget.correo}. Escríbelo para confirmar que tienes acceso a esa cuenta.',
                  style: tema.textTheme.bodyLarge,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _codigo,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            onSubmitted: (_) => _confirmar(),
            decoration: const InputDecoration(
              labelText: 'Código de 6 dígitos',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _enviando ? null : _confirmar,
            child: _enviando
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Confirmar correo'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _enviando ? null : _reenviar,
            child: const Text('Reenviar código'),
          ),
        ],
      ),
    );
  }
}
