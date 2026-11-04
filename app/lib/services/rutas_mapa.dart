import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config.dart';

/// Trazo de una ruta por calles entre dos puntos.
class TrazoRuta {
  TrazoRuta({required this.origen, required this.destino, required this.puntos, this.metros, this.segundos});
  final LatLng origen;
  final LatLng destino;
  final List<LatLng> puntos;
  final double? metros;
  final double? segundos;
}

/// Convierte origen/destino (texto libre) en coordenadas con Nominatim y
/// pide la ruta en coche a OSRM. Ambos son servicios gratuitos de OpenStreetMap.
class RutasMapa {
  static final Map<String, TrazoRuta?> _cache = {};

  static Future<TrazoRuta?> trazar(String origen, String destino) async {
    final clave = '$origen→$destino';
    if (_cache.containsKey(clave)) return _cache[clave];
    final a = await _geocodificar(origen);
    final b = await _geocodificar(destino);
    if (a == null || b == null) return null;
    final trazo = await _ruta(a, b) ?? TrazoRuta(origen: a, destino: b, puntos: [a, b]);
    return _cache[clave] = trazo;
  }

  static Future<LatLng?> _geocodificar(String lugar) async {
    final texto = lugar.trim();
    final consulta = aliasLugares[texto.toLowerCase()] ?? texto;
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': consulta,
      'format': 'json',
      'limit': '1',
      if (paisMapa.isNotEmpty) 'countrycodes': paisMapa,
      if (areaMapa.isNotEmpty) ...{'viewbox': areaMapa, 'bounded': '1'},
    });
    try {
      final r = await http.get(uri, headers: {'User-Agent': 'UniRaite/1.0'});
      if (r.statusCode != 200) return null;
      final lista = jsonDecode(r.body) as List;
      if (lista.isEmpty) return null;
      return LatLng(double.parse(lista[0]['lat']), double.parse(lista[0]['lon']));
    } catch (_) {
      return null;
    }
  }

  static Future<TrazoRuta?> _ruta(LatLng a, LatLng b) async {
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/${a.longitude},${a.latitude};${b.longitude},${b.latitude}',
      {'overview': 'full', 'geometries': 'geojson'},
    );
    try {
      final r = await http.get(uri);
      if (r.statusCode != 200) return null;
      final rutas = (jsonDecode(r.body)['routes'] as List?) ?? [];
      if (rutas.isEmpty) return null;
      final ruta = rutas[0];
      final coords = ruta['geometry']['coordinates'] as List;
      return TrazoRuta(
        origen: a,
        destino: b,
        puntos: [for (final c in coords) LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())],
        metros: (ruta['distance'] as num?)?.toDouble(),
        segundos: (ruta['duration'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
