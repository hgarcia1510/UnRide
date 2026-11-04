import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/alertas.dart';
import '../state/auth_state.dart';
import '../widgets/banner_notificacion.dart';
import 'buscar_screen.dart';
import 'mis_reservas_screen.dart';
import 'mis_viajes_screen.dart';
import 'notificaciones_screen.dart';
import 'perfil_screen.dart';
import 'viaje_detalle_screen.dart';

const _intervaloRevision = Duration(seconds: 15);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  int _noLeidas = 0;
  bool _pedirPermiso = false;
  bool _revisando = false;
  Timer? _timer;

  static const _titulos = ['', 'Conducir', 'Mis reservas', 'Cuenta'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepararPermisos();
    _revisar();
    _timer = Timer.periodic(_intervaloRevision, (_) => _revisar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _revisar();
  }

  Future<void> _prepararPermisos() async {
    if (await Alertas.permisoConcedido()) return;
    if (kIsWeb) {
      // En navegador/iPhone el permiso debe pedirse con un toque del usuario.
      if (mounted) setState(() => _pedirPermiso = true);
    } else {
      await Alertas.pedirPermiso();
    }
  }

  Future<void> _activarNotificaciones() async {
    final ok = await Alertas.pedirPermiso();
    await Alertas.sonar(); // también "desbloquea" el audio en Safari/Chrome
    if (!mounted) return;
    setState(() => _pedirPermiso = !ok);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Listo. Escucharás un sonido cuando haya novedades.'
          : 'Sin permiso del sistema: solo verás y escucharás avisos con la app abierta.'),
    ));
  }

  /// Revisa novedades: aviso con sonido si la app está abierta, notificación del sistema si no.
  Future<void> _revisar() async {
    if (_revisando) return;
    _revisando = true;
    try {
      final api = context.read<AuthState>().api;
      final nuevas = await Alertas.nuevasDesdeServidor(api);
      final total = await api.notificacionesNoLeidas();
      if (!mounted) return;
      setState(() => _noLeidas = total);
      if (nuevas.isEmpty) return;

      final enPrimerPlano = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      if (enPrimerPlano) {
        final ultima = nuevas.last;
        Alertas.sonar();
        mostrarBannerNotificacion(
          nuevas.length == 1
              ? ultima
              : Notificacion(
                  id: ultima.id,
                  titulo: ultima.titulo,
                  mensaje: '${ultima.mensaje}  (+${nuevas.length - 1} más)',
                  idViaje: ultima.idViaje,
                  leida: false,
                  fecha: ultima.fecha,
                ),
          alTocar: () => ultima.idViaje != null && nuevas.length == 1
              ? _abrirViaje(ultima.idViaje!)
              : _abrirNotificaciones(),
        );
      } else {
        for (final n in nuevas.take(5)) {
          await Alertas.notificacionSistema(n);
        }
      }
    } catch (_) {
      // Sin conexión: se reintenta en el siguiente ciclo.
    } finally {
      _revisando = false;
    }
  }

  void _abrirViaje(int id) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ViajeDetalleScreen(idViaje: id)));
  }

  Future<void> _abrirNotificaciones() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificacionesScreen()));
    if (mounted) setState(() => _noLeidas = 0);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthState>().usuario!;
    final tema = Theme.of(context);
    final nombre = usuario.nombre.split(' ').first;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Text(
          _tab == 0 ? 'Hola, $nombre' : _titulos[_tab],
          style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              style: IconButton.styleFrom(backgroundColor: tema.colorScheme.surfaceContainerHigh),
              tooltip: 'Notificaciones',
              onPressed: _abrirNotificaciones,
              icon: Badge(
                isLabelVisible: _noLeidas > 0,
                label: Text(_noLeidas > 9 ? '9+' : '$_noLeidas'),
                child: Icon(_noLeidas > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded),
              ),
            ),
          ),
        ],
      ),
      body: Column(children: [
        if (_pedirPermiso) _avisoPermiso(tema),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [
              BuscarScreen(),
              MisViajesScreen(),
              MisReservasScreen(),
              PerfilScreen(),
            ],
          ),
        ),
      ]),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: tema.colorScheme.outlineVariant))),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
            NavigationDestination(
                icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car_rounded), label: 'Conducir'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Reservas'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Cuenta'),
          ],
        ),
      ),
    );
  }

  Widget _avisoPermiso(ThemeData tema) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(color: tema.colorScheme.inverseSurface, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.notifications_active_rounded, color: tema.colorScheme.onInverseSurface),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Activa las notificaciones para escuchar cuando haya viajes o respuestas.',
              style: TextStyle(color: tema.colorScheme.onInverseSurface, fontSize: 13.5)),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF8DB2F8)),
          onPressed: _activarNotificaciones,
          child: const Text('Activar'),
        ),
      ]),
    );
  }
}
