import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Logo de UniRaite: una ruta en forma de "U" que va del origen (círculo)
/// al destino (cuadrado). Misma geometría que branding/marca.svg.tpl (lienzo de 1024).
class LogoUniRaite extends StatelessWidget {
  const LogoUniRaite({super.key, this.tamano = 48, this.fondo = Colors.black, this.color = Colors.white, this.radio});

  final double tamano;
  final Color fondo;
  final Color color;

  /// Radio de las esquinas del fondo; por defecto proporcional (estilo ícono de app).
  final double? radio;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(radio ?? tamano * 0.225),
      ),
      child: CustomPaint(painter: _MarcaPainter(color)),
    );
  }
}

/// Solo la marca, sin fondo.
class MarcaUniRaite extends StatelessWidget {
  const MarcaUniRaite({super.key, this.tamano = 24, this.color});
  final double tamano;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: CustomPaint(painter: _MarcaPainter(color ?? Theme.of(context).colorScheme.onSurface, sinMargen: true)),
    );
  }
}

class _MarcaPainter extends CustomPainter {
  _MarcaPainter(this.color, {this.sinMargen = false});
  final Color color;
  final bool sinMargen;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (sinMargen) {
      // Ajusta la marca (aprox. x 233–769, y 196–808) a todo el cuadro.
      final s = size.width / 640;
      canvas.scale(s);
      canvas.translate(-192, -182);
    } else {
      canvas.scale(size.width / 1024);
    }
    canvas.translate(0, 10);

    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 100;
    final ruta = Path()
      ..moveTo(330, 350)
      ..lineTo(330, 556)
      ..arcTo(Rect.fromCircle(center: const Offset(512, 556), radius: 182), math.pi, -math.pi, false)
      ..lineTo(694, 340);
    canvas.drawPath(ruta, trazo);

    canvas.drawCircle(
      const Offset(330, 282),
      76,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 42,
    );
    canvas.drawRect(const Rect.fromLTWH(619, 206, 150, 150), Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarcaPainter old) => old.color != color || old.sinMargen != sinMargen;
}
