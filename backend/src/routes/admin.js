const router = require('express').Router();
const { pool } = require('../db');
const { HttpError, asyncHandler } = require('../errors');
const { notificar } = require('../services/notificaciones');

router.get('/estadisticas', asyncHandler(async (req, res) => {
  const [[r]] = await pool.query(
    `SELECT
       (SELECT COUNT(*) FROM Usuarios) AS usuarios,
       (SELECT COUNT(*) FROM Usuarios WHERE estado_cuenta = 'Pendiente') AS pendientes,
       (SELECT COUNT(*) FROM Usuarios WHERE estado_cuenta = 'Suspendido') AS suspendidos,
       (SELECT COUNT(*) FROM Vehiculos WHERE activo = TRUE) AS vehiculos,
       (SELECT COUNT(*) FROM Viajes WHERE estado_viaje = 'Programado') AS viajes_programados,
       (SELECT COUNT(*) FROM Viajes WHERE estado_viaje = 'Finalizado') AS viajes_finalizados`);
  res.json(r);
}));

router.get('/usuarios', asyncHandler(async (req, res) => {
  const where = [];
  const params = [];
  if (req.query.estado) { where.push('estado_cuenta = ?'); params.push(req.query.estado); }
  if (req.query.q) {
    where.push('(nombre_completo LIKE ? OR correo_institucional LIKE ?)');
    params.push(`%${req.query.q}%`, `%${req.query.q}%`);
  }
  const [rows] = await pool.query(
    `SELECT id_usuario, nombre_completo, correo_institucional, telefono, foto_url, calificacion_promedio,
            estado_cuenta, rol, fecha_registro
       FROM Usuarios ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
      ORDER BY FIELD(estado_cuenta, 'Pendiente','Suspendido','Activo'), fecha_registro DESC
      LIMIT 200`,
    params);
  res.json(rows);
}));

// Validar (Activo) o bloquear (Suspendido) una cuenta.
router.patch('/usuarios/:id', asyncHandler(async (req, res) => {
  const estado = req.body.estado_cuenta;
  if (!['Activo', 'Suspendido'].includes(estado)) throw new HttpError(400, 'Estado inválido');
  if (Number(req.params.id) === req.user.id_usuario) throw new HttpError(400, 'No puedes cambiar tu propia cuenta');

  const [r] = await pool.query('UPDATE Usuarios SET estado_cuenta = ? WHERE id_usuario = ?', [estado, req.params.id]);
  if (!r.affectedRows) throw new HttpError(404, 'Usuario no encontrado');
  if (estado === 'Activo') {
    await notificar(req.params.id, 'Cuenta activa', 'Tu cuenta de UniRaite está activa. ¡Bienvenido!');
  }
  res.json({ id_usuario: Number(req.params.id), estado_cuenta: estado });
}));

module.exports = router;
