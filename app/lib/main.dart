import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'navegacion.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/viaje_detalle_screen.dart';
import 'services/alertas.dart';
import 'state/auth_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  Intl.defaultLocale = 'es_MX';
  await cargarServidor();
  if (!kIsWeb) SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Al tocar una notificación del sistema, abre el viaje correspondiente.
  Alertas.alTocar = (idViaje) {
    if (idViaje == null) return;
    navegadorGlobal.currentState?.push(
      MaterialPageRoute(builder: (_) => ViajeDetalleScreen(idViaje: idViaje)),
    );
  };
  await Alertas.inicializar();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthState()..cargar(),
      child: const UniRaiteApp(),
    ),
  );
}

class UniRaiteApp extends StatelessWidget {
  const UniRaiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniRaite',
      navigatorKey: navegadorGlobal,
      debugShowCheckedModeBanner: false,
      theme: temaUniRaite(Brightness.light),
      darkTheme: temaUniRaite(Brightness.dark),
      home: Consumer<AuthState>(
        builder: (context, auth, _) {
          if (auth.cargando) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return auth.autenticado ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}
