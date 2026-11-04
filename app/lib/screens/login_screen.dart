import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../state/auth_state.dart';
import '../widgets/comunes.dart';
import '../widgets/logo.dart';
import 'registro_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _password = TextEditingController();
  bool _ocultar = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    // Si la sesión se cerró por suspensión o expiración, avisa al usuario.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthState>();
      if (auth.mensajeCierre != null) {
        mostrarMensaje(context, auth.mensajeCierre!, error: true);
        auth.mensajeCierre = null;
      }
    });
  }

  @override
  void dispose() {
    _correo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _enviando = true);
    await intentar(context, () => context.read<AuthState>().login(_correo.text.trim(), _password.text));
    if (mounted) setState(() => _enviando = false);
  }

  /// Si el link público del servidor cambió, se pega aquí el nuevo (sin reinstalar la app).
  Future<void> _cambiarServidor() async {
    final ctrl = TextEditingController(text: servidorPersonalizado ? Uri.parse(apiUrl).origin : '');
    final link = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Cambiar servidor', style: Theme.of(c).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Pega el link que te compartieron, por ejemplo https://algo.trycloudflare.com',
              style: TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(hintText: 'https://...', prefixIcon: Icon(Icons.link_rounded)),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Guardar')),
          if (servidorPersonalizado) ...[
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => Navigator.pop(c, ''), child: const Text('Usar servidor original')),
          ],
        ]),
      ),
    );
    ctrl.dispose();
    if (link == null || !mounted) return;

    final anterior = servidorPersonalizado ? apiUrl : null;
    final nuevo = await guardarServidor(link);
    final ok = await ApiClient.probarServidor(nuevo);
    if (!mounted) return;
    if (ok) {
      setState(() {});
      mostrarMensaje(context, 'Conectado a ${Uri.parse(nuevo).host}');
    } else {
      await guardarServidor(anterior);
      if (!mounted) return;
      setState(() {});
      mostrarMensaje(context, 'No se pudo conectar a ese link. Revisa que esté bien escrito.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: IntrinsicHeight(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Encabezado negro
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const LogoUniRaite(tamano: 52, fondo: Colors.white, color: Colors.black),
                        const SizedBox(width: 12),
                        Text('UniRaite',
                            style: tema.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 40),
                      Text('Viaja con tu\ncomunidad.',
                          style: tema.textTheme.headlineLarge?.copyWith(
                              color: Colors.white, fontSize: 40, height: 1.1, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      Text('Comparte tu auto o encuentra lugar en el de un compañero.',
                          style: tema.textTheme.bodyLarge?.copyWith(color: Colors.white70)),
                    ]),
                  ),
                  // Panel del formulario
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: tema.colorScheme.surface,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + MediaQuery.of(context).padding.bottom),
                      child: Form(
                        key: _form,
                        child: AutofillGroup(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Text('Inicia sesión', style: tema.textTheme.headlineSmall),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _correo,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'Correo institucional',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                              validator: (v) => (v == null || !v.contains('@')) ? 'Escribe tu correo' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              obscureText: _ocultar,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _entrar(),
                              decoration: InputDecoration(
                                hintText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_ocultar ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  onPressed: () => setState(() => _ocultar = !_ocultar),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Escribe tu contraseña' : null,
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _enviando ? null : _entrar,
                              child: _enviando
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: tema.colorScheme.onSurface),
                                    )
                                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Text('Continuar'),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded),
                                    ]),
                            ),
                            const SizedBox(height: 16),
                            Row(children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('o', style: TextStyle(color: tema.colorScheme.onSurfaceVariant)),
                              ),
                              const Expanded(child: Divider()),
                            ]),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegistroScreen()),
                              ),
                              child: const Text('Crear cuenta nueva'),
                            ),
                            if (!kIsWeb) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: TextButton.icon(
                                  onPressed: _cambiarServidor,
                                  icon: const Icon(Icons.dns_outlined, size: 18),
                                  label: Text(
                                    'Servidor: ${Uri.parse(apiUrl).host}',
                                    style: TextStyle(fontSize: 13, color: tema.colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              ),
                            ],
                          ]),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
