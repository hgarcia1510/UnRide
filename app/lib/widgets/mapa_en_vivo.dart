import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/auth_state.dart';
import 'mapa_ruta.dart';

/// Mapa de un viaje En Curso con la ubicación del chofer en vivo.
/// - Chofer: lee el GPS del teléfono y lo envía a la API.
/// - Pasajero: consulta la última ubicación del chofer cada pocos segundos.
class MapaEnVivo extends StatefulWidget {
  const MapaEnVivo({super.key, required this.viaje});
  final Viaje viaje;

  @override
  State<MapaEnVivo> createState() => _MapaEnVivoState();
}

class _MapaEnVivoState extends State<MapaEnVivo> {
  static const _intervalo = Duration(seconds: 5);

  StreamSubscription<Position>? _gps;
  Timer? _timer;
  LatLng? _chofer;
  double? _rumbo;
  String? _aviso;
  DateTime _ultimoEnvio = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    if (widget.viaje.esMio) {
      _compartir();
    } else {
      _consultar();
      _timer = Timer.periodic(_intervalo, (_) => _consultar());
    }
  }

  @override
  void dispose() {
    _gps?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _compartir() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return _avisar('Activa la ubicación del teléfono');
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
    if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
      return _avisar('Sin permiso de ubicación');
    }
    _avisar('Compartiendo tu ubicación');
    _gps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen(_nuevaPosicion, onError: (_) => _avisar('No se pudo leer el GPS'));
  }

  void _nuevaPosicion(Position p) {
    if (!mounted) return;
    setState(() {
      _chofer = LatLng(p.latitude, p.longitude);
      if (p.heading > 0) _rumbo = p.heading;
    });
    // No saturar la API: como mucho un envío cada [_intervalo].
    final ahora = DateTime.now();
    if (ahora.difference(_ultimoEnvio) < _intervalo) return;
    _ultimoEnvio = ahora;
    context
        .read<AuthState>()
        .api
        .enviarUbicacion(widget.viaje.id, p.latitude, p.longitude, _rumbo)
        .then((_) => _avisar('Compartiendo tu ubicación'), onError: (_) => _avisar('Sin conexión, reintentando…'));
  }

  Future<void> _consultar() async {
    try {
      final u = await context.read<AuthState>().api.ubicacionChofer(widget.viaje.id);
      if (!mounted) return;
      setState(() {
        if (u == null) {
          _aviso = 'Esperando ubicación del chofer';
          return;
        }
        _chofer = LatLng(u.latitud, u.longitud);
        _rumbo = u.rumbo;
        _aviso = u.haceSegundos < 30 ? 'En vivo' : 'Actualizado hace ${_hace(u.haceSegundos)}';
      });
    } catch (_) {
      // Error de red puntual: se reintenta en el siguiente ciclo.
    }
  }

  String _hace(int s) => s < 60 ? '$s s' : '${s ~/ 60} min';

  void _avisar(String texto) {
    if (mounted && _aviso != texto) setState(() => _aviso = texto);
  }

  @override
  Widget build(BuildContext context) => MapaRuta(
        origen: widget.viaje.origen,
        destino: widget.viaje.destino,
        alto: 300,
        chofer: _chofer,
        rumbo: _rumbo,
        aviso: _aviso,
      );
}
