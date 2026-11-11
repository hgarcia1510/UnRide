const router = require('express').Router();
const { pool, withTransaction } = require('../db');
const { HttpError, asyncHandler } = require('../errors');
const { requireFields, normalizarFecha, toInt } = require('../validators');
const { notificar, notificarRutaCoincidente } = require('../services/notificaciones');

const SELECT_VIAJE = `
  SELECT v.*, u.nombre_completo AS chofer_nombre, u.calificacion_promedio AS chofer_calificacion, u.foto_url AS chofer_foto,
         (SELECT COUNT(*) FROM Resenas r WHERE r.id_evaluado = u.id_usuario) AS chofer_total_resenas,
         ve.modelo_color, ve.placas, ve.capacidad_maxima
    FROM Viajes v
    JOIN Usuarios  u  ON u.id_usuario   = v.id_chofer
    JOIN Vehiculos ve ON ve.id_vehiculo = v.id_vehiculo`;

// Buscar viajes activos (Programados, a futuro y con asientos).
router.get('/', asyncHandler(async (req, res) => {
  const where = [`v.estado_viaje = 'Programado'`, 'v.fecha_hora_salida >= NOW()', 'v.asientos_disponibles > 0'];
  const params = [];
  if (req.query.destino) { where.push('v.punto_destino LIKE ?'); params.push(`%${req.query.destino}%`); }
  if (req.query.origen)  { where.push('v.punto_origen LIKE ?');  params.push(`%${req.query.origen}%`); }
  if (req.query.fecha)   { where.push('DATE(v.fecha_hora_salida) = ?'); params.push(req.query.fecha); }

  const [rows] = await pool.query(
    `${SELECT_VIAJE}
     WHERE ${where.join(' AND ')}
     ORDER BY v.fecha_hora_salida ASC LIMIT 100`,
    params
  );
  res.json(rows.map((v) => ({ ...v, es_mio: v.id_chofer === req.user.id_usuario })));
}));

// Viajes que yo publiqué como chofer.
router.get('/mios', asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    `SELECT v.*, ve.modelo_color, ve.placas, ve.capacidad_maxima,
            (SELECT COUNT(*) FROM Solicitudes_Asiento s
              WHERE s.id_viaje = v.id_viaje AND s.estado_solicitud = 'Pendiente') AS solicitudes_pendientes
       FROM Viajes v JOIN Vehiculos ve ON ve.id_vehiculo = v.id_vehiculo
      WHERE v.id_chofer = ?
      ORDER BY (v.estado_viaje IN ('Programado','En Curso')) DESC, v.fecha_hora_salida DESC`,
    [req.user.id_usuario]
  );
  res.json(rows);
}));

router.get('/:id', asyncHandler(async (req, res) => {
  const yo = req.user.id_usuario;
  const [rows] = await pool.query(`${SELECT_VIAJE} WHERE v.id_viaje = ?`, [req.params.id]);
  const viaje = rows[0];
  if (!viaje) throw new HttpError(404, 'Viaje no encontrado');

  const esChofer = viaje.id_chofer === yo;
  const [[mia]] = await pool.query(
    'SELECT id_solicitud, estado_solicitud FROM Solicitudes_Asiento WHERE id_viaje = ? AND id_pasajero = ?',
    [viaje.id_viaje, yo]
  );
  const esPasajeroAceptado = mia?.estado_solicitud === 'Aceptada';

  // Solo el chofer ve todas las solicitudes; los pasajeros aceptados ven a sus compañeros.
  let solicitudes = [];
  if (esChofer || esPasajeroAceptado) {
    [solicitudes] = await pool.query(
      `SELECT s.id_solicitud, s.id_pasajero, s.estado_solicitud, s.fecha_solicitud,
              u.nombre_completo AS pasajero_nombre, u.calificacion_promedio AS pasajero_calificacion, u.foto_url AS pasajero_foto,
              ${esChofer ? "CASE WHEN s.estado_solicitud = 'Aceptada' THEN u.telefono ELSE NULL END" : 'NULL'} AS pasajero_telefono,
              (SELECT COUNT(*) FROM Resenas r WHERE r.id_evaluado = u.id_usuario) AS pasajero_total_resenas
         FROM Solicitudes_Asiento s JOIN Usuarios u ON u.id_usuario = s.id_pasajero
        WHERE s.id_viaje = ? ${esChofer ? '' : "AND s.estado_solicitud = 'Aceptada'"}
        ORDER BY FIELD(s.estado_solicitud, 'Pendiente','Aceptada','Rechazada','Cancelada'), s.fecha_solicitud`,
      [viaje.id_viaje]
    );
  }

  // El teléfono del chofer solo se comparte con pasajeros aceptados.
  let chofer_telefono = null;
  if (esPasajeroAceptado) {
    const [[c]] = await pool.query('SELECT telefono FROM Usuarios WHERE id_usuario = ?', [viaje.id_chofer]);
    chofer_telefono = c.telefono;
  }

  // Personas que puedo calificar si el viaje terminó.
  let por_calificar = [];
  if (viaje.estado_viaje === 'Finalizado' && (esChofer || esPasajeroAceptado)) {
    [por_calificar] = await pool.query(
      `SELECT p.id_usuario, p.nombre_completo, p.foto_url FROM (
          SELECT id_chofer AS id_usuario FROM Viajes WHERE id_viaje = ?
          UNION
          SELECT id_pasajero FROM Solicitudes_Asiento WHERE id_viaje = ? AND estado_solicitud = 'Aceptada'
       ) x
       JOIN Usuarios p ON p.id_usuario = x.id_usuario
       WHERE x.id_usuario <> ?
         AND NOT EXISTS (SELECT 1 FROM Resenas r
                          WHERE r.id_viaje = ? AND r.id_autor = ? AND r.id_evaluado = x.id_usuario)
         ${esChofer ? '' : 'AND x.id_usuario = ' + Number(viaje.id_chofer)}`,
      [viaje.id_viaje, viaje.id_viaje, yo, viaje.id_viaje, yo]
    );
  }

  res.json({ ...viaje, es_mio: esChofer, chofer_telefono, mi_solicitud: mia || null, solicitudes, por_calificar });
}));

// Publicar un viaje (el usuario actúa como Chofer).
router.post('/', asyncHandler(async (req, res) => {
  requireFields(req.body, ['id_vehiculo', 'punto_origen', 'punto_destino', 'fecha_hora_salida']);
  const yo = req.user.id_usuario;
  const id_vehiculo = toInt(req.body.id_vehiculo, 'id_vehiculo');
  const origen = String(req.body.punto_origen).trim();
  const destino = String(req.body.punto_destino).trim();
  const salida = normalizarFecha(req.body.fecha_hora_salida);
  if (salida.date.getTime() < Date.now() - 60_000) throw new HttpError(400, 'La salida debe ser en el futuro');
  if (origen.length > 150 || destino.length > 150) throw new HttpError(400, 'Origen/destino demasiado largo');

  const [[veh]] = await pool.query(
    'SELECT capacidad_maxima FROM Vehiculos WHERE id_vehiculo = ? AND id_usuario = ? AND activo = TRUE',
    [id_vehiculo, yo]
  );
  if (!veh) throw new HttpError(400, 'Selecciona uno de tus vehículos');

  let asientos = veh.capacidad_maxima;
  if (req.body.asientos_disponibles !== undefined && req.body.asientos_disponibles !== null) {
    asientos = toInt(req.body.asientos_disponibles, 'asientos_disponibles');
    if (asientos < 1 || asientos > veh.capacidad_maxima) {
      throw new HttpError(400, `Los asientos deben estar entre 1 y ${veh.capacidad_maxima}`);
    }
  }

  const [r] = await pool.query(
    `INSERT INTO Viajes (id_chofer, id_vehiculo, punto_origen, punto_destino, fecha_hora_salida, asientos_disponibles, notas)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [yo, id_vehiculo, origen, destino, salida.sql, asientos, req.body.notas ? String(req.body.notas).slice(0, 255) : null]
  );
  const [[viaje]] = await pool.query(`${SELECT_VIAJE} WHERE v.id_viaje = ?`, [r.insertId]);
  const notificados = await notificarRutaCoincidente(viaje);
  res.status(201).json({ ...viaje, notificados });
}));

// Cambiar estado del viaje: Programado -> En Curso -> Finalizado, o Programado -> Cancelado.
const TRANSICIONES = {
  Programado: ['En Curso', 'Cancelado'],
  'En Curso': ['Finalizado'],
};

router.patch('/:id/estado', asyncHandler(async (req, res) => {
  const nuevo = req.body.estado;
  const viaje = await withTransaction(async (conn) => {
    const [[v]] = await conn.query('SELECT * FROM Viajes WHERE id_viaje = ? FOR UPDATE', [req.params.id]);
    if (!v) throw new HttpError(404, 'Viaje no encontrado');
    if (v.id_chofer !== req.user.id_usuario) throw new HttpError(403, 'Solo el chofer puede cambiar el estado');
    if (!(TRANSICIONES[v.estado_viaje] || []).includes(nuevo)) {
      throw new HttpError(400, `No se puede pasar de "${v.estado_viaje}" a "${nuevo}"`);
    }
    await conn.query('UPDATE Viajes SET estado_viaje = ? WHERE id_viaje = ?', [nuevo, v.id_viaje]);

    if (nuevo !== 'Finalizado') {
      // Las solicitudes pendientes ya no se pueden atender una vez que arranca o se cancela.
      await conn.query(
        `UPDATE Solicitudes_Asiento SET estado_solicitud = 'Rechazada'
          WHERE id_viaje = ? AND estado_solicitud = 'Pendiente'`,
        [v.id_viaje]
      );
    }
    const [pasajeros] = await conn.query(
      `SELECT id_pasajero FROM Solicitudes_Asiento WHERE id_viaje = ? AND estado_solicitud = 'Aceptada'`,
      [v.id_viaje]
    );
    const textos = {
      'En Curso': ['Tu viaje ya arrancó', `El chofer inició el viaje a ${v.punto_destino}.`],
      Finalizado: ['Viaje finalizado', `Llegaste a ${v.punto_destino}. ¡Califica a tu chofer!`],
      Cancelado: ['Viaje cancelado', `El chofer canceló el viaje a ${v.punto_destino}.`],
    };
    for (const p of pasajeros) {
      await notificar(p.id_pasajero, textos[nuevo][0], textos[nuevo][1], v.id_viaje, conn);
    }
    return v;
  });
  res.json({ id_viaje: viaje.id_viaje, estado_viaje: nuevo });
}));

// Ubicación en vivo: el chofer la envía mientras el viaje está En Curso.
router.put('/:id/ubicacion', asyncHandler(async (req, res) => {
  const lat = Number(req.body.latitud);
  const lng = Number(req.body.longitud);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) {
    throw new HttpError(400, 'Ubicación inválida');
  }
  const rumbo = Number.isFinite(Number(req.body.rumbo)) ? Math.round(Number(req.body.rumbo)) % 360 : null;
  const [[v]] = await pool.query('SELECT id_chofer, estado_viaje FROM Viajes WHERE id_viaje = ?', [req.params.id]);
  if (!v) throw new HttpError(404, 'Viaje no encontrado');
  if (v.id_chofer !== req.user.id_usuario) throw new HttpError(403, 'Solo el chofer comparte su ubicación');
  if (v.estado_viaje !== 'En Curso') throw new HttpError(409, 'El viaje no está en curso');
  await pool.query(
    `INSERT INTO Ubicacion_Viaje (id_viaje, latitud, longitud, rumbo) VALUES (?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE latitud = VALUES(latitud), longitud = VALUES(longitud), rumbo = VALUES(rumbo),
                             actualizada = CURRENT_TIMESTAMP`,
    [req.params.id, lat, lng, rumbo]
  );
  res.json({ ok: true });
}));

// Última ubicación del chofer: solo para el chofer y sus pasajeros aceptados.
router.get('/:id/ubicacion', asyncHandler(async (req, res) => {
  const yo = req.user.id_usuario;
  const [[v]] = await pool.query('SELECT id_chofer, estado_viaje FROM Viajes WHERE id_viaje = ?', [req.params.id]);
  if (!v) throw new HttpError(404, 'Viaje no encontrado');
  if (v.id_chofer !== yo) {
    const [[s]] = await pool.query(
      `SELECT 1 FROM Solicitudes_Asiento WHERE id_viaje = ? AND id_pasajero = ? AND estado_solicitud = 'Aceptada'`,
      [req.params.id, yo]
    );
    if (!s) throw new HttpError(403, 'Solo los pasajeros del viaje ven la ubicación');
  }
  if (v.estado_viaje !== 'En Curso') return res.json(null);
  const [[u]] = await pool.query(
    `SELECT latitud, longitud, rumbo, TIMESTAMPDIFF(SECOND, actualizada, NOW()) AS hace_segundos
       FROM Ubicacion_Viaje WHERE id_viaje = ?`,
    [req.params.id]
  );
  res.json(u || null);
}));

// Solicitar asiento (el usuario actúa como Pasajero).
router.post('/:id/solicitudes', asyncHandler(async (req, res) => {
  const yo = req.user.id_usuario;
  const resultado = await withTransaction(async (conn) => {
    const [[v]] = await conn.query('SELECT * FROM Viajes WHERE id_viaje = ? FOR UPDATE', [req.params.id]);
    if (!v) throw new HttpError(404, 'Viaje no encontrado');
    if (v.id_chofer === yo) throw new HttpError(400, 'No puedes reservar en tu propio viaje');
    if (v.estado_viaje !== 'Programado') throw new HttpError(409, 'El viaje ya no acepta solicitudes');
    if (v.asientos_disponibles <= 0) throw new HttpError(409, 'El viaje ya está lleno');

    const [[existente]] = await conn.query(
      'SELECT * FROM Solicitudes_Asiento WHERE id_viaje = ? AND id_pasajero = ?',
      [v.id_viaje, yo]
    );
    let id_solicitud;
    if (existente) {
      if (existente.estado_solicitud !== 'Cancelada') {
        throw new HttpError(409, `Ya tienes una solicitud ${existente.estado_solicitud.toLowerCase()} en este viaje`);
      }
      await conn.query(
        `UPDATE Solicitudes_Asiento SET estado_solicitud = 'Pendiente', fecha_solicitud = NOW() WHERE id_solicitud = ?`,
        [existente.id_solicitud]
      );
      id_solicitud = existente.id_solicitud;
    } else {
      const [r] = await conn.query(
        'INSERT INTO Solicitudes_Asiento (id_viaje, id_pasajero) VALUES (?, ?)',
        [v.id_viaje, yo]
      );
      id_solicitud = r.insertId;
    }
    await notificar(v.id_chofer, 'Nueva solicitud de asiento',
      `${req.user.nombre_completo} quiere unirse a tu viaje a ${v.punto_destino}.`, v.id_viaje, conn);
    return { id_solicitud, estado_solicitud: 'Pendiente' };
  });
  res.status(201).json(resultado);
}));

module.exports = router;
