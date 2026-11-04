import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../models/models.dart';
import '../theme.dart';

final _fmtFechaHora = DateFormat("EEE d MMM · HH:mm", 'es_MX');
final _fmtHora = DateFormat('HH:mm', 'es_MX');
final _fmtDia = DateFormat("EEE d MMM", 'es_MX');

String fechaHora(DateTime d) => _fmtFechaHora.format(d);
String hora(DateTime d) => _fmtHora.format(d);

/// "Hoy", "Mañana" o la fecha corta.
String diaRelativo(DateTime d) {
  final hoy = DateTime.now();
  final a = DateTime(hoy.year, hoy.month, hoy.day);
  final b = DateTime(d.year, d.month, d.day);
  final dif = b.difference(a).inDays;
  if (dif == 0) return 'Hoy';
  if (dif == 1) return 'Mañana';
  if (dif == -1) return 'Ayer';
  final s = _fmtDia.format(d);
  return s[0].toUpperCase() + s.substring(1);
}

/// "en 25 min", "en 2 h" para viajes próximos.
String? faltaPara(DateTime d) {
  final min = d.difference(DateTime.now()).inMinutes;
  if (min < 0 || min > 24 * 60) return null;
  if (min < 1) return 'saliendo';
  if (min < 60) return 'en $min min';
  return 'en ${(min / 60).floor()} h';
}

void mostrarMensaje(BuildContext context, String texto, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: error ? const Color(0xFFFF8A75) : const Color(0xFF6FD39E), size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(texto)),
      ]),
    ));
}

/// Ejecuta una acción mostrando el error de la API como SnackBar.
Future<bool> intentar(BuildContext context, Future<void> Function() accion, {String? exito}) async {
  try {
    await accion();
    if (exito != null && context.mounted) mostrarMensaje(context, exito);
    return true;
  } catch (e) {
    if (context.mounted) mostrarMensaje(context, e.toString(), error: true);
    return false;
  }
}

/// Confirmación como hoja inferior (estilo Uber).
Future<bool> confirmar(BuildContext context, String titulo, String mensaje,
    {String accion = 'Confirmar', bool destructivo = false}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(titulo, style: Theme.of(c).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(mensaje, style: Theme.of(c).textTheme.bodyLarge?.copyWith(color: Theme.of(c).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          FilledButton(
            style: destructivo ? FilledButton.styleFrom(backgroundColor: Paleta.rojo, foregroundColor: Colors.white) : null,
            onPressed: () => Navigator.pop(c, true),
            child: Text(accion),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('Volver')),
        ]),
      ),
    ),
  );
  return r ?? false;
}

class Calificacion extends StatelessWidget {
  const Calificacion(this.valor, {super.key, this.tamano = 14});
  final double valor;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.star_rounded, size: tamano + 2, color: Theme.of(context).colorScheme.onSurface),
      const SizedBox(width: 2),
      Text(valor.toStringAsFixed(1), style: TextStyle(fontSize: tamano, fontWeight: FontWeight.w600)),
    ]);
  }
}

/// Avatar circular: foto de perfil si existe; si no, la inicial del nombre.
class Avatar extends StatelessWidget {
  const Avatar(this.nombre, {super.key, this.radio = 20, this.fotoUrl});
  final String nombre;
  final double radio;
  final String? fotoUrl;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final inicial = Text(
      nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase(),
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: radio * 0.85, color: esquema.onSurface),
    );
    final url = urlRecurso(fotoUrl);
    return Container(
      width: radio * 2,
      height: radio * 2,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: esquema.surfaceContainerHigh, shape: BoxShape.circle),
      child: url == null
          ? inicial
          : Image.network(
              url,
              width: radio * 2,
              height: radio * 2,
              fit: BoxFit.cover,
              cacheWidth: (radio * 2 * MediaQuery.devicePixelRatioOf(context)).round(),
              errorBuilder: (_, _, _) => inicial,
              loadingBuilder: (_, hijo, progreso) => progreso == null ? hijo : inicial,
            ),
    );
  }
}

class EstadoChip extends StatelessWidget {
  const EstadoChip(this.estado, {super.key});
  final String estado;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final (Color fondo, Color texto, IconData icono) = switch (estado) {
      'Programado' => (esquema.surfaceContainerHigh, esquema.onSurface, Icons.schedule_rounded),
      'Pendiente' => (const Color(0xFFFFF4DB), const Color(0xFF7A5300), Icons.hourglass_top_rounded),
      'En Curso' => (esquema.secondaryContainer, esquema.onSecondaryContainer, Icons.navigation_rounded),
      'Aceptada' || 'Activo' => (esquema.tertiaryContainer, esquema.onTertiaryContainer, Icons.check_rounded),
      'Finalizado' => (esquema.surfaceContainerHigh, esquema.onSurfaceVariant, Icons.flag_rounded),
      _ => (esquema.errorContainer, esquema.onErrorContainer, Icons.close_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 14, color: texto),
        const SizedBox(width: 4),
        Text(estado, style: TextStyle(color: texto, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Origen → destino: círculo + línea + cuadrado, como en Uber.
class RutaVisual extends StatelessWidget {
  const RutaVisual({super.key, required this.origen, required this.destino, this.grande = false});
  final String origen;
  final String destino;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final estilo = (grande ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyLarge)
        ?.copyWith(fontWeight: FontWeight.w600);
    final separacion = grande ? 22.0 : 14.0;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: esquema.onSurface, width: 2.5)),
          ),
          Container(width: 2, height: separacion + 8, color: esquema.onSurface),
          Container(width: 9, height: 9, color: esquema.onSurface),
        ]),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(origen, style: estilo, maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: separacion),
          Text(destino, style: estilo, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]);
  }
}

class TarjetaViaje extends StatelessWidget {
  const TarjetaViaje({super.key, required this.viaje, this.onTap, this.pie});
  final Viaje viaje;
  final VoidCallback? onTap;
  final Widget? pie;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final falta = viaje.estado == 'Programado' ? faltaPara(viaje.salida) : null;
    final lleno = viaje.asientosDisponibles == 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(hora(viaje.salida), style: tema.textTheme.headlineMedium),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(diaRelativo(viaje.salida),
                    style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant, fontWeight: FontWeight.w500)),
              ),
              const Spacer(),
              if (falta != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: esquema.primary, borderRadius: BorderRadius.circular(20)),
                  child: Text(falta,
                      style: TextStyle(color: esquema.onPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                )
              else
                EstadoChip(viaje.estado),
            ]),
            const SizedBox(height: 16),
            RutaVisual(origen: viaje.origen, destino: viaje.destino),
            const SizedBox(height: 16),
            Row(children: [
              if (viaje.choferNombre != null) ...[
                Avatar(viaje.choferNombre!, radio: 16, fotoUrl: viaje.choferFoto),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(viaje.choferNombre!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (viaje.modeloColor != null)
                      Text(viaje.modeloColor!, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.bodySmall?.copyWith(color: esquema.onSurfaceVariant)),
                  ]),
                ),
                const SizedBox(width: 8),
                if (viaje.choferCalificacion != null) Calificacion(viaje.choferCalificacion!, tamano: 13),
              ] else if (viaje.modeloColor != null)
                Flexible(
                  child: Row(children: [
                    const Icon(Icons.directions_car_rounded, size: 18),
                    const SizedBox(width: 6),
                    Flexible(child: Text(viaje.modeloColor!, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: lleno ? esquema.errorContainer : esquema.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_rounded, size: 16, color: lleno ? esquema.onErrorContainer : esquema.onSurface),
                  const SizedBox(width: 3),
                  Text(lleno ? 'Lleno' : '${viaje.asientosDisponibles}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: lleno ? esquema.onErrorContainer : esquema.onSurface)),
                ]),
              ),
            ]),
            if (pie != null) ...[const SizedBox(height: 12), pie!],
          ]),
        ),
      ),
    );
  }
}

/// Encabezado de sección en negritas.
class Seccion extends StatelessWidget {
  const Seccion(this.titulo, {super.key, this.accion});
  final String titulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 6),
      child: Row(children: [
        Expanded(child: Text(titulo, style: Theme.of(context).textTheme.titleLarge)),
        ?accion,
      ]),
    );
  }
}

class Vacio extends StatelessWidget {
  const Vacio({super.key, required this.icono, required this.titulo, this.mensaje, this.accion});
  final IconData icono;
  final String titulo;
  final String? mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: tema.colorScheme.surfaceContainerHigh, shape: BoxShape.circle),
            child: Icon(icono, size: 44, color: tema.colorScheme.onSurface),
          ),
        ),
        const SizedBox(height: 20),
        Text(titulo, textAlign: TextAlign.center, style: tema.textTheme.titleLarge),
        if (mensaje != null) ...[
          const SizedBox(height: 8),
          Text(mensaje!,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
        ],
        if (accion != null) ...[const SizedBox(height: 24), Center(child: accion!)],
      ],
    );
  }
}

/// Carga asíncrona con pull-to-refresh y manejo de error.
class Cargador<T> extends StatefulWidget {
  const Cargador({super.key, required this.cargar, required this.builder});
  final Future<T> Function() cargar;
  final Widget Function(BuildContext context, T datos, Future<void> Function() recargar) builder;

  @override
  State<Cargador<T>> createState() => CargadorState<T>();
}

class CargadorState<T> extends State<Cargador<T>> {
  late Future<T> _futuro = widget.cargar();
  T? _ultimo;

  Future<void> recargar() async {
    final f = widget.cargar();
    setState(() => _futuro = f);
    try {
      await f;
    } catch (_) {
      // El FutureBuilder muestra el error.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.hasData) _ultimo = snap.data;
        // Mientras recarga, conserva lo anterior para evitar parpadeos.
        if (snap.connectionState != ConnectionState.done && _ultimo == null) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 3));
        }
        if (snap.hasError && snap.connectionState == ConnectionState.done) {
          return RefreshIndicator(
            onRefresh: recargar,
            child: Vacio(
              icono: Icons.wifi_off_rounded,
              titulo: 'Algo salió mal',
              mensaje: snap.error.toString(),
              accion: SizedBox(
                width: 200,
                child: FilledButton.icon(
                  onPressed: recargar,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ),
            ),
          );
        }
        return RefreshIndicator(
          color: Theme.of(context).colorScheme.onSurface,
          onRefresh: recargar,
          child: widget.builder(context, (snap.data ?? _ultimo) as T, recargar),
        );
      },
    );
  }
}

/// Abre una pantalla y recarga la lista al regresar.
Future<void> abrirYRecargar(BuildContext context, Widget pantalla, Future<void> Function() recargar) async {
  await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  await recargar();
}
