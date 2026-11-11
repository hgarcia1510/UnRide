const nodemailer = require('nodemailer');
const { HttpError } = require('../errors');

function validarConfiguracionCorreo() {
  const user = process.env.SMTP_USER?.trim();
  const password = process.env.SMTP_PASSWORD;
  if (!process.env.SMTP_HOST?.trim() || !process.env.SMTP_FROM?.trim()) {
    throw new HttpError(503, 'Falta configurar SMTP_HOST y SMTP_FROM en el .env del servidor.');
  }
  if (Boolean(user) !== Boolean(password)) {
    throw new HttpError(503, 'Configura juntos SMTP_USER y SMTP_PASSWORD, o deja ambos vacíos.');
  }
}

async function enviarCodigoVerificacion(correo, codigo) {
  validarConfiguracionCorreo();
  const port = Number(process.env.SMTP_PORT || 587);
  const auth = process.env.SMTP_USER?.trim()
    ? { user: process.env.SMTP_USER.trim(), pass: process.env.SMTP_PASSWORD }
    : undefined;
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST.trim(),
    port,
    secure: String(process.env.SMTP_SECURE || (port === 465)).toLowerCase() === 'true',
    auth,
    connectionTimeout: 10000,
    greetingTimeout: 10000,
    socketTimeout: 15000,
  });

  try {
    await transporter.sendMail({
      from: process.env.SMTP_FROM,
      to: correo,
      subject: 'Confirma tu correo de UniRaite',
      text: `Tu código de verificación es ${codigo}. Vence en 15 minutos. Si no creaste una cuenta, ignora este correo.`,
      html: `<div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;color:#111"><h2>Confirma tu correo</h2><p>Escribe este código en UniRaite:</p><p style="font-size:32px;font-weight:bold;letter-spacing:8px">${codigo}</p><p>El código vence en 15 minutos. Si no creaste una cuenta, ignora este correo.</p></div>`,
    });
  } catch {
    throw new HttpError(503, 'No se pudo enviar el correo. Revisa la configuración SMTP del servidor.');
  } finally {
    transporter.close();
  }
}

module.exports = { enviarCodigoVerificacion, validarConfiguracionCorreo };
