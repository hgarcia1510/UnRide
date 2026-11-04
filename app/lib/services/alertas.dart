import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models/models.dart';

const _kToken = 'token';
const _kUltimaId = 'ultima_notificacion_id';
const _tareaFondo = 'uniraite_revisar_notificaciones';

bool get _esAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool get _esIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Notificaciones con sonido: del sistema (Android / iOS / navegador) y dentro de la app.
class Alertas {
  Alertas._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static final AudioPlayer _reproductor = AudioPlayer();
  static bool _inicializado = false;

  /// Se invoca al tocar una notificación del sistema (payload = id del viaje).
  static void Function(int? idViaje)? alTocar;

  static const _android = AndroidNotificationDetails(
    'uniraite_viajes_v2',
    'Viajes y reservas',
    channelDescription: 'Nuevos viajes en tus rutas, solicitudes y confirmaciones',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('alerta'),
    enableVibration: true,
    category: AndroidNotificationCategory.message,
    visibility: NotificationVisibility.public,
    icon: 'ic_notificacion',
    largeIcon: DrawableResourceAndroidBitmap('ic_logo_notificacion'),
    color: Color(0xFF000000),
    styleInformation: BigTextStyleInformation(''),
  );

  static Future<void> inicializar() async {
    if (_inicializado) return;
    _inicializado = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notificacion'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          web: WebInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (r) => alTocar?.call(int.tryParse(r.payload ?? '')),
      );
      final lanzamiento = await _plugin.getNotificationAppLaunchDetails();
      if (lanzamiento?.didNotificationLaunchApp == true) {
        final payload = lanzamiento!.notificationResponse?.payload;
        Future.delayed(const Duration(milliseconds: 800), () => alTocar?.call(int.tryParse(payload ?? '')));
      }
    } catch (e) {
      debugPrint('Notificaciones no disponibles: $e');
    }
    try {
      await _reproductor.setReleaseMode(ReleaseMode.stop);
      await _reproductor.setSource(AssetSource('sonidos/alerta.wav'));
    } catch (_) {}
  }

  /// ¿El usuario ya dio permiso de notificaciones del sistema?
  static Future<bool> permisoConcedido() async {
    try {
      if (kIsWeb) {
        return _plugin
                .resolvePlatformSpecificImplementation<WebFlutterLocalNotificationsPlugin>()
                ?.permissionStatus ==
            WebNotificationPermission.granted;
      }
      if (_esAndroid) {
        return await _plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.areNotificationsEnabled() ??
            false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// En web/iPhone debe llamarse desde un toque del usuario.
  static Future<bool> pedirPermiso() async {
    try {
      if (kIsWeb) {
        return await _plugin
                .resolvePlatformSpecificImplementation<WebFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      if (_esAndroid) {
        return await _plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      if (_esIOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
    } catch (_) {}
    return false;
  }

  /// Notificación del sistema (con sonido y vibración).
  static Future<void> notificacionSistema(Notificacion n) async {
    try {
      await _plugin.show(
        id: n.id,
        title: n.titulo,
        body: n.mensaje,
        payload: n.idViaje?.toString(),
        notificationDetails: NotificationDetails(
          android: _android,
          iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBanner: true),
          web: WebNotificationDetails(renotify: true, iconUrl: Uri.parse('icons/Icon-192.png')),
        ),
      );
    } catch (e) {
      debugPrint('No se pudo mostrar la notificación: $e');
    }
  }

  /// Sonido + vibración para avisos dentro de la app.
  static Future<void> sonar() async {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 180), HapticFeedback.mediumImpact);
    try {
      await _reproductor.stop();
      await _reproductor.play(AssetSource('sonidos/alerta.wav'), volume: 1);
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  // ------------------------------------------------------------------
  // Revisión de notificaciones nuevas (primer plano y segundo plano)
  // ------------------------------------------------------------------

  /// Consulta la bandeja y regresa las notificaciones no leídas que aún no se avisaron.
  static Future<List<Notificacion>> nuevasDesdeServidor(ApiClient api) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final ultimaId = prefs.getInt(_kUltimaId);
    final lista = await api.notificaciones();
    if (lista.isEmpty) return [];

    final maxId = lista.map((n) => n.id).reduce((a, b) => a > b ? a : b);
    // Primera vez en este dispositivo: no se avisa del historial antiguo.
    if (ultimaId == null) {
      await prefs.setInt(_kUltimaId, maxId);
      return [];
    }
    final nuevas = lista.where((n) => n.id > ultimaId && !n.leida).toList()..sort((a, b) => a.id.compareTo(b.id));
    if (maxId > ultimaId) await prefs.setInt(_kUltimaId, maxId);
    return nuevas;
  }

  static Future<void> reiniciarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUltimaId);
  }

  /// Android: revisa cada ~15 min aunque la app esté cerrada.
  static Future<void> activarSegundoPlano() async {
    if (!_esAndroid) return;
    try {
      await Workmanager().initialize(revisarEnSegundoPlano);
      await Workmanager().registerPeriodicTask(
        _tareaFondo,
        _tareaFondo,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (e) {
      debugPrint('No se pudo programar la revisión en segundo plano: $e');
    }
  }

  static Future<void> desactivarSegundoPlano() async {
    if (!_esAndroid) return;
    try {
      await Workmanager().cancelAll();
    } catch (_) {}
  }
}

/// Punto de entrada del proceso en segundo plano (Android WorkManager).
@pragma('vm:entry-point')
void revisarEnSegundoPlano() {
  Workmanager().executeTask((tarea, datos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final token = prefs.getString(_kToken);
      if (token == null) return true;

      await cargarServidor();
      await Alertas.inicializar();
      final api = ApiClient()..token = token;
      final nuevas = await Alertas.nuevasDesdeServidor(api);
      for (final n in nuevas.take(5)) {
        await Alertas.notificacionSistema(n);
      }
    } catch (_) {
      // Sin red o sesión vencida: se reintenta en el siguiente ciclo.
    }
    return true;
  });
}
