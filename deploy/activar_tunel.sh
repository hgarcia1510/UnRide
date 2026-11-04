#!/usr/bin/env bash
# Crea/arranca el túnel público de Cloudflare como servicio y muestra la URL.
# Uso: sudo bash activar_tunel.sh
set -euo pipefail

cat > /etc/systemd/system/uniraite-tunnel.service <<'EOF'
[Unit]
Description=UniRaite - Cloudflare Quick Tunnel
After=network-online.target nginx.service
Wants=network-online.target

[Service]
ExecStart=/usr/bin/cloudflared tunnel --no-autoupdate --protocol http2 --url http://localhost:80
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable uniraite-tunnel >/dev/null 2>&1
INICIO=$(date '+%Y-%m-%d %H:%M:%S')
systemctl restart uniraite-tunnel

URL=""
for _ in $(seq 1 40); do
  URL=$(journalctl -u uniraite-tunnel --since "$INICIO" --no-pager -o cat \
        | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1 || true)
  [ -n "$URL" ] && break
  sleep 2
done

if [ -z "$URL" ]; then
  echo "No se obtuvo la URL. Revisa: journalctl -u uniraite-tunnel -n 50"
  exit 1
fi
echo "$URL" > /opt/uniraite/url_publica.txt
echo "$URL"
