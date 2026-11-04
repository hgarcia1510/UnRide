const router = require('express').Router();
const bcrypt = require('bcryptjs');
const { pool } = require('../db');
const { HttpError, asyncHandler } = require('../errors');
const { perfil } = require('./auth');
const { guardarFoto, borrarFoto } = require('../services/fotos');

router.get('/me', asyncHandler(async (req, res) => {
  const id = req.user.id_usuario;
  const usuario = await perfil(id);
  const [[stats]] = await pool.query(
    `SELECT
       (SELECT COUNT(*) FROM Viajes WHERE id_chofer = ? AND estado_viaje = 'Finalizado') AS viajes_como_chofer,
       (SELECT COUNT(*) FROM Solicitudes_Asiento s JOIN Viajes v ON v.id_viaje = s.id_viaje
         WHERE s.id_pasajero = ? AND s.estado_solicitud = 'Aceptada' AND v.estado_viaje = 'Finalizado') AS viajes_como_pasajero,
       (SELECT COUNT(*) FROM Resenas WHERE id_evaluado = ?) AS total_resenas`,
    [id, id, id]
  );
  res.json({ ...usuario, ...stats });
}));

router.patch('/me', asyncHandler(async (req, res) => {
  const id = req.user.id_usuario;
  const { nombre_completo, telefono, password_actual, password_nueva } = req.body;
  if (nombre_completo !== undefined) {
    const nombre = String(nombre_completo).trim();
    if (!nombre || nombre.length > 100) throw new HttpError(400, 'Nombre inválido');
    await pool.query('UPDATE Usuarios SET nombre_completo = ? WHERE id_usuario = ?', [nombre, id]);
  }
  if (telefono !== undefined) {
    await pool.query('UPDATE Usuarios SET telefono = ? WHERE id_usuario = ?', [telefono || null, id]);
  }
  if (password_nueva) {
    const [[u]] = await pool.query('SELECT password_hash FROM Usuarios WHERE id_usuario = ?', [id]);
    if (!password_actual || !(await bcrypt.compare(String(password_actual), u.password_hash))) {
      throw new HttpError(400, 'La contraseña actual no es correcta');
    }
    if (String(password_nueva).length < 8) throw new HttpError(400, 'La contraseña debe tener al menos 8 caracteres');
    await pool.query('UPDATE Usuarios SET password_hash = ? WHERE id_usuario = ?',
      [await bcrypt.hash(String(password_nueva), 10), id]);
  }
  res.json(await perfil(id));
}));

// Subir/cambiar foto de perfil (JSON: { imagen: "<base64>" })
router.put('/me/foto', asyncHandler(async (req, res) => {
  const id = req.user.id_usuario;
  const url = await guardarFoto(id, req.body.imagen);
  const [[antes]] = await pool.query('SELECT foto_url FROM Usuarios WHERE id_usuario = ?', [id]);
  await pool.query('UPDATE Usuarios SET foto_url = ? WHERE id_usuario = ?', [url, id]);
  await borrarFoto(antes?.foto_url);
  res.json(await perfil(id));
}));

router.delete('/me/foto', asyncHandler(async (req, res) => {
  const id = req.user.id_usuario;
  const [[antes]] = await pool.query('SELECT foto_url FROM Usuarios WHERE id_usuario = ?', [id]);
  await pool.query('UPDATE Usuarios SET foto_url = NULL WHERE id_usuario = ?', [id]);
  await borrarFoto(antes?.foto_url);
  res.json(await perfil(id));
}));

// Perfil público + reseñas recibidas
router.get('/:id', asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    'SELECT id_usuario, nombre_completo, foto_url, calificacion_promedio, fecha_registro FROM Usuarios WHERE id_usuario = ?',
    [req.params.id]
  );
  if (!rows[0]) throw new HttpError(404, 'Usuario no encontrado');
  const [resenas] = await pool.query(
    `SELECT r.calificacion, r.comentario, r.fecha, u.nombre_completo AS autor
       FROM Resenas r JOIN Usuarios u ON u.id_usuario = r.id_autor
      WHERE r.id_evaluado = ? ORDER BY r.fecha DESC LIMIT 20`,
    [req.params.id]
  );
  res.json({ ...rows[0], resenas });
}));

module.exports = router;
