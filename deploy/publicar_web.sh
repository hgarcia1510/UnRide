#!/usr/bin/env bash
# Publica la página de descarga, la app web (PWA), el APK y la config de Nginx desde la carpeta de Windows.
# Uso (en WSL): sudo bash /mnt/c/Users/garci/uniraite/deploy/publicar_web.sh
set -euo pipefail
ORIGEN=/mnt/c/Users/garci/uniraite

cp "$ORIGEN/deploy/descargar/index.html" "$ORIGEN/deploy/descargar/logo.svg" /var/www/uniraite/
rm -rf /var/www/uniraite/app
cp -r "$ORIGEN/app/build/web" /var/www/uniraite/app
# La web vive en /app/: corrige el base href por si se compiló sin --base-href /app/
sed -i 's|<base href="[^"]*">|<base href="/app/">|' /var/www/uniraite/app/index.html
APK="$ORIGEN/app/build/app/outputs/flutter-apk/app-release.apk"
[ -f "$APK" ] && cp "$APK" /var/www/uniraite/uniraite.apk
chown -R www-data:www-data /var/www/uniraite

cp "$ORIGEN/deploy/nginx-uniraite.conf" /opt/uniraite/deploy/nginx-uniraite.conf
sed "s/__DOMINIO__/_/g" /opt/uniraite/deploy/nginx-uniraite.conf > /etc/nginx/sites-available/uniraite
nginx -t && systemctl reload nginx
echo "Publicado."
