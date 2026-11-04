import 'package:flutter/material.dart';

/// Llave global del Navigator: permite abrir pantallas y mostrar avisos
/// desde servicios (p. ej. al tocar una notificación del sistema).
final GlobalKey<NavigatorState> navegadorGlobal = GlobalKey<NavigatorState>();
