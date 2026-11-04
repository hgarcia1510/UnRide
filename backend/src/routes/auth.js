const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { pool } = require('../db');
const { HttpError, asyncHandler } = require('../errors');
const { requireFields, esCorreoInstitucional, CORREO_RE } = require('../validators');

const firmar = (id) => jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: '30d' });

async function perfil(id) {
  const [rows] = await pool.query(
    `SELECT id_usuario, nombre_completo, correo_institucional, telefono, foto_url, calificacion_promedio,
            estado_cuenta, rol, fecha_registro
       FROM Usuarios WHERE id_usuario = ?`,
    [id]
  );
  return rows[0];
}

// Muro de confianza: correo institucional => cuenta Activa;
// cualquier otro correo => cuenta Pendiente de validación manual del administrador.
router.post('/registro', asyncHandler(async (req, res) => {
  requireFields(req.body, ['nombre_completo', 'correo', 'password']);
  const nombre = String(req.body.nombre_completo).trim();
  const correo = String(req.body.correo).trim().toLowerCase();
  const { password, telefono } = req.body;

  if (!CORREO_RE.test(correo)) throw new HttpError(400, 'Correo inválido');
  if (String(password).length < 8) throw new HttpError(400, 'La contraseña debe tener al menos 8 caracteres');
  if (nombre.length > 100) throw new HttpError(400, 'Nombre demasiado largo');

  const institucional = esCorreoInstitucional(correo);
  const hash = await bcrypt.hash(String(password), 10);

  let insertId;
  try {
    const [r] = await pool.query(
      `INSERT INTO Usuarios (nombre_completo, correo_institucional, password_hash, telefono, estado_cuenta)
       VALUES (?, ?, ?, ?, ?)`,
      [nombre, correo, hash, telefono || null, institucional ? 'Activo' : 'Pendiente']
    );
    insertId = r.insertId;
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') throw new HttpError(409, 'Ese correo ya está registrado');
    throw err;
  }

  if (!institucional) {
    return res.status(202).json({
      pendiente: true,
      mensaje: 'Tu correo no es institucional. Un administrador debe validar tu cuenta antes de que puedas entrar.',
    });
  }
  res.status(201).json({ token: firmar(insertId), usuario: await perfil(insertId) });
}));

router.post('/login', asyncHandler(async (req, res) => {
  requireFields(req.body, ['correo', 'password']);
  const correo = String(req.body.correo).trim().toLowerCase();
  const [rows] = await pool.query('SELECT * FROM Usuarios WHERE correo_institucional = ?', [correo]);
  const u = rows[0];
  if (!u || !(await bcrypt.compare(String(req.body.password), u.password_hash))) {
    throw new HttpError(401, 'Correo o contraseña incorrectos');
  }
  if (u.estado_cuenta === 'Suspendido') throw new HttpError(403, 'Tu cuenta está suspendida');
  if (u.estado_cuenta === 'Pendiente') throw new HttpError(403, 'Tu cuenta espera validación del administrador');
  res.json({ token: firmar(u.id_usuario), usuario: await perfil(u.id_usuario) });
}));

module.exports = { router, perfil };
