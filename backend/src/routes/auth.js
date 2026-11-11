const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { createHmac, randomInt, timingSafeEqual } = require('node:crypto');
const { pool, withTransaction } = require('../db');
const { HttpError, asyncHandler } = require('../errors');
const { requireFields, esCorreoInstitucional, CORREO_RE } = require('../validators');
const { enviarCodigoVerificacion, validarConfiguracionCorreo } = require('../services/correo');

const firmar = (id) => jwt.sign({ id }, process.env.JWT_SECRET, { expiresIn: '30d' });
const MAX_INTENTOS_CODIGO = 5;
const MAX_ENVIOS_HORA = 5;
const hashCodigo = (id, codigo) =>
  createHmac('sha256', process.env.JWT_SECRET).update(`${id}:${codigo}`).digest('hex');

async function perfil(id) {
  const [rows] = await pool.query(
    `SELECT id_usuario, nombre_completo, correo_institucional, telefono, foto_url, calificacion_promedio,
            (SELECT COUNT(*) FROM Resenas WHERE id_evaluado = Usuarios.id_usuario) AS total_resenas,
            estado_cuenta, rol, fecha_registro
       FROM Usuarios WHERE id_usuario = ?`,
    [id]
  );
  return rows[0];
}

async function nuevoCodigo(idUsuario, correo, { nuevo = false } = {}) {
  validarConfiguracionCorreo();
  const codigo = String(randomInt(0, 1_000_000)).padStart(6, '0');
  const codigoHash = hashCodigo(idUsuario, codigo);

  if (nuevo) {
    await pool.query(
      `INSERT INTO Verificaciones_Email
         (id_usuario, codigo_hash, expira, enviado_en, intentos, envios_ventana, ventana_envios)
       VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 15 MINUTE), NOW(), 0, 1, NOW())`,
      [idUsuario, codigoHash]
    );
  } else {
    const [[control]] = await pool.query(
      `SELECT envios_ventana,
              TIMESTAMPDIFF(SECOND, enviado_en, NOW()) AS segundos_desde_envio,
              TIMESTAMPDIFF(SECOND, ventana_envios, NOW()) AS segundos_ventana
         FROM Verificaciones_Email WHERE id_usuario = ?`,
      [idUsuario]
    );
    if (control && Number(control.segundos_desde_envio) < 60) {
      const espera = 60 - Number(control.segundos_desde_envio);
      throw new HttpError(429, `Espera ${espera} s antes de pedir otro código.`);
    }
    if (control && Number(control.segundos_ventana) < 3600 && Number(control.envios_ventana) >= MAX_ENVIOS_HORA) {
      throw new HttpError(429, 'Alcanzaste el límite de códigos. Intenta de nuevo en una hora.');
    }

    if (!control) {
      await pool.query(
        `INSERT INTO Verificaciones_Email
           (id_usuario, codigo_hash, expira, enviado_en, intentos, envios_ventana, ventana_envios)
         VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 15 MINUTE), NOW(), 0, 1, NOW())`,
        [idUsuario, codigoHash]
      );
    } else {
      await pool.query(
        `UPDATE Verificaciones_Email
            SET codigo_hash = ?, expira = DATE_ADD(NOW(), INTERVAL 15 MINUTE), enviado_en = NOW(), intentos = 0,
                envios_ventana = IF(TIMESTAMPDIFF(SECOND, ventana_envios, NOW()) >= 3600, 1, envios_ventana + 1),
                ventana_envios = IF(TIMESTAMPDIFF(SECOND, ventana_envios, NOW()) >= 3600, NOW(), ventana_envios)
          WHERE id_usuario = ?`,
        [codigoHash, idUsuario]
      );
    }
  }

  try {
    await enviarCodigoVerificacion(correo, codigo);
  } catch (error) {
    await pool.query('DELETE FROM Verificaciones_Email WHERE id_usuario = ?', [idUsuario]);
    throw error;
  }
}

router.post('/registro', asyncHandler(async (req, res) => {
  requireFields(req.body, ['nombre_completo', 'correo', 'password']);
  const nombre = String(req.body.nombre_completo).trim();
  const correo = String(req.body.correo).trim().toLowerCase();
  const { password, telefono } = req.body;

  if (!CORREO_RE.test(correo)) throw new HttpError(400, 'Correo inválido');
  if (String(password).length < 8) throw new HttpError(400, 'La contraseña debe tener al menos 8 caracteres');
  if (nombre.length > 100) throw new HttpError(400, 'Nombre demasiado largo');
  validarConfiguracionCorreo();

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
    if (err.code === 'ER_DUP_ENTRY') {
      throw new HttpError(409, 'Ese correo ya está registrado. Si falta verificarlo, pide otro código desde el inicio de sesión.');
    }
    throw err;
  }

  await nuevoCodigo(insertId, correo, { nuevo: true });
  res.status(202).json({ verificacion_requerida: true, correo, mensaje: 'Revisa tu correo para confirmar la cuenta.' });
}));

router.post('/reenviar-verificacion', asyncHandler(async (req, res) => {
  requireFields(req.body, ['correo']);
  const correo = String(req.body.correo).trim().toLowerCase();
  if (!CORREO_RE.test(correo)) throw new HttpError(400, 'Correo inválido');

  const [rows] = await pool.query(
    'SELECT id_usuario, email_verificado FROM Usuarios WHERE correo_institucional = ?',
    [correo]
  );
  const user = rows[0];
  if (user && !user.email_verificado) await nuevoCodigo(user.id_usuario, correo);
  res.status(202).json({ mensaje: 'Si la cuenta requiere verificación, enviamos un código.' });
}));

router.post('/verificar-correo', asyncHandler(async (req, res) => {
  requireFields(req.body, ['correo', 'codigo']);
  const correo = String(req.body.correo).trim().toLowerCase();
  const codigo = String(req.body.codigo).trim();
  if (!CORREO_RE.test(correo)) throw new HttpError(400, 'Correo inválido');
  if (!/^\d{6}$/.test(codigo)) throw new HttpError(400, 'El código debe tener 6 dígitos');

  const resultado = await withTransaction(async (conn) => {
    const [[user]] = await conn.query(
      'SELECT id_usuario, email_verificado, estado_cuenta FROM Usuarios WHERE correo_institucional = ? FOR UPDATE',
      [correo]
    );
    if (!user) return { estado: 'invalido' };
    if (user.email_verificado) return { estado: 'ya_verificado' };

    const [[verificacion]] = await conn.query(
      `SELECT codigo_hash, intentos, (expira <= NOW()) AS vencido
         FROM Verificaciones_Email WHERE id_usuario = ? FOR UPDATE`,
      [user.id_usuario]
    );
    if (!verificacion) return { estado: 'vencido' };
    if (verificacion.vencido) {
      await conn.query('DELETE FROM Verificaciones_Email WHERE id_usuario = ?', [user.id_usuario]);
      return { estado: 'vencido' };
    }
    if (Number(verificacion.intentos) >= MAX_INTENTOS_CODIGO) return { estado: 'limite' };

    const recibido = Buffer.from(hashCodigo(user.id_usuario, codigo), 'hex');
    const guardado = Buffer.from(verificacion.codigo_hash, 'hex');
    const coincide = recibido.length === guardado.length && timingSafeEqual(recibido, guardado);
    if (!coincide) {
      await conn.query('UPDATE Verificaciones_Email SET intentos = intentos + 1 WHERE id_usuario = ?', [user.id_usuario]);
      return { estado: 'incorrecto', restantes: MAX_INTENTOS_CODIGO - Number(verificacion.intentos) - 1 };
    }

    await conn.query('UPDATE Usuarios SET email_verificado = TRUE WHERE id_usuario = ?', [user.id_usuario]);
    await conn.query('DELETE FROM Verificaciones_Email WHERE id_usuario = ?', [user.id_usuario]);
    return { estado: 'verificado', id: user.id_usuario, estadoCuenta: user.estado_cuenta };
  });

  if (resultado.estado === 'incorrecto') {
    throw new HttpError(400, `Código incorrecto. Te quedan ${resultado.restantes} intentos.`);
  }
  if (resultado.estado === 'vencido' || resultado.estado === 'invalido') {
    throw new HttpError(400, 'El código no es válido o ya venció. Pide otro código.');
  }
  if (resultado.estado === 'limite') {
    throw new HttpError(429, 'Alcanzaste el límite de intentos. Pide un código nuevo.');
  }
  if (resultado.estado === 'ya_verificado') {
    throw new HttpError(409, 'Este correo ya está verificado. Inicia sesión.');
  }
  if (resultado.estadoCuenta === 'Suspendido') throw new HttpError(403, 'Tu cuenta está suspendida');
  if (resultado.estadoCuenta === 'Pendiente') {
    return res.status(202).json({
      pendiente: true,
      mensaje: 'Correo verificado. Un administrador debe validar tu cuenta antes de que puedas entrar.',
    });
  }
  res.status(201).json({ token: firmar(resultado.id), usuario: await perfil(resultado.id) });
}));

router.post('/login', asyncHandler(async (req, res) => {
  requireFields(req.body, ['correo', 'password']);
  const correo = String(req.body.correo).trim().toLowerCase();
  const [rows] = await pool.query('SELECT * FROM Usuarios WHERE correo_institucional = ?', [correo]);
  const user = rows[0];
  if (!user || !(await bcrypt.compare(String(req.body.password), user.password_hash))) {
    throw new HttpError(401, 'Correo o contraseña incorrectos');
  }
  if (!user.email_verificado) {
    throw new HttpError(403, 'Verifica tu correo antes de iniciar sesión. Puedes reenviar el código desde aquí.');
  }
  if (user.estado_cuenta === 'Suspendido') throw new HttpError(403, 'Tu cuenta está suspendida');
  if (user.estado_cuenta === 'Pendiente') throw new HttpError(403, 'Tu cuenta espera validación del administrador');
  res.json({ token: firmar(user.id_usuario), usuario: await perfil(user.id_usuario) });
}));

module.exports = { router, perfil };
