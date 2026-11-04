const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');
const { HttpError } = require('../errors');

const DIR_FOTOS = path.resolve(process.env.UPLOADS_DIR || path.join(__dirname, '..', '..', 'uploads'), 'fotos');
const MAX_BYTES = 4 * 1024 * 1024;

// Se valida por la firma real del archivo, no por lo que diga el cliente.
function detectarFormato(buf) {
  if (buf.length > 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'jpg';
  if (buf.length > 8 && buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'png';
  if (buf.length > 12 && buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') return 'webp';
  return null;
}

async function guardarFoto(idUsuario, base64) {
  if (typeof base64 !== 'string' || !base64) throw new HttpError(400, 'Falta la imagen');
  const limpio = base64.replace(/^data:image\/[a-z]+;base64,/, '');
  const buf = Buffer.from(limpio, 'base64');
  if (!buf.length) throw new HttpError(400, 'Imagen inválida');
  if (buf.length > MAX_BYTES) throw new HttpError(413, 'La foto pesa más de 4 MB');
  const ext = detectarFormato(buf);
  if (!ext) throw new HttpError(400, 'Formato no soportado (usa JPG, PNG o WEBP)');

  await fs.mkdir(DIR_FOTOS, { recursive: true });
  const nombre = `u${idUsuario}_${Date.now()}_${crypto.randomBytes(4).toString('hex')}.${ext}`;
  await fs.writeFile(path.join(DIR_FOTOS, nombre), buf);
  return `/api/fotos/${nombre}`;
}

async function borrarFoto(fotoUrl) {
  if (!fotoUrl || !fotoUrl.startsWith('/api/fotos/')) return;
  const nombre = path.basename(fotoUrl);
  await fs.unlink(path.join(DIR_FOTOS, nombre)).catch(() => {});
}

module.exports = { DIR_FOTOS, guardarFoto, borrarFoto };
