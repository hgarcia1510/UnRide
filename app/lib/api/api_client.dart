import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;

  @override
  String toString() => message;
}

/// Cliente HTTP de la API REST de UniRaite.
class ApiClient {
  ApiClient({this.onUnauthorized});

  String? token;

  /// Se llama cuando el servidor responde 401/403 (sesión vencida o cuenta suspendida).
  void Function(String message)? onUnauthorized;

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$apiUrl$path'));
    req.headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);

    http.Response res;
    try {
      res = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 15)),
      );
    } on TimeoutException {
      throw ApiException(0, 'El servidor tardó demasiado en responder');
    } catch (_) {
      throw ApiException(0, 'No se pudo conectar con el servidor ($apiUrl)');
    }

    final data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      final msg = data is Map && data['error'] != null ? data['error'] as String : 'Error ${res.statusCode}';
      if (token != null && (res.statusCode == 401 || (res.statusCode == 403 && msg.contains('cuenta')))) {
        onUnauthorized?.call(msg);
      }
      throw ApiException(res.statusCode, msg);
    }
    return data;
  }

  // ---------- Autenticación ----------
  Future<Map<String, dynamic>> login(String correo, String password) async =>
      await _send('POST', '/auth/login', {'correo': correo, 'password': password});

  Future<Map<String, dynamic>> registro({
    required String nombre,
    required String correo,
    required String password,
    String? telefono,
  }) async =>
      await _send('POST', '/auth/registro', {
        'nombre_completo': nombre,
        'correo': correo,
        'password': password,
        'telefono': telefono,
      });

  Future<List<String>> dominiosInstitucionales() async {
    final data = await _send('GET', '/config');
    return List<String>.from(data['dominios_institucionales'] as List);
  }

  // ---------- Usuario ----------
  Future<Usuario> miPerfil() async => Usuario.fromJson(await _send('GET', '/usuarios/me'));

  Future<Usuario> actualizarPerfil(Map<String, dynamic> cambios) async =>
      Usuario.fromJson(await _send('PATCH', '/usuarios/me', cambios));

  /// Sube la foto de perfil (bytes JPG/PNG/WEBP) y regresa el perfil actualizado.
  Future<Usuario> subirFoto(List<int> bytes) async =>
      Usuario.fromJson(await _send('PUT', '/usuarios/me/foto', {'imagen': base64Encode(bytes)}));

  Future<Usuario> quitarFoto() async => Usuario.fromJson(await _send('DELETE', '/usuarios/me/foto'));

  /// Comprueba que un servidor responda (para "Cambiar servidor").
  static Future<bool> probarServidor(String urlApi) async {
    try {
      final r = await http.get(Uri.parse('$urlApi/salud')).timeout(const Duration(seconds: 10));
      return r.statusCode == 200 && r.body.contains('"ok":true');
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> perfilPublico(int id) async => await _send('GET', '/usuarios/$id');

  // ---------- Vehículos ----------
  Future<List<Vehiculo>> misVehiculos() async =>
      (await _send('GET', '/vehiculos') as List).map((e) => Vehiculo.fromJson(e)).toList();

  Future<Vehiculo> crearVehiculo(String placas, String modeloColor, int capacidad) async =>
      Vehiculo.fromJson(await _send('POST', '/vehiculos', {
        'placas': placas,
        'modelo_color': modeloColor,
        'capacidad_maxima': capacidad,
      }));

  Future<void> eliminarVehiculo(int id) => _send('DELETE', '/vehiculos/$id');

  // ---------- Viajes ----------
  Future<List<Viaje>> buscarViajes({String? origen, String? destino, String? fecha}) async {
    final q = <String, String>{
      if (origen != null && origen.isNotEmpty) 'origen': origen,
      if (destino != null && destino.isNotEmpty) 'destino': destino,
      'fecha': ?fecha,
    };
    final query = q.isEmpty ? '' : '?${Uri(queryParameters: q).query}';
    return (await _send('GET', '/viajes$query') as List).map((e) => Viaje.fromJson(e)).toList();
  }

  Future<List<Viaje>> misViajes() async =>
      (await _send('GET', '/viajes/mios') as List).map((e) => Viaje.fromJson(e)).toList();

  Future<Viaje> detalleViaje(int id) async => Viaje.fromJson(await _send('GET', '/viajes/$id'));

  Future<Viaje> publicarViaje({
    required int idVehiculo,
    required String origen,
    required String destino,
    required DateTime salida,
    int? asientos,
    String? notas,
  }) async =>
      Viaje.fromJson(await _send('POST', '/viajes', {
        'id_vehiculo': idVehiculo,
        'punto_origen': origen,
        'punto_destino': destino,
        'fecha_hora_salida': fechaSql(salida),
        'asientos_disponibles': asientos,
        'notas': notas,
      }));

  Future<void> cambiarEstadoViaje(int id, String estado) =>
      _send('PATCH', '/viajes/$id/estado', {'estado': estado});

  Future<void> enviarUbicacion(int idViaje, double lat, double lng, double? rumbo) =>
      _send('PUT', '/viajes/$idViaje/ubicacion', {'latitud': lat, 'longitud': lng, 'rumbo': rumbo});

  Future<UbicacionChofer?> ubicacionChofer(int idViaje) async {
    final j = await _send('GET', '/viajes/$idViaje/ubicacion');
    return j == null ? null : UbicacionChofer.fromJson(j);
  }

  // ---------- Solicitudes ----------
  Future<void> solicitarAsiento(int idViaje) => _send('POST', '/viajes/$idViaje/solicitudes');

  Future<void> responderSolicitud(int idSolicitud, String estado) =>
      _send('PATCH', '/solicitudes/$idSolicitud', {'estado': estado});

  Future<List<Reserva>> misReservas() async =>
      (await _send('GET', '/solicitudes/mias') as List).map((e) => Reserva.fromJson(e)).toList();

  // ---------- Rutas guardadas ----------
  Future<List<RutaGuardada>> misRutas() async =>
      (await _send('GET', '/rutas') as List).map((e) => RutaGuardada.fromJson(e)).toList();

  Future<void> guardarRuta(String? origen, String destino) =>
      _send('POST', '/rutas', {'punto_origen': origen, 'punto_destino': destino});

  Future<void> eliminarRuta(int id) => _send('DELETE', '/rutas/$id');

  // ---------- Notificaciones ----------
  Future<List<Notificacion>> notificaciones() async =>
      (await _send('GET', '/notificaciones') as List).map((e) => Notificacion.fromJson(e)).toList();

  Future<int> notificacionesNoLeidas() async =>
      ((await _send('GET', '/notificaciones/no-leidas'))['total'] as num).toInt();

  Future<void> marcarNotificacionesLeidas() => _send('POST', '/notificaciones/leer-todas');

  // ---------- Reseñas ----------
  Future<void> calificar(int idViaje, int idEvaluado, int calificacion, String? comentario) =>
      _send('POST', '/resenas', {
        'id_viaje': idViaje,
        'id_evaluado': idEvaluado,
        'calificacion': calificacion,
        'comentario': comentario,
      });

  // ---------- Administración ----------
  Future<Map<String, dynamic>> estadisticasAdmin() async => await _send('GET', '/admin/estadisticas');

  Future<List<Usuario>> usuariosAdmin({String? estado, String? q}) async {
    final params = <String, String>{
      'estado': ?estado,
      if (q != null && q.isNotEmpty) 'q': q,
    };
    final query = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    return (await _send('GET', '/admin/usuarios$query') as List).map((e) => Usuario.fromJson(e)).toList();
  }

  Future<void> cambiarEstadoCuenta(int idUsuario, String estado) =>
      _send('PATCH', '/admin/usuarios/$idUsuario', {'estado_cuenta': estado});
}

String fechaSql(DateTime d) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${p(d.month)}-${p(d.day)} ${p(d.hour)}:${p(d.minute)}:00';
}
