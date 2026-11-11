const jwt = require('jsonwebtoken');
const { pool } = require('../db');
const { HttpError, asyncHandler } = require('../errors');

const requireAuth = asyncHandler(async (req, res, next) => {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) throw new HttpError(401, 'No autenticado');

  let payload;
  try {
    payload = jwt.verify(token, process.env.JWT_SECRET);
  } catch {
    throw new HttpError(401, 'Sesión inválida o expirada');
  }

  // Se consulta el estado en cada petición para que una suspensión sea inmediata.
  const [rows] = await pool.query(
    'SELECT id_usuario, nombre_completo, correo_institucional, rol, estado_cuenta, email_verificado FROM Usuarios WHERE id_usuario = ?',
    [payload.id]
  );
  const user = rows[0];
  if (!user) throw new HttpError(401, 'Usuario no encontrado');
  if (!user.email_verificado) throw new HttpError(403, 'Verifica tu correo antes de usar la cuenta');
  if (user.estado_cuenta === 'Suspendido') throw new HttpError(403, 'Tu cuenta está suspendida');
  if (user.estado_cuenta === 'Pendiente') throw new HttpError(403, 'Tu cuenta espera validación del administrador');

  req.user = user;
  next();
});

function requireAdmin(req, res, next) {
  if (req.user?.rol !== 'Administrador') return next(new HttpError(403, 'Solo administradores'));
  next();
}

module.exports = { requireAuth, requireAdmin };
