import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/alertas.dart';

/// Sesión del usuario: token JWT + perfil. Un mismo usuario puede ser
/// chofer o pasajero (roles dinámicos); solo el rol Administrador cambia la UI.
class AuthState extends ChangeNotifier {
  AuthState() {
    api.onUnauthorized = (msg) {
      mensajeCierre = msg;
      cerrarSesion();
    };
  }

  final ApiClient api = ApiClient();
  Usuario? usuario;
  bool cargando = true;

  /// Motivo por el que se cerró la sesión de forma forzada (p. ej. cuenta suspendida).
  String? mensajeCierre;

  bool get autenticado => usuario != null;

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final json = prefs.getString('usuario');
    if (token != null && json != null) {
      api.token = token;
      usuario = Usuario.fromJson(jsonDecode(json));
      Alertas.activarSegundoPlano();
      // Refresca en segundo plano; si falla por red se conserva la sesión local.
      refrescarPerfil().catchError((_) {});
    }
    cargando = false;
    notifyListeners();
  }

  Future<void> login(String correo, String password) async {
    final res = await api.login(correo, password);
    await _guardar(res['token'] as String, Usuario.fromJson(res['usuario']));
  }

  Future<void> registro({
    required String nombre,
    required String correo,
    required String password,
    String? telefono,
  }) async {
    await api.registro(nombre: nombre, correo: correo, password: password, telefono: telefono);
  }

  /// Confirma el correo y abre la sesión cuando la cuenta puede entrar.
  /// Regresa un mensaje si queda pendiente de validación manual.
  Future<String?> verificarCorreo(String correo, String codigo) async {
    final res = await api.verificarCorreo(correo, codigo);
    if (res['pendiente'] == true) return res['mensaje'] as String;
    await _guardar(res['token'] as String, Usuario.fromJson(res['usuario']));
    return null;
  }

  Future<void> reenviarVerificacion(String correo) => api.reenviarVerificacion(correo);

  Future<void> refrescarPerfil() async {
    usuario = await api.miPerfil();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('usuario', jsonEncode(usuario!.toJson()));
    notifyListeners();
  }

  Future<void> _guardar(String token, Usuario u) async {
    api.token = token;
    usuario = u;
    mensajeCierre = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await Alertas.reiniciarHistorial();
    Alertas.activarSegundoPlano();
    await prefs.setString('usuario', jsonEncode(u.toJson()));
    notifyListeners();
  }

  Future<void> cerrarSesion() async {
    api.token = null;
    usuario = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('usuario');
    await Alertas.reiniciarHistorial();
    Alertas.desactivarSegundoPlano();
    notifyListeners();
  }
}
