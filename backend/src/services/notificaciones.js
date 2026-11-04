const { pool } = require('../db');

async function notificar(id_usuario, titulo, mensaje, id_viaje = null, conn = pool) {
  await conn.query(
    'INSERT INTO Notificaciones (id_usuario, titulo, mensaje, id_viaje) VALUES (?, ?, ?, ?)',
    [id_usuario, titulo, mensaje, id_viaje]
  );
}

// Notifica a los usuarios con una ruta guardada que coincide con el viaje publicado.
async function notificarRutaCoincidente(viaje) {
  const [rows] = await pool.query(
    `SELECT DISTINCT r.id_usuario
       FROM Rutas_Guardadas r
       JOIN Usuarios u ON u.id_usuario = r.id_usuario AND u.estado_cuenta = 'Activo'
      WHERE r.id_usuario <> ?
        AND ? LIKE CONCAT('%', r.punto_destino, '%')
        AND (r.punto_origen IS NULL OR r.punto_origen = '' OR ? LIKE CONCAT('%', r.punto_origen, '%'))`,
    [viaje.id_chofer, viaje.punto_destino, viaje.punto_origen]
  );
  const hora = viaje.fecha_hora_salida.slice(11, 16);
  for (const { id_usuario } of rows) {
    await notificar(
      id_usuario,
      'Nuevo viaje en tu ruta',
      `${viaje.punto_origen} → ${viaje.punto_destino} a las ${hora}. ¡Reserva antes de que se llene!`,
      viaje.id_viaje
    );
  }
  return rows.length;
}

module.exports = { notificar, notificarRutaCoincidente };
