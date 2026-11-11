// Crea (o actualiza) el administrador inicial definido en .env
require('dotenv').config();
const bcrypt = require('bcryptjs');
const { pool } = require('./db');

(async () => {
  const correo = (process.env.ADMIN_CORREO || 'admin@universidad.edu.mx').toLowerCase();
  const password = process.env.ADMIN_PASSWORD || 'Admin123!';
  const hash = await bcrypt.hash(password, 10);
  await pool.query(
    `INSERT INTO Usuarios (nombre_completo, correo_institucional, password_hash, estado_cuenta, rol, email_verificado)
     VALUES ('Administrador UniRaite', ?, ?, 'Activo', 'Administrador', TRUE)
     ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash), rol = 'Administrador', estado_cuenta = 'Activo', email_verificado = TRUE`,
    [correo, hash]
  );
  console.log(`Administrador listo: ${correo}`);
  await pool.end();
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
