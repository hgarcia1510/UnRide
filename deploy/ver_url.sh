#!/usr/bin/env bash
# Muestra el link público actual del túnel (sin reiniciarlo).
# Uso (en WSL): sudo bash /mnt/c/Users/garci/uniraite/deploy/ver_url.sh
URL=""
for _ in $(seq 1 30); do
  URL=$(journalctl -u uniraite-tunnel -b --no-pager -o cat | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1)
  [ -n "$URL" ] && break
  sleep 2
done
[ -n "$URL" ] && echo "$URL" > /opt/uniraite/url_publica.txt
echo "${URL:-Sin URL todavía. Revisa: journalctl -u uniraite-tunnel -n 50}"
