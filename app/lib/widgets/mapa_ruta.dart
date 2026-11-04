import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/rutas_mapa.dart';

/// Mapa con la ruta marcada de origen a destino (OpenStreetMap + OSRM).
/// Si se pasa [chofer], muestra el auto en esa posición.
class MapaRuta extends StatefulWidget {
  const MapaRuta({
    super.key,
    required this.origen,
    required this.destino,
    this.alto = 260,
    this.chofer,
    this.rumbo,
    this.aviso,
  });
  final String origen;
  final String destino;
  final double alto;
  final LatLng? chofer;
  final double? rumbo;
  final String? aviso;

  @override
  State<MapaRuta> createState() => _MapaRutaState();
}

class _MapaRutaState extends State<MapaRuta> {
  late Future<TrazoRuta?> _trazo = RutasMapa.trazar(widget.origen, widget.destino);
  final _mapa = MapController();
  bool _listo = false;
  bool _seguir = false;

  @override
  void didUpdateWidget(MapaRuta viejo) {
    super.didUpdateWidget(viejo);
    if (viejo.origen != widget.origen || viejo.destino != widget.destino) {
      _trazo = RutasMapa.trazar(widget.origen, widget.destino);
    }
    final c = widget.chofer;
    if (_seguir && _listo && c != null && c != viejo.chofer) {
      _mapa.move(c, _mapa.camera.zoom);
    }
  }

  void _centrarChofer() {
    final c = widget.chofer;
    if (c == null || !_listo) return;
    setState(() => _seguir = true);
    _mapa.move(c, math.max(_mapa.camera.zoom, 16));
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.alto,
        child: FutureBuilder<TrazoRuta?>(
          future: _trazo,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return Container(
                color: esquema.surfaceContainerLow,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              );
            }
            final t = snap.data;
            if (t == null) {
              return Container(
                color: esquema.surfaceContainerLow,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.map_outlined, size: 36, color: esquema.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text('No pudimos ubicar la ruta en el mapa',
                      textAlign: TextAlign.center, style: TextStyle(color: esquema.onSurfaceVariant)),
                  TextButton(
                    onPressed: () => setState(() => _trazo = RutasMapa.trazar(widget.origen, widget.destino)),
                    child: const Text('Reintentar'),
                  ),
                ]),
              );
            }
            return Stack(children: [
              FlutterMap(
                mapController: _mapa,
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(t.puntos.length > 1 ? t.puntos : [t.origen, t.destino]),
                    padding: const EdgeInsets.all(40),
                    maxZoom: 17,
                  ),
                  onMapReady: () => _listo = true,
                  // Si el usuario mueve el mapa con el dedo, deja de seguir al auto.
                  onPositionChanged: (_, gesto) {
                    if (gesto && _seguir) setState(() => _seguir = false);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.jahdevs.uniraite',
                  ),
                  PolylineLayer(polylines: [
                    Polyline(points: t.puntos, strokeWidth: 8, color: Colors.white),
                    Polyline(points: t.puntos, strokeWidth: 5, color: esquema.primary),
                  ]),
                  MarkerLayer(markers: [
                    _marcador(t.origen, Icons.trip_origin, esquema.primary),
                    _marcador(t.destino, Icons.flag_rounded, Colors.red.shade700),
                    if (widget.chofer != null) _auto(widget.chofer!, esquema),
                  ]),
                  const SimpleAttributionWidget(source: Text('OpenStreetMap')),
                ],
              ),
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Wrap(spacing: 8, runSpacing: 6, children: [
                  if (t.metros != null && t.segundos != null)
                    _etiqueta(esquema, '${(t.metros! / 1000).toStringAsFixed(1)} km · ${(t.segundos! / 60).round()} min'),
                  if (widget.aviso != null) _etiqueta(esquema, widget.aviso!),
                ]),
              ),
              if (widget.chofer != null)
                Positioned(
                  right: 10,
                  bottom: 30,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    tooltip: 'Seguir al auto',
                    backgroundColor: _seguir ? esquema.primary : esquema.surface,
                    foregroundColor: _seguir ? esquema.onPrimary : esquema.onSurface,
                    onPressed: _centrarChofer,
                    child: const Icon(Icons.my_location_rounded),
                  ),
                ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _etiqueta(ColorScheme esquema, String texto) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: esquema.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
        ),
        child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Marker _auto(LatLng punto, ColorScheme esquema) => Marker(
        point: punto,
        width: 44,
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            color: esquema.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 8)],
          ),
          child: widget.rumbo == null
              ? Icon(Icons.directions_car_rounded, color: esquema.onPrimary, size: 22)
              : Transform.rotate(
                  angle: widget.rumbo! * math.pi / 180,
                  child: Icon(Icons.navigation_rounded, color: esquema.onPrimary, size: 22),
                ),
        ),
      );

  Marker _marcador(LatLng punto, IconData icono, Color color) => Marker(
        point: punto,
        width: 36,
        height: 36,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6)],
          ),
          child: Icon(icono, color: color, size: 20),
        ),
      );
}
