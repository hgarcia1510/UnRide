#!/usr/bin/env bash
# Actualiza el backend del servidor con el código de la carpeta de Windows,
# aplica migraciones pendientes y reinicia la API. No toca .env ni las fotos subidas.
# Uso (en WSL): sudo bash /mnt/c/Users/garci/uniraite/deploy/actualizar_backend.sh
set -euo pipefail
ORIGEN=/mnt/c/Users/garci/uniraite
DESTINO=/opt/uniraite

echo "==> Código"
rm -rf "$DESTINO/backend/src"
cp -r "$ORIGEN/backend/src" "$DESTINO/backend/src"
if ! cmp -s "$ORIGEN/backend/package-lock.json" "$DESTINO/backend/package-lock.json"; then
  cp "$ORIGEN/backend/package.json" "$ORIGEN/backend/package-lock.json" "$DESTINO/backend/"
  (cd "$DESTINO/backend" && npm ci --omit=dev)
fi
cp -r "$ORIGEN/database/." "$DESTINO/database/"
cp "$ORIGEN/deploy/"*.sh "$ORIGEN/deploy/"*.service "$ORIGEN/deploy/"*.conf "$DESTINO/deploy/" 2>/dev/null || true
mkdir -p "$DESTINO/backend/uploads/fotos"
chown -R uniraite:uniraite "$DESTINO/backend"

echo "==> Migraciones"
if [ "$(mysql -N -e "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='uniraite' AND TABLE_NAME='Usuarios' AND COLUMN_NAME='foto_url'")" = "0" ]; then
  mysql uniraite < "$DESTINO/database/migracion_002_foto_perfil.sql"
  echo "    002 foto de perfil: aplicada"
else
  echo "    002 foto de perfil: ya estaba"
fi
mysql uniraite < "$DESTINO/database/migracion_003_ubicacion_viaje.sql"
echo "    003 ubicación del chofer: lista"

if [ "$(mysql -N -e "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='uniraite' AND TABLE_NAME='Usuarios' AND COLUMN_NAME='email_verificado'")" = "0" ]; then
  mysql uniraite < "$DESTINO/database/migracion_004_verificacion_email.sql"
  echo "    004 verificaciÃ³n de correo: aplicada"
else
  echo "    004 verificaciÃ³n de correo: ya estaba"
fi

echo "==> Reiniciando API"
systemctl restart uniraite-api
sleep 2
curl -s http://localhost:3000/api/salud && echo
