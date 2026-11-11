// Modelos que reflejan las tablas de MySQL expuestas por la API.

int _int(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
int? _intOrNull(dynamic v) => v == null ? null : _int(v);
double _double(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
DateTime _fecha(dynamic v) => DateTime.tryParse('$v') ?? DateTime.now();

class Usuario {
  Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    this.telefono,
    this.fotoUrl,
    required this.calificacion,
    required this.estadoCuenta,
    required this.rol,
    this.viajesComoChofer = 0,
    this.viajesComoPasajero = 0,
    this.totalResenas = 0,
  });

  final int id;
  final String nombre;
  final String correo;
  final String? telefono;
  final String? fotoUrl;
  final double calificacion;
  final String estadoCuenta; // Activo | Suspendido | Pendiente
  final String rol; // Usuario | Administrador
  final int viajesComoChofer;
  final int viajesComoPasajero;
  final int totalResenas;

  bool get esAdmin => rol == 'Administrador';

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: _int(j['id_usuario']),
        nombre: j['nombre_completo'] ?? '',
        correo: j['correo_institucional'] ?? '',
        telefono: j['telefono'],
        fotoUrl: j['foto_url'],
        calificacion: _double(j['calificacion_promedio']),
        estadoCuenta: j['estado_cuenta'] ?? 'Activo',
        rol: j['rol'] ?? 'Usuario',
        viajesComoChofer: _int(j['viajes_como_chofer']),
        viajesComoPasajero: _int(j['viajes_como_pasajero']),
        totalResenas: _int(j['total_resenas']),
      );

  Map<String, dynamic> toJson() => {
        'id_usuario': id,
        'nombre_completo': nombre,
        'correo_institucional': correo,
        'telefono': telefono,
        'foto_url': fotoUrl,
        'calificacion_promedio': calificacion,
        'estado_cuenta': estadoCuenta,
        'rol': rol,
      };
}

class Vehiculo {
  Vehiculo({required this.id, required this.placas, required this.modeloColor, required this.capacidad});

  final int id;
  final String placas;
  final String modeloColor;
  final int capacidad;

  factory Vehiculo.fromJson(Map<String, dynamic> j) => Vehiculo(
        id: _int(j['id_vehiculo']),
        placas: j['placas'] ?? '',
        modeloColor: j['modelo_color'] ?? '',
        capacidad: _int(j['capacidad_maxima']),
      );
}

class Solicitud {
  Solicitud({
    required this.id,
    required this.idPasajero,
    required this.estado,
    required this.pasajeroNombre,
    required this.pasajeroCalificacion,
    this.pasajeroTotalResenas = 0,
    this.pasajeroTelefono,
    this.pasajeroFoto,
  });

  final int id;
  final int idPasajero;
  final String estado; // Pendiente | Aceptada | Rechazada | Cancelada
  final String pasajeroNombre;
  final double pasajeroCalificacion;
  final int pasajeroTotalResenas;
  final String? pasajeroTelefono;
  final String? pasajeroFoto;

  factory Solicitud.fromJson(Map<String, dynamic> j) => Solicitud(
        id: _int(j['id_solicitud']),
        idPasajero: _int(j['id_pasajero']),
        estado: j['estado_solicitud'] ?? 'Pendiente',
        pasajeroNombre: j['pasajero_nombre'] ?? '',
        pasajeroCalificacion: _double(j['pasajero_calificacion']),
        pasajeroTotalResenas: _int(j['pasajero_total_resenas']),
        pasajeroTelefono: j['pasajero_telefono'],
        pasajeroFoto: j['pasajero_foto'],
      );
}

class Participante {
  Participante(this.id, this.nombre, [this.fotoUrl]);
  final int id;
  final String nombre;
  final String? fotoUrl;
}

class Viaje {
  Viaje({
    required this.id,
    required this.idChofer,
    required this.idVehiculo,
    required this.origen,
    required this.destino,
    required this.salida,
    required this.asientosDisponibles,
    required this.estado,
    this.notas,
    this.choferNombre,
    this.choferCalificacion,
    this.choferTotalResenas = 0,
    this.choferTelefono,
    this.choferFoto,
    this.modeloColor,
    this.placas,
    this.capacidad,
    this.esMio = false,
    this.solicitudesPendientes = 0,
    this.miSolicitudId,
    this.miSolicitudEstado,
    this.solicitudes = const [],
    this.porCalificar = const [],
    this.notificados,
  });

  final int id;
  final int idChofer;
  final int idVehiculo;
  final String origen;
  final String destino;
  final DateTime salida;
  final int asientosDisponibles;
  final String estado; // Programado | En Curso | Finalizado | Cancelado
  final String? notas;
  final String? choferNombre;
  final double? choferCalificacion;
  final int choferTotalResenas;
  final String? choferTelefono;
  final String? choferFoto;
  final String? modeloColor;
  final String? placas;
  final int? capacidad;
  final bool esMio;
  final int solicitudesPendientes;
  final int? miSolicitudId;
  final String? miSolicitudEstado;
  final List<Solicitud> solicitudes;
  final List<Participante> porCalificar;
  final int? notificados;

  factory Viaje.fromJson(Map<String, dynamic> j) {
    final mia = j['mi_solicitud'] as Map<String, dynamic>?;
    return Viaje(
      id: _int(j['id_viaje']),
      idChofer: _int(j['id_chofer']),
      idVehiculo: _int(j['id_vehiculo']),
      origen: j['punto_origen'] ?? '',
      destino: j['punto_destino'] ?? '',
      salida: _fecha(j['fecha_hora_salida']),
      asientosDisponibles: _int(j['asientos_disponibles']),
      estado: j['estado_viaje'] ?? 'Programado',
      notas: j['notas'],
      choferNombre: j['chofer_nombre'],
      choferCalificacion: j['chofer_calificacion'] == null ? null : _double(j['chofer_calificacion']),
      choferTotalResenas: _int(j['chofer_total_resenas']),
      choferTelefono: j['chofer_telefono'],
      choferFoto: j['chofer_foto'],
      modeloColor: j['modelo_color'],
      placas: j['placas'],
      capacidad: _intOrNull(j['capacidad_maxima']),
      esMio: j['es_mio'] == true,
      solicitudesPendientes: _int(j['solicitudes_pendientes']),
      miSolicitudId: _intOrNull(mia?['id_solicitud']),
      miSolicitudEstado: mia?['estado_solicitud'],
      solicitudes: ((j['solicitudes'] as List?) ?? []).map((e) => Solicitud.fromJson(e)).toList(),
      porCalificar: ((j['por_calificar'] as List?) ?? [])
          .map((e) => Participante(_int(e['id_usuario']), e['nombre_completo'] ?? '', e['foto_url']))
          .toList(),
      notificados: _intOrNull(j['notificados']),
    );
  }
}

class Reserva {
  Reserva({
    required this.idSolicitud,
    required this.estado,
    required this.idViaje,
    required this.origen,
    required this.destino,
    required this.salida,
    required this.estadoViaje,
    required this.choferNombre,
    required this.choferCalificacion,
    this.choferTotalResenas = 0,
    this.choferFoto,
    required this.modeloColor,
    required this.placas,
  });

  final int idSolicitud;
  final String estado;
  final int idViaje;
  final String origen;
  final String destino;
  final DateTime salida;
  final String estadoViaje;
  final String choferNombre;
  final double choferCalificacion;
  final int choferTotalResenas;
  final String? choferFoto;
  final String modeloColor;
  final String placas;

  factory Reserva.fromJson(Map<String, dynamic> j) => Reserva(
        idSolicitud: _int(j['id_solicitud']),
        estado: j['estado_solicitud'] ?? '',
        idViaje: _int(j['id_viaje']),
        origen: j['punto_origen'] ?? '',
        destino: j['punto_destino'] ?? '',
        salida: _fecha(j['fecha_hora_salida']),
        estadoViaje: j['estado_viaje'] ?? '',
        choferNombre: j['chofer_nombre'] ?? '',
        choferCalificacion: _double(j['chofer_calificacion']),
        choferTotalResenas: _int(j['chofer_total_resenas']),
        choferFoto: j['chofer_foto'],
        modeloColor: j['modelo_color'] ?? '',
        placas: j['placas'] ?? '',
      );
}

class RutaGuardada {
  RutaGuardada({required this.id, this.origen, required this.destino});
  final int id;
  final String? origen;
  final String destino;

  factory RutaGuardada.fromJson(Map<String, dynamic> j) =>
      RutaGuardada(id: _int(j['id_ruta']), origen: j['punto_origen'], destino: j['punto_destino'] ?? '');
}

class UbicacionChofer {
  UbicacionChofer({required this.latitud, required this.longitud, this.rumbo, required this.haceSegundos});
  final double latitud;
  final double longitud;
  final double? rumbo;
  final int haceSegundos;

  factory UbicacionChofer.fromJson(Map<String, dynamic> j) => UbicacionChofer(
        latitud: _double(j['latitud']),
        longitud: _double(j['longitud']),
        rumbo: j['rumbo'] == null ? null : _double(j['rumbo']),
        haceSegundos: _int(j['hace_segundos']),
      );
}

class Notificacion {
  Notificacion({
    required this.id,
    required this.titulo,
    required this.mensaje,
    this.idViaje,
    required this.leida,
    required this.fecha,
  });

  final int id;
  final String titulo;
  final String mensaje;
  final int? idViaje;
  final bool leida;
  final DateTime fecha;

  factory Notificacion.fromJson(Map<String, dynamic> j) => Notificacion(
        id: _int(j['id_notificacion']),
        titulo: j['titulo'] ?? '',
        mensaje: j['mensaje'] ?? '',
        idViaje: _intOrNull(j['id_viaje']),
        leida: j['leida'] == true,
        fecha: _fecha(j['fecha']),
      );
}
