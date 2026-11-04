class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

// Envuelve handlers async para que los errores lleguen al middleware de errores.
const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

function errorMiddleware(err, req, res, next) {
  if (err instanceof HttpError) {
    return res.status(err.status).json({ error: err.message });
  }
  // Errores lanzados por los triggers (SIGNAL SQLSTATE '45000')
  if (err.sqlState === '45000') {
    return res.status(409).json({ error: err.sqlMessage });
  }
  // Errores de express/body-parser (JSON mal formado, cuerpo demasiado grande)
  if (err.type === 'entity.too.large') {
    return res.status(413).json({ error: 'El archivo es demasiado grande' });
  }
  if (err.expose && err.status) {
    return res.status(err.status).json({ error: 'Petición inválida' });
  }
  if (err.code === 'ER_DUP_ENTRY') {
    return res.status(409).json({ error: 'El registro ya existe' });
  }
  if (err.code === 'ER_CHECK_CONSTRAINT_VIOLATED') {
    return res.status(400).json({ error: 'Los datos no cumplen las restricciones' });
  }
  console.error(err);
  res.status(500).json({ error: 'Error interno del servidor' });
}

module.exports = { HttpError, asyncHandler, errorMiddleware };
