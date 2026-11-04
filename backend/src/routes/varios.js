// Rutas guardadas, notificaciones y reseñas.
const express = require('express');
const { pool } = require('../db');
const { HttpError, asyncHandler } = require('../errors');
const { requireFields, toInt } = require('../validators');

// ---------------- Rutas guardadas ----------------
const rutas = express.Router();

rutas.get('/', asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    'SELECT * FROM Rutas_Guardadas WHERE id_usuario = ? ORDER BY id_ruta DESC', [req.user.id_usuario]);
  res.json(rows);
}));

rutas.post('/', asyncHandler(async (req, res) => {
  requireFields(req.body, ['punto_destino']);
  const destino = String(req.body.punto_destino).trim().slice(0, 150);
  const origen = req.body.punto_origen ? String(req.body.punto_origen).trim().slice(0, 150) : null;
  const [r] = await pool.query(
    'INSERT INTO Rutas_Guardadas (id_usuario, punto_origen, punto_destino) VALUES (?, ?, ?)',
    [req.user.id_usuario, origen, destino]);
  res.status(201).json({ id_ruta: r.insertId, id_usuario: req.user.id_usuario, punto_origen: origen, punto_destino: destino });
}));

rutas.delete('/:id', asyncHandler(async (req, res) => {
  const [r] = await pool.query('DELETE FROM Rutas_Guardadas WHERE id_ruta = ? AND id_usuario = ?',
    [req.params.id, req.user.id_usuario]);
  if (!r.affectedRows) throw new HttpError(404, 'Ruta no encontrada');
  res.status(204).end();
}));

// ---------------- Notificaciones ----------------
const notificaciones = express.Router();

notificaciones.get('/', asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    'SELECT * FROM Notificaciones WHERE id_usuario = ? ORDER BY fecha DESC, id_notificacion DESC LIMIT 100',
    [req.user.id_usuario]);
  res.json(rows.map((n) => ({ ...n, leida: !!n.leida })));
}));

notificaciones.get('/no-leidas', asyncHandler(async (req, res) => {
  const [[r]] = await pool.query(
    'SELECT COUNT(*) AS total FROM Notificaciones WHERE id_usuario = ? AND leida = FALSE', [req.user.id_usuario]);
  res.json(r);
}));

notificaciones.post('/leer-todas', asyncHandler(async (req, res) => {
  await pool.query('UPDATE Notificaciones SET leida = TRUE WHERE id_usuario = ?', [req.user.id_usuario]);
  res.status(204).end();
}));

// ---------------- Reseñas ----------------
const resenas = express.Router();

resenas.post('/', asyncHandler(async (req, res) => {
  requireFields(req.body, ['id_viaje', 'id_evaluado', 'calificacion']);
  const yo = req.user.id_usuario;
  const id_viaje = toInt(req.body.id_viaje, 'id_viaje');
  const id_evaluado = toInt(req.body.id_evaluado, 'id_evaluado');
  const calificacion = toInt(req.body.calificacion, 'calificacion');
  if (calificacion < 1 || calificacion > 5) throw new HttpError(400, 'La calificación va de 1 a 5');
  if (id_evaluado === yo) throw new HttpError(400, 'No puedes calificarte a ti mismo');

  const [[v]] = await pool.query('SELECT id_chofer, estado_viaje FROM Viajes WHERE id_viaje = ?', [id_viaje]);
  if (!v) throw new HttpError(404, 'Viaje no encontrado');
  if (v.estado_viaje !== 'Finalizado') throw new HttpError(409, 'Solo se califican viajes finalizados');

  const [aceptados] = await pool.query(
    `SELECT id_pasajero FROM Solicitudes_Asiento WHERE id_viaje = ? AND estado_solicitud = 'Aceptada'`, [id_viaje]);
  const pasajeros = aceptados.map((a) => a.id_pasajero);
  const yoSoyChofer = v.id_chofer === yo;
  // El chofer califica a sus pasajeros; cada pasajero califica al chofer.
  const valido = yoSoyChofer
    ? pasajeros.includes(id_evaluado)
    : pasajeros.includes(yo) && id_evaluado === v.id_chofer;
  if (!valido) throw new HttpError(403, 'No participaste en ese viaje con esa persona');

  try {
    await pool.query(
      'INSERT INTO Resenas (id_viaje, id_autor, id_evaluado, calificacion, comentario) VALUES (?, ?, ?, ?, ?)',
      [id_viaje, yo, id_evaluado, calificacion, req.body.comentario ? String(req.body.comentario).slice(0, 255) : null]);
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') throw new HttpError(409, 'Ya calificaste a esta persona en este viaje');
    throw err;
  }
  res.status(201).json({ ok: true });
}));

module.exports = { rutas, notificaciones, resenas };
