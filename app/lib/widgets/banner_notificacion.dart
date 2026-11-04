import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../navegacion.dart';
import 'logo.dart';

OverlayEntry? _actual;

/// Muestra un aviso que baja desde arriba (estilo heads-up) dentro de la app.
void mostrarBannerNotificacion(Notificacion n, {VoidCallback? alTocar}) {
  final overlay = navegadorGlobal.currentState?.overlay;
  if (overlay == null) return;
  _actual?.remove();
  late OverlayEntry entrada;
  entrada = OverlayEntry(
    builder: (_) => _Banner(
      notificacion: n,
      alTocar: alTocar,
      alCerrar: () {
        if (_actual == entrada) _actual = null;
        if (entrada.mounted) entrada.remove();
      },
    ),
  );
  _actual = entrada;
  overlay.insert(entrada);
}

IconData iconoNotificacion(String titulo) {
  final t = titulo.toLowerCase();
  if (t.contains('ruta')) return Icons.route_rounded;
  if (t.contains('confirmado')) return Icons.check_circle_rounded;
  if (t.contains('rechaz') || t.contains('cancel')) return Icons.cancel_rounded;
  if (t.contains('solicitud')) return Icons.person_add_alt_1_rounded;
  if (t.contains('arranc')) return Icons.directions_car_rounded;
  if (t.contains('finaliz')) return Icons.flag_rounded;
  if (t.contains('cuenta')) return Icons.verified_user_rounded;
  return Icons.notifications_rounded;
}

Color colorNotificacion(String titulo) {
  final t = titulo.toLowerCase();
  if (t.contains('confirmado') || t.contains('cuenta')) {
    return const Color(0xFF05A357);
  }
  if (t.contains('rechaz') || t.contains('cancel')) {
    return const Color(0xFFE11900);
  }
  if (t.contains('ruta') || t.contains('solicitud')) {
    return const Color(0xFF276EF1);
  }
  return const Color(0xFF757575);
}

class _Banner extends StatefulWidget {
  const _Banner({
    required this.notificacion,
    required this.alCerrar,
    this.alTocar,
  });
  final Notificacion notificacion;
  final VoidCallback alCerrar;
  final VoidCallback? alTocar;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 240),
  )..forward();
  Timer? _timer;
  double _arrastre = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 5), _cerrar);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _cerrar() async {
    _timer?.cancel();
    if (!mounted) return;
    await _anim.reverse();
    widget.alCerrar();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notificacion;
    final acento = colorNotificacion(n.titulo);
    final top = MediaQuery.of(context).padding.top + 8;
    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1.4), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _anim,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeIn,
          ),
        ),
        child: GestureDetector(
          onVerticalDragUpdate: (d) => setState(
            () => _arrastre = (_arrastre + d.delta.dy).clamp(-120.0, 0.0),
          ),
          onVerticalDragEnd: (d) {
            if (_arrastre < -30 || (d.primaryVelocity ?? 0) < -300) {
              _cerrar();
            } else {
              setState(() => _arrastre = 0);
            }
          },
          onTap: () {
            _cerrar();
            widget.alTocar?.call();
          },
          child: Transform.translate(
            offset: Offset(0, _arrastre),
            child: Material(
              color: Colors.black,
              elevation: 12,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Encabezado tipo notificación del sistema: logo + nombre de la app
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, right: 4),
                      child: Row(
                        children: [
                          const LogoUniRaite(
                            tamano: 18,
                            fondo: Colors.white,
                            color: Colors.black,
                            radio: 5,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'UniRaite',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Text(
                            '  ·  ahora',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12.5,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _cerrar,
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white54,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: acento,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            iconoNotificacion(n.titulo),
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                n.titulo,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                n.mensaje,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13.5,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
