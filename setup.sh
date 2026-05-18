#!/usr/bin/env bash
# Stawia całe szkolenie n8n od zera: instaluje Dockera (jeśli trzeba),
# generuje .env.prod, certyfikat SSL, uruchamia 22 kontenery i tworzy
# access-list.csv z URL-ami, loginami i hasłami uczestników.
#
# Użycie:
#   bash setup.sh                  # IP z .env.prod (lub 51.83.32.60)
#   bash setup.sh 1.2.3.4          # nadpisuje IP

set -euo pipefail

VPS_IP="${1:-51.83.32.60}"
COMPOSE_FILE="docker-compose.prod.yaml"
ENV_FILE=".env.prod"
CSV_OUT="access-list.csv"

cd "$(dirname "$0")"

log() { echo -e "\n\033[1;34m==>\033[0m $*"; }
err() { echo -e "\033[1;31mERROR:\033[0m $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Sprawdź zależności
# ---------------------------------------------------------------------------
log "Sprawdzam zależności (docker, openssl)..."
command -v openssl >/dev/null || err "openssl nie jest zainstalowany"

if ! command -v docker >/dev/null; then
  log "Docker nie jest zainstalowany — instaluję..."
  curl -fsSL https://get.docker.com | sh
fi

docker compose version >/dev/null 2>&1 || err "docker compose plugin nie działa"

[ -f participants.csv ] || err "Brakuje participants.csv"
[ -f "$COMPOSE_FILE" ] || err "Brakuje $COMPOSE_FILE"

# ---------------------------------------------------------------------------
# 2. .env.prod
# ---------------------------------------------------------------------------
if [ -f "$ENV_FILE" ]; then
  log "$ENV_FILE już istnieje — pomijam generowanie (usuń ręcznie, by zregenerować)"
else
  log "Generuję $ENV_FILE i access-list.txt..."
  yes t | bash generate-env.sh
fi

# Wymuś podany VPS_IP
log "Ustawiam VPS_IP=${VPS_IP} w $ENV_FILE"
sed -i -E "s|^VPS_IP=.*|VPS_IP=${VPS_IP}|" "$ENV_FILE"
sed -i -E "s|https://[^/]+/|https://${VPS_IP}/|g" access-list.txt 2>/dev/null || true

# ---------------------------------------------------------------------------
# 3. Certyfikat SSL
# ---------------------------------------------------------------------------
if [ -f nginx/certs/cert.pem ] && [ -f nginx/certs/key.pem ]; then
  log "Certyfikat już istnieje w nginx/certs/ — pomijam"
else
  log "Generuję self-signed certyfikat SSL dla ${VPS_IP}..."
  bash generate-certs.sh "$VPS_IP"
fi

# ---------------------------------------------------------------------------
# 4. Firewall (jeśli ufw zainstalowane i aktywne)
# ---------------------------------------------------------------------------
if command -v ufw >/dev/null; then
  log "Otwieram porty w ufw (22, 80, 443)..."
  ufw allow 22/tcp   >/dev/null 2>&1 || true
  ufw allow 80/tcp   >/dev/null 2>&1 || true
  ufw allow 443/tcp  >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# 5. Uruchom kontenery
# ---------------------------------------------------------------------------
log "Uruchamiam docker compose (22 × n8n + nginx + postgres)..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d

log "Czekam aż wszystkie kontenery zgłoszą running (max 60s)..."
for i in $(seq 1 30); do
  not_running=$(docker compose -f "$COMPOSE_FILE" ps --format '{{.State}}' | grep -vc '^running$' || true)
  [ "$not_running" = "0" ] && break
  sleep 2
done
docker compose -f "$COMPOSE_FILE" ps

# ---------------------------------------------------------------------------
# 6. Wygeneruj CSV z dostępami
# ---------------------------------------------------------------------------
log "Generuję $CSV_OUT z URL-ami, loginami i hasłami..."

# shellcheck disable=SC1090
set -a; . "$ENV_FILE"; set +a

{
  echo "nr,name,url,email,password"
  while IFS=, read -r nr name email; do
    [[ "$nr" =~ ^[[:space:]]*(nr|#) ]] && continue
    [[ -z "${nr// }" ]] && continue
    NUM=$(printf '%02d' $((10#${nr// })))
    EMAIL_VAR="N8N_${NUM}_ADMIN_EMAIL"
    PASS_VAR="N8N_${NUM}_ADMIN_PASSWORD"
    URL="https://${VPS_IP}/${NUM}/"
    # CSV-escape przecinków i cudzysłowów w name
    safe_name=$(echo "$name" | sed 's/"/""/g')
    echo "\"${NUM}\",\"${safe_name}\",\"${URL}\",\"${!EMAIL_VAR:-}\",\"${!PASS_VAR:-}\""
  done < participants.csv
} > "$CSV_OUT"

# ---------------------------------------------------------------------------
# 7. Podsumowanie
# ---------------------------------------------------------------------------
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo " GOTOWE — szkolenie n8n uruchomione"
echo "════════════════════════════════════════════════════════════════════"
echo " Adres bazowy:   https://${VPS_IP}/01/  …  https://${VPS_IP}/22/"
echo " Dostępy:        $CSV_OUT  (CSV: nr,name,url,email,password)"
echo "                 access-list.txt  (czytelna tabela)"
echo " Sekrety:        $ENV_FILE  (NIE commituj!)"
echo ""
echo " Przykładowe wiersze:"
head -4 "$CSV_OUT" | sed 's/^/   /'
echo "════════════════════════════════════════════════════════════════════"
