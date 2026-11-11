import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../widgets/comunes.dart';
import 'verificar_correo_screen.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  List<String> _dominios = [];
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    context.read<AuthState>().api.dominiosInstitucionales().then((d) {
      if (mounted) setState(() => _dominios = d);
    }).catchError((_) {});
    _correo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_nombre, _correo, _telefono, _password, _password2]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _esInstitucional {
    final partes = _correo.text.trim().toLowerCase().split('@');
    return partes.length == 2 && _dominios.contains(partes[1]);
  }

  Future<void> _registrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _enviando = true);
    final auth = context.read<AuthState>();
    try {
      await auth.registro(
        nombre: _nombre.text.trim(),
        correo: _correo.text.trim(),
        password: _password.text,
        telefono: _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
      );
      if (!mounted) return;
      final resultado = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => VerificarCorreoScreen(correo: _correo.text.trim())),
      );
      if (mounted && (auth.autenticado || resultado == false)) Navigator.pop(context);
    } catch (e) {
      if (mounted) mostrarMensaje(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final correo = _correo.text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => (v == null || v.trim().length < 3) ? 'Escribe tu nombre real' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _correo,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Correo institucional',
              prefixIcon: const Icon(Icons.school_outlined),
              helperText: _dominios.isEmpty ? null : 'Ej. nombre@${_dominios.first}',
            ),
            validator: (v) => (v == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()))
                ? 'Correo inválido'
                : null,
          ),
          if (correo.contains('@') && _dominios.isNotEmpty && !_esInstitucional)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tema.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, color: tema.colorScheme.onTertiaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Este correo no es institucional. Tu cuenta quedará pendiente hasta que un administrador la valide.',
                    style: TextStyle(color: tema.colorScheme.onTertiaryContainer),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono (opcional)',
              prefixIcon: Icon(Icons.phone_outlined),
              helperText: 'Solo se comparte con tu chofer o pasajeros confirmados',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline)),
            validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password2,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirmar contraseña', prefixIcon: Icon(Icons.lock_outline)),
            validator: (v) => v != _password.text ? 'Las contraseñas no coinciden' : null,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _enviando ? null : _registrar,
            child: _enviando
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Registrarme'),
          ),
        ]),
      ),
    );
  }
}
