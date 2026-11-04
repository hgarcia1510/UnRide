require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { pool } = require('./db');
const { errorMiddleware } = require('./errors');
const { requireAuth, requireAdmin } = require('./middleware/auth');
const { dominiosInstitucionales } = require('./validators');

if (!process.env.JWT_SECRET) {
  console.error('Falta JWT_SECRET en el archivo .env (copia .env.example a .env)');
  process.exit(1);
}

const app = express();
app.use(cors());
// Las fotos de perfil llegan en base64 (hasta ~4 MB); el resto de la API, 100 KB.
const jsonChico = express.json({ limit: '100kb' });
const jsonFoto = express.json({ limit: '6mb' });
app.use((req, res, next) => (req.path === '/api/usuarios/me/foto' ? jsonFoto : jsonChico)(req, res, next));

// Fotos de perfil públicas (nombres aleatorios, solo lectura)
const { DIR_FOTOS } = require('./services/fotos');
app.use('/api/fotos', express.static(DIR_FOTOS, { maxAge: '7d', immutable: true }));

app.get('/api/salud', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ ok: true, db: 'conectada' });
  } catch (e) {
    res.status(503).json({ ok: false, db: e.message });
  }
});

app.get('/api/config', (req, res) => res.json({ dominios_institucionales: dominiosInstitucionales() }));

app.use('/api/auth', require('./routes/auth').router);

const { rutas, notificaciones, resenas } = require('./routes/varios');
app.use('/api/usuarios', requireAuth, require('./routes/usuarios'));
app.use('/api/vehiculos', requireAuth, require('./routes/vehiculos'));
app.use('/api/viajes', requireAuth, require('./routes/viajes'));
app.use('/api/solicitudes', requireAuth, require('./routes/solicitudes'));
app.use('/api/rutas', requireAuth, rutas);
app.use('/api/notificaciones', requireAuth, notificaciones);
app.use('/api/resenas', requireAuth, resenas);
app.use('/api/admin', requireAuth, requireAdmin, require('./routes/admin'));

// Página de descarga, APK y app web (PWA) cuando no hay Nginx enfrente (p. ej. en Windows).
if (process.env.WEB_DIR) {
  const path = require('path');
  const WEB_DIR = path.resolve(process.env.WEB_DIR);
  const sinCache = /[\\/]app[\\/](index\.html|flutter_service_worker\.js)$/;
  app.get('/uniraite.apk', (req, res) =>
    res.download(path.join(WEB_DIR, 'uniraite.apk'), 'UniRaite.apk', (e) => {
      if (e && !res.headersSent) res.status(404).json({ error: 'APK no publicado' });
    }));
  app.use(express.static(WEB_DIR, {
    setHeaders: (res, ruta) => { if (sinCache.test(ruta)) res.setHeader('Cache-Control', 'no-cache'); },
  }));
  // Rutas internas de la PWA: siempre su index.html
  app.get(/^\/app(\/.*)?$/, (req, res) =>
    res.sendFile(path.join(WEB_DIR, 'app', 'index.html'), { headers: { 'Cache-Control': 'no-cache' } }));
}

app.use((req, res) => res.status(404).json({ error: 'Ruta no encontrada' }));
app.use(errorMiddleware);

const PORT = Number(process.env.PORT || 3000);
// 0.0.0.0 para que el celular pueda conectarse desde la misma red Wi-Fi.
app.listen(PORT, '0.0.0.0', () => console.log(`UniRaite API escuchando en http://localhost:${PORT}/api`));
