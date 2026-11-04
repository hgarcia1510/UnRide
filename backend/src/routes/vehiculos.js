const router = require('express').Router();
const { pool } = require('../db');
const { HttpError, asyncHandler } = require('../errors');
const { requireFields, toInt } = require('../validators');

router.get('/', asyncHandler(async (req, res) => {
  const [rows] = await pool.query(
    'SELECT * FROM Vehiculos WHERE id_usuario = ? AND activo = TRUE ORDER BY id_vehiculo DESC',
    [req.user.id_usuario]
  );
  res.json(rows);
}));

router.post('/', asyncHandler(async (req, res) => {
  requireFields(req.body, ['placas', 'modelo_color', 'capacidad_maxima']);
  const capacidad = toInt(req.body.capacidad_maxima, 'capacidad_maxima');
  if (capacidad < 1 || capacidad > 8) throw new HttpError(400, 'La capacidad debe estar entre 1 y 8 pasajeros');
  const placas = String(req.body.placas).trim().toUpperCase();
  if (placas.length > 15) throw new HttpError(400, 'Placas demasiado largas');

  let insertId;
  try {
    const [r] = await pool.query(
      'INSERT INTO Vehiculos (id_usuario, placas, modelo_color, capacidad_maxima) VALUES (?, ?, ?, ?)',
      [req.user.id_usuario, placas, String(req.body.modelo_color).trim(), capacidad]
    );
    insertId = r.insertId;
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') throw new HttpError(409, 'Esas placas ya están registradas');
    throw err;
  }
  const [[v]] = await pool.query('SELECT * FROM Vehiculos WHERE id_vehiculo = ?', [insertId]);
  res.status(201).json(v);
}));

// Baja lógica: los viajes históricos siguen referenciando al vehículo.
router.delete('/:id', asyncHandler(async (req, res) => {
  const [[activos]] = await pool.query(
    `SELECT COUNT(*) AS n FROM Viajes WHERE id_vehiculo = ? AND estado_viaje IN ('Programado','En Curso')`,
    [req.params.id]
  );
  if (activos.n > 0) throw new HttpError(409, 'El vehículo tiene viajes activos');
  const [r] = await pool.query(
    'UPDATE Vehiculos SET activo = FALSE WHERE id_vehiculo = ? AND id_usuario = ?',
    [req.params.id, req.user.id_usuario]
  );
  if (!r.affectedRows) throw new HttpError(404, 'Vehículo no encontrado');
  res.status(204).end();
}));

module.exports = router;
