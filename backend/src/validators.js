const { HttpError } = require('./errors');

function requireFields(body, fields) {
  for (const f of fields) {
    if (body[f] === undefined || body[f] === null || String(body[f]).trim() === '') {
      throw new HttpError(400, `El campo "${f}" es obligatorio`);
    }
  }
}

function dominiosInstitucionales() {
  return (process.env.DOMINIOS_INSTITUCIONALES || '')
    .split(',')
    .map((d) => d.trim().toLowerCase())
    .filter(Boolean);
}

function esCorreoInstitucional(correo) {
  const dominio = correo.split('@')[1]?.toLowerCase();
  return dominiosInstitucionales().includes(dominio);
}

const CORREO_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Acepta 'YYYY-MM-DD HH:MM[:SS]' o ISO; regresa 'YYYY-MM-DD HH:MM:SS' en hora local.
function normalizarFecha(valor) {
  const d = new Date(String(valor).replace(' ', 'T'));
  if (Number.isNaN(d.getTime())) throw new HttpError(400, 'Fecha inválida');
  const p = (n) => String(n).padStart(2, '0');
  return {
    date: d,
    sql: `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:00`,
  };
}

function toInt(valor, nombre) {
  const n = Number(valor);
  if (!Number.isInteger(n)) throw new HttpError(400, `"${nombre}" debe ser un número entero`);
  return n;
}

module.exports = { requireFields, esCorreoInstitucional, dominiosInstitucionales, CORREO_RE, normalizarFecha, toInt };
