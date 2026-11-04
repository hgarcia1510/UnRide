#!/usr/bin/env bash
# =====================================================================
# UniRaite - Instalación en Ubuntu 22.04 / 24.04
# Uso (en el servidor, como usuario con sudo):
#   Servidor con dominio:  sudo DOMINIO=uniraite.midominio.com CORREO=tu@correo.com bash instalar_servidor.sh
#   WSL / sin dominio:     sudo bash instalar_servidor.sh   (luego se publica con Cloudflare Tunnel)
# Requiere que el proyecto ya esté copiado en /opt/uniraite
# y que el dominio apunte (registro DNS tipo A) a la IP del servidor.
# =====================================================================
set -euo pipefail

DOMINIO="${DOMINIO:-}"
CORREO="${CORREO:-}"
if [ -n "$DOMINIO" ] && [ -z "$CORREO" ]; then echo "Con DOMINIO también define CORREO"; exit 1; fi
APP_DIR=/opt/uniraite
DB_PASS="${DB_PASS:-$(openssl rand -hex 16)}"
JWT_SECRET="$(openssl rand -hex 32)"
ADMIN_PASS="${ADMIN_PASS:-$(openssl rand -base64 12)}"
DOMINIOS_INSTITUCIONALES="${DOMINIOS_INSTITUCIONALES:-alumnos.universidad.edu.mx,universidad.edu.mx}"
ADMIN_CORREO="${ADMIN_CORREO:-admin@universidad.edu.mx}"

echo "==> Paquetes del sistema"
apt-get update
apt-get install -y curl ca-certificates gnupg nginx mysql-server openssl
[ -n "$DOMINIO" ] && apt-get install -y certbot python3-certbot-nginx ufw

echo "==> Node.js 22 LTS"
if ! command -v node >/dev/null || [ "$(node -v | cut -d. -f1 | tr -d v)" -lt 20 ]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

echo "==> Base de datos MySQL"
if mysql -e "USE uniraite" 2>/dev/null; then
  echo "    La base 'uniraite' ya existe: NO se recrea (para no borrar datos)."
else
  mysql < "$APP_DIR/database/schema.sql"
fi
mysql -e "CREATE USER IF NOT EXISTS 'uniraite'@'localhost' IDENTIFIED BY '$DB_PASS';
          ALTER USER 'uniraite'@'localhost' IDENTIFIED BY '$DB_PASS';
          GRANT SELECT, INSERT, UPDATE, DELETE ON uniraite.* TO 'uniraite'@'localhost';
          FLUSH PRIVILEGES;"

echo "==> Backend"
id -u uniraite >/dev/null 2>&1 || useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin uniraite
cd "$APP_DIR/backend"
npm ci --omit=dev
if [ ! -f .env ]; then
  cat > .env <<EOF
PORT=3000
DB_HOST=localhost
DB_PORT=3306
DB_USER=uniraite
DB_PASSWORD=$DB_PASS
DB_NAME=uniraite
JWT_SECRET=$JWT_SECRET
DOMINIOS_INSTITUCIONALES=$DOMINIOS_INSTITUCIONALES
ADMIN_CORREO=$ADMIN_CORREO
ADMIN_PASSWORD=$ADMIN_PASS
EOF
  chmod 600 .env
  npm run seed
  echo
  echo "    *** Administrador: $ADMIN_CORREO  /  contraseña: $ADMIN_PASS  (guárdala) ***"
  echo
fi
chown -R uniraite:uniraite "$APP_DIR/backend"

echo "==> Servicio systemd"
cp "$APP_DIR/deploy/uniraite-api.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now uniraite-api
systemctl restart uniraite-api

echo "==> Página de descarga"
mkdir -p /var/www/uniraite
cp -r "$APP_DIR/deploy/descargar/." /var/www/uniraite/
chown -R www-data:www-data /var/www/uniraite

echo "==> Nginx"
sed "s/__DOMINIO__/${DOMINIO:-_}/g" "$APP_DIR/deploy/nginx-uniraite.conf" > /etc/nginx/sites-available/uniraite
ln -sf /etc/nginx/sites-available/uniraite /etc/nginx/sites-enabled/uniraite
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

if [ -n "$DOMINIO" ]; then
  echo "==> Firewall"
  ufw allow OpenSSH
  ufw allow "Nginx Full"
  ufw --force enable

  echo "==> Certificado HTTPS (Let's Encrypt)"
  certbot --nginx -d "$DOMINIO" -m "$CORREO" --agree-tos --non-interactive --redirect
  URL="https://$DOMINIO"
else
  URL="http://localhost (publícalo con: cloudflared tunnel --url http://localhost:80)"
fi

echo
echo "Listo:"
echo "  API:        $URL/api/salud"
echo "  Descargas:  $URL/  (sube el APK a /var/www/uniraite/uniraite.apk)"
