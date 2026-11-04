const router = require('express').Router();
const { pool, withTransaction } = require('../db');
const { HttpError, asyncHandler } = require('../errors');
const { notificar } = require('../services/notificaciones');

// Mis reservas como pasajero.
router.get('/mias', asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    `SELECT s.id_solicitud, s.estado_solicitud, s.fecha_solicitud,
            v.id_viaje, v.punto_origen, v.punto_destino, v.fecha_hora_salida, v.estado_viaje,
            v.asientos_disponibles, u.nombre_completo AS chofer_nombre,
            u.calificacion_promedio AS chofer_calificacion, u.foto_url AS chofer_foto, ve.modelo_color, ve.placas
       FROM Solicitudes_Asiento s
       JOIN Viajes v     ON v.id_viaje = s.id_viaje
       JOIN Usuarios u   ON u.id_usuario = v.id_chofer
       JOIN Vehiculos ve ON ve.id_vehiculo = v.id_vehiculo
      WHERE s.id_pasajero = ?
      ORDER BY (v.estado_viaje IN ('Programado','En Curso')) DESC, v.fecha_hora_salida DESC`,
    [req.user.id_usuario]
  );
  res.json(rows);
}));

// El chofer acepta/rechaza; el pasajero cancela.
// La aceptación ocurre en una transacción con la fila del viaje bloqueada, y el trigger
// trg_solicitudes_before_update rechaza el cambio si ya no quedan asientos (overbooking).
router.patch('/:id', asyncHandler(async (req, res) => {
  const yo = req.user.id_usuario;
  const nuevo = req.body.estado;
  if (!['Aceptada', 'Rechazada', 'Cancelada'].includes(nuevo)) throw new HttpError(400, 'Estado inválido');

  const resultado = await withTransaction(async (conn) => {
    const [[s]] = await conn.query('SELECT * FROM Solicitudes_Asiento WHERE id_solicitud = ?', [req.params.id]);
    if (!s) throw new HttpError(404, 'Solicitud no encontrada');
    const [[v]] = await conn.query('SELECT * FROM Viajes WHERE id_viaje = ? FOR UPDATE', [s.id_viaje]);

    if (nuevo === 'Cancelada') {
      if (s.id_pasajero !== yo) throw new HttpError(403, 'Solo el pasajero puede cancelar su solicitud');
      if (!['Pendiente', 'Aceptada'].includes(s.estado_solicitud)) throw new HttpError(409, 'La solicitud ya no está activa');
      if (v.estado_viaje !== 'Programado') throw new HttpError(409, 'El viaje ya inició o terminó');
    } else {
      if (v.id_chofer !== yo) throw new HttpError(403, 'Solo el chofer puede responder solicitudes');
      if (v.estado_viaje !== 'Programado') throw new HttpError(409, 'El viaje ya no está programado');
      if (s.estado_solicitud !== 'Pendiente') throw new HttpError(409, 'La solicitud ya fue respondida');
    }

    await conn.query('UPDATE Solicitudes_Asiento SET estado_solicitud = ? WHERE id_solicitud = ?', [nuevo, s.id_solicitud]);

    if (nuevo === 'Cancelada') {
      if (s.estado_solicitud === 'Aceptada') {
        await notificar(v.id_chofer, 'Un pasajero canceló',
          `${req.user.nombre_completo} liberó su asiento en el viaje a ${v.punto_destino}.`, v.id_viaje, conn);
      }
    } else {
      await notificar(s.id_pasajero,
        nuevo === 'Aceptada' ? '¡Asiento confirmado!' : 'Solicitud rechazada',
        nuevo === 'Aceptada'
          ? `Tienes lugar en el viaje a ${v.punto_destino} (${String(v.fecha_hora_salida).slice(11, 16)}).`
          : `El chofer no pudo aceptarte en el viaje a ${v.punto_destino}.`,
        v.id_viaje, conn);
    }

    const [[act]] = await conn.query('SELECT asientos_disponibles FROM Viajes WHERE id_viaje = ?', [v.id_viaje]);
    return { id_solicitud: s.id_solicitud, estado_solicitud: nuevo, asientos_disponibles: act.asientos_disponibles };
  });
  res.json(resultado);
}));

module.exports = router;
