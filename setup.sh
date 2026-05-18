#!/usr/bin/env bash
# Stawia całe szkolenie n8n od zera:
#   - instaluje Dockera (jeśli trzeba)
#   - generuje .env.prod z hasłami i kluczami
#   - otwiera porty 5678-5699 w ufw (jeśli aktywne)
#   - uruchamia 22 izolowane kontenery n8n + postgres
#   - tworzy access-list.csv z URL-ami, loginami i hasłami uczestników
#
# Użycie:
#   bash setup.sh                  # IP z .env.prod lub auto-wykrycie
#   bash setup.sh 1.2.3.4          # nadpisuje IP

set -euo pipefail

cd "$(dirname "$0")"

VPS_IP_ARG="${1:-}"
COMPOSE_FILE="docker-compose.prod.yaml"
ENV_FILE=".env.prod"
CSV_OUT="access-list.csv"
BASE_PORT=5678

log() { echo -e "\n\033[1;34m==>\033[0m $*"; }
err() { echo -e "\033[1;31mBŁĄD:\033[0m $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Zależności
# ---------------------------------------------------------------------------
log "Sprawdzam zależności (docker, openssl)..."
command -v openssl >/dev/null || err "openssl nie jest zainstalowany"

if ! command -v docker >/dev/null; then
  log "Docker nie jest zainstalowany — instaluję..."
  curl -fsSL https://get.docker.com | sh
fi

docker compose version >/dev/null 2>&1 || err "docker compose plugin nie działa"

[ -f participants.csv ] || err "Brakuje participants.csv"
[ -f "$COMPOSE_FILE" ]  || err "Brakuje $COMPOSE_FILE"

# ---------------------------------------------------------------------------
# 2. Ustal VPS_IP
# ---------------------------------------------------------------------------
VPS_IP=""
if [ -n "$VPS_IP_ARG" ]; then
  VPS_IP="$VPS_IP_ARG"
elif [ -f "$ENV_FILE" ]; then
  VPS_IP=$(grep -E '^VPS_IP=' "$ENV_FILE" | cut -d= -f2 | tr -d '"' | tr -d "'" || true)
fi
if [ -z "$VPS_IP" ] || [ "$VPS_IP" = "CHANGE_ME" ]; then
  VPS_IP=$(curl -fsS --max-time 5 ifconfig.me 2>/dev/null || true)
fi
[ -n "$VPS_IP" ] || err "Nie udało się ustalić VPS_IP — podaj jako argument: bash setup.sh 1.2.3.4"
log "Używam VPS_IP=${VPS_IP}"

# ---------------------------------------------------------------------------
# 3. .env.prod
# ---------------------------------------------------------------------------
if [ -f "$ENV_FILE" ]; then
  log "$ENV_FILE już istnieje — zachowuję istniejące hasła/klucze"
else
  log "Generuję $ENV_FILE..."
  yes t | bash generate-env.sh >/dev/null
fi

log "Ustawiam VPS_IP w $ENV_FILE"
sed -i -E "s|^VPS_IP=.*|VPS_IP=${VPS_IP}|" "$ENV_FILE"

# ---------------------------------------------------------------------------
# 4. Firewall
# ---------------------------------------------------------------------------
if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
  log "Otwieram porty 22 i 5678-5699 w ufw..."
  ufw allow 22/tcp           >/dev/null 2>&1 || true
  ufw allow 5678:5699/tcp    >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# 5. Uruchom kontenery
# ---------------------------------------------------------------------------
log "Uruchamiam docker compose (postgres + 22 × n8n)..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d

log "Czekam aż kontenery zgłoszą running (max 90s)..."
for _ in $(seq 1 45); do
  not_running=$(docker compose -f "$COMPOSE_FILE" ps --format '{{.State}}' | grep -vc '^running$' || true)
  [ "$not_running" = "0" ] && break
  sleep 2
done
docker compose -f "$COMPOSE_FILE" ps

# ---------------------------------------------------------------------------
# 6. CSV z dostępami
# ---------------------------------------------------------------------------
log "Generuję $CSV_OUT (nr,name,url,email,password)..."

# shellcheck disable=SC1090
set -a; . "$ENV_FILE"; set +a

{
  echo "nr,name,url,email,password"
  while IFS=, read -r nr name email; do
    [[ "$nr" =~ ^[[:space:]]*(nr|#) ]] && continue
    [[ -z "${nr// }" ]] && continue
    NUM=$(printf '%02d' $((10#${nr// })))
    PORT=$(( BASE_PORT + 10#${nr// } - 1 ))
    EMAIL_VAR="N8N_${NUM}_ADMIN_EMAIL"
    PASS_VAR="N8N_${NUM}_ADMIN_PASSWORD"
    URL="http://${VPS_IP}:${PORT}"
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
echo " Dostęp:    http://${VPS_IP}:5678  …  http://${VPS_IP}:5699"
echo " Konta:     $CSV_OUT  (nr,name,url,email,password)"
echo " Sekrety:   $ENV_FILE (NIE commituj!)"
echo ""
echo " Pierwsze wiersze CSV:"
head -4 "$CSV_OUT" | sed 's/^/   /'
echo "════════════════════════════════════════════════════════════════════"
