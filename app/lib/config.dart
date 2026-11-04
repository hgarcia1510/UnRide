import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// URL base de la API, definida al compilar con --dart-define=API_URL=...
///
/// - Android por USB (default): http://127.0.0.1:3000/api con `adb reverse tcp:3000 tcp:3000`
/// - Celular físico: usa la IP de tu PC en la red Wi-Fi, p. ej.
///   flutter run --dart-define=API_URL=http://192.168.1.50:3000/api
/// - Web (PWA): si no se define, usa el mismo servidor desde el que se abrió
///   la página, así sigue funcionando aunque cambie el dominio.
///
/// En Android/iPhone el usuario puede cambiarla desde la app ("Cambiar servidor")
/// si el link público del túnel cambia; se guarda en el teléfono.
const String _apiUrlDefinida = String.fromEnvironment('API_URL');
const _kServidor = 'servidor_api';

final String apiUrlPorDefecto = _apiUrlDefinida.isNotEmpty
    ? _apiUrlDefinida
    : kIsWeb
        ? _apiWebPorDefecto()
        // Teléfono/emulador conectado por USB: `adb reverse tcp:3000 tcp:3000`
        // hace que 127.0.0.1:3000 del teléfono llegue a la API de esta PC.
        : 'http://127.0.0.1:3000/api';

/// Publicada (puerto 80/443): usa su propio servidor.
/// Con `flutter run -d chrome` (puerto aleatorio de desarrollo): usa el servidor local.
String _apiWebPorDefecto() {
  final base = Uri.base;
  final esDesarrollo = base.host == 'localhost' && base.hasPort && base.port != 80 && base.port != 443;
  return esDesarrollo ? 'http://localhost/api' : '${base.origin}/api';
}

String? _apiUrlGuardada;

String get apiUrl => _apiUrlGuardada ?? apiUrlPorDefecto;

/// Servidor personalizado (si el usuario pegó un link nuevo).
bool get servidorPersonalizado => _apiUrlGuardada != null;

Future<void> cargarServidor() async {
  if (kIsWeb) return; // la web siempre usa su propio origen
  final prefs = await SharedPreferences.getInstance();
  _apiUrlGuardada = prefs.getString(_kServidor);
}

/// Acepta "https://algo.trycloudflare.com", con o sin "/api" o "/" final.
/// Con `null` o vacío vuelve al servidor de fábrica.
Future<String> guardarServidor(String? link) async {
  final prefs = await SharedPreferences.getInstance();
  var url = (link ?? '').trim();
  if (url.isEmpty) {
    _apiUrlGuardada = null;
    await prefs.remove(_kServidor);
    return apiUrl;
  }
  if (!url.startsWith('http')) url = 'https://$url';
  final uri = Uri.parse(url);
  url = '${uri.scheme}://${uri.authority}/api';
  _apiUrlGuardada = url;
  await prefs.setString(_kServidor, url);
  return url;
}

/// Convierte una ruta de la API (p. ej. /api/fotos/x.jpg) en URL completa.
String? urlRecurso(String? ruta) {
  if (ruta == null || ruta.isEmpty) return null;
  if (ruta.startsWith('http')) return ruta;
  return Uri.parse(apiUrl).resolve(ruta).toString();
}

/// Recuadro donde se buscan origen/destino en el mapa (oeste,norte,este,sur).
/// Por defecto León, Guanajuato. Vacío = buscar en todo el país.
/// flutter run --dart-define=AREA_MAPA="-103.50,20.80,-103.20,20.55"
const String areaMapa = String.fromEnvironment('AREA_MAPA', defaultValue: '-101.85,21.30,-101.50,20.95');

/// Nombre del campus, usado como origen por defecto al publicar un viaje.
const String nombreCampus = 'Universidad Tecnológica de León';

/// Lugares que no están en OpenStreetMap con ese nombre (en minúsculas).
const Map<String, String> aliasLugares = {
  'campus central': nombreCampus,
  'campus': nombreCampus,
  'utl': nombreCampus,
};

/// Código de país (ISO) para limitar la búsqueda en el mapa.
const String paisMapa = String.fromEnvironment('PAIS_MAPA', defaultValue: 'mx');

/// Cada cuánto se revisan notificaciones nuevas.
const Duration intervaloNotificaciones = Duration(seconds: 20);
