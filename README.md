# UniRaite – Carpooling universitario (app móvil)

Proyecto de JAH Devs (Aron, Hugo, José de Jesús), construido a partir del documento
*Arquitectura y Base de Datos – UniRaite*. Esta versión es **solo para móvil** (Android / iOS).

```
uniraite/
├── database/schema.sql   → Base de datos MySQL (tablas, restricciones y triggers)
├── backend/              → API REST: Node.js + Express (JWT + bcrypt + transacciones)
└── app/                  → App móvil: Flutter / Dart
```

> **¿Por qué hay backend?** Una app móvil nunca debe conectarse directo a MySQL: tendría
> que llevar el usuario y la contraseña de la base dentro del APK, y cualquiera podría extraerlos.
> La app habla con la API y la API con MySQL, tal como lo marca el documento.

---

## 1. Base de datos (MySQL 8)

```powershell
cd C:\Users\garci\uniraite\database
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p -e "source schema.sql"
```

También puedes abrir `schema.sql` en **MySQL Workbench** y ejecutarlo (rayo ⚡).

Tablas: `Usuarios`, `Vehiculos`, `Viajes`, `Solicitudes_Asiento` (las 4 del documento) +
`Rutas_Guardadas`, `Notificaciones` y `Resenas` (necesarias para notificaciones y calificaciones).

### Reglas de negocio que garantiza la base de datos
| Regla | Cómo se implementa |
|---|---|
| Prevención de overbooking | Trigger `trg_solicitudes_before_update`: al aceptar una solicitud bloquea la fila del viaje (`FOR UPDATE`) y lanza error si `asientos_disponibles` llegó a 0. También hay `CHECK (asientos_disponibles >= 0)`. |
| Asientos iniciales | Trigger `trg_viajes_before_insert`: toma la `capacidad_maxima` del vehículo y valida que el auto sea del chofer. |
| Capacidad ≤ 8 | `CHECK (capacidad_maxima BETWEEN 1 AND 8)` |
| Placas y correo únicos | `UNIQUE` |
| Calificación promedio | Trigger `trg_resenas_after_insert` recalcula el promedio (default 5.0). |
| Liberar asiento | Si una solicitud aceptada se cancela, el trigger devuelve el asiento. |

## 2. Backend (Node.js)

```powershell
cd C:\Users\garci\uniraite\backend
copy .env.example .env      # y edita DB_PASSWORD, JWT_SECRET y DOMINIOS_INSTITUCIONALES
npm install
npm run seed                # crea el administrador inicial (ADMIN_CORREO / ADMIN_PASSWORD)
npm start                   # http://localhost:3000/api
```

Prueba: abre `http://localhost:3000/api/salud` → `{"ok":true,"db":"conectada"}`.

**Muro de confianza:** si el correo pertenece a `DOMINIOS_INSTITUCIONALES` la cuenta queda
`Activo`; si no, queda `Pendiente` y el administrador la valida desde la app
(Perfil → Panel de administrador).

### Endpoints principales
| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/auth/registro`, `/api/auth/login` | Registro / inicio de sesión |
| GET/PATCH | `/api/usuarios/me` | Perfil y estadísticas |
| GET/POST/DELETE | `/api/vehiculos` | Vehículos del chofer |
| GET | `/api/viajes?destino=&origen=&fecha=` | Buscar viajes |
| POST | `/api/viajes` | Publicar viaje (notifica a rutas guardadas) |
| GET | `/api/viajes/mios`, `/api/viajes/:id` | Mis viajes / detalle |
| PATCH | `/api/viajes/:id/estado` | Programado → En Curso → Finalizado, o Cancelado |
| POST | `/api/viajes/:id/solicitudes` | Pedir asiento |
| PATCH | `/api/solicitudes/:id` | Aceptar / Rechazar (chofer) o Cancelar (pasajero) |
| GET | `/api/solicitudes/mias` | Mis reservas |
| GET/POST/DELETE | `/api/rutas` | Rutas guardadas |
| GET | `/api/notificaciones` | Bandeja de notificaciones |
| POST | `/api/resenas` | Calificar al terminar el viaje |
| GET/PATCH | `/api/admin/...` | Validar / suspender cuentas, estadísticas |

## 3. App móvil (Flutter)

```powershell
cd C:\Users\garci\uniraite\app
flutter pub get

# Emulador Android (usa 10.0.2.2 para llegar a tu PC):
flutter run

# Celular físico en la misma red Wi-Fi (usa la IP de tu PC, ver con `ipconfig`):
flutter run --dart-define=API_URL=http://192.168.X.X:3000/api

# APK para instalar:
flutter build apk --release --dart-define=API_URL=http://TU_SERVIDOR:3000/api
```

Si el celular no conecta, permite el puerto 3000 en el Firewall de Windows.

### Pantallas
- **Login / Registro** (aviso si el correo no es institucional)
- **Buscar**: filtra por origen, destino y fecha; botón *Avisarme* guarda la ruta
- **Conducir**: tus viajes como chofer y botón *Publicar viaje*
- **Reservas**: tus solicitudes como pasajero
- **Detalle del viaje**: solicitar/cancelar asiento, aceptar/rechazar pasajeros, iniciar/finalizar, calificar
- **Perfil**: vehículos, rutas guardadas, editar perfil, panel de administrador
- **Notificaciones**: campana con contador (se revisa cada 20 s y al volver a la app)

**Roles dinámicos:** no hay "cuenta de chofer" ni "cuenta de pasajero"; la misma cuenta publica
viajes en *Conducir* y reserva en *Buscar*.

## Notificaciones push reales (siguiente paso)
Hoy las notificaciones se guardan en MySQL y la app las consulta mientras está abierta.
Para que lleguen con la app cerrada hay que agregar **Firebase Cloud Messaging**:
crear un proyecto en Firebase, `flutterfire configure`, el paquete `firebase_messaging` en la app,
guardar el token FCM por usuario y enviarlo con `firebase-admin` desde
`backend/src/services/notificaciones.js` (función `notificar`).
