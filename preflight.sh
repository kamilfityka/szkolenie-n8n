#!/usr/bin/env bash
# =============================================================================
# preflight.sh — sprawdzenie serwera PRZED postawieniem floty n8n
# =============================================================================
# Sprawdza to, co najczęściej wywraca szkolenie: DNS nieprzepropagowany,
# zajęte porty, za mało RAM-u, NPM poza siecią docker.
#
# Użycie:
#   bash preflight.sh user{1..20}     # sprawdź te subdomeny
#   bash preflight.sh                 # sprawdź instancje już zdefiniowane
#
# Oczekiwane IP bierze z SERVER_IP w .env.dynamic, a jeśli go nie ma —
# wykrywa publiczny adres serwera.
# =============================================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

require_env

ERRORS=0
WARNS=0
fail() { bad_line "$@"; ERRORS=$((ERRORS + 1)); }
bad_line() { echo -e "\033[1;31m✗\033[0m $*"; }
warn_line() { echo -e "\033[1;33m!\033[0m $*"; WARNS=$((WARNS + 1)); }

section() { echo -e "\n\033[1;34m==>\033[0m $*"; }

# --- lista instancji do sprawdzenia -----------------------------------------
SLUGS=("$@")
if [ ${#SLUGS[@]} -eq 0 ]; then
  shopt -s nullglob
  for f in "$INSTANCES_DIR"/*.yaml; do SLUGS+=("$(basename "$f" .yaml)"); done
fi
[ ${#SLUGS[@]} -gt 0 ] || c_err "Podaj nazwy instancji, np:  bash preflight.sh user{1..20}"

# --- 1. narzędzia ------------------------------------------------------------
section "Narzędzia"
for t in docker openssl curl; do
  if command -v "$t" >/dev/null 2>&1; then c_ok "$t"; else fail "brak: $t"; fi
done
docker compose version >/dev/null 2>&1 && c_ok "docker compose" || fail "plugin 'docker compose' nie działa"

# --- 2. konfiguracja ---------------------------------------------------------
section "Konfiguracja (.env.dynamic)"
c_ok "BASE_DOMAIN = ${BASE_DOMAIN}"
if grep -v '^[[:space:]]*#' "$ENV_DYNAMIC" | grep -q "CHANGE_ME"; then
  fail "w .env.dynamic zostały wartości CHANGE_ME — uzupełnij hasła i ACME_EMAIL"
else
  c_ok "brak pozostawionych CHANGE_ME"
fi
c_ok "sieć nginx-proxy-managera: ${NPM_NETWORK}"

# --- 3. IP serwera -----------------------------------------------------------
section "Adres IP serwera"
if [ -z "${SERVER_IP:-}" ]; then
  SERVER_IP="$(curl -s --max-time 8 https://api.ipify.org 2>/dev/null || true)"
fi
if [ -z "${SERVER_IP:-}" ]; then
  warn_line "nie udało się wykryć publicznego IP — ustaw SERVER_IP=... w .env.dynamic"
else
  c_ok "oczekiwane IP: ${SERVER_IP}"
fi

# --- 4. DNS ------------------------------------------------------------------
section "DNS (${#SLUGS[@]} subdomen)"
resolve() {
  if command -v dig >/dev/null 2>&1; then
    dig +short A "$1" | grep -E '^[0-9.]+$' | tail -1
  else
    getent hosts "$1" 2>/dev/null | awk '{print $1}' | head -1
  fi
}
DNS_BAD=()
for s in "${SLUGS[@]}"; do
  fqdn="${s}.${BASE_DOMAIN}"
  ip="$(resolve "$fqdn")"
  if [ -z "$ip" ]; then
    DNS_BAD+=("${fqdn} → brak rekordu")
  elif [ -n "${SERVER_IP:-}" ] && [ "$ip" != "$SERVER_IP" ]; then
    DNS_BAD+=("${fqdn} → ${ip}")
  fi
done
if [ ${#DNS_BAD[@]} -eq 0 ]; then
  c_ok "wszystkie subdomeny wskazują na ${SERVER_IP:-ten serwer}"
else
  fail "${#DNS_BAD[@]} z ${#SLUGS[@]} subdomen nie wskazuje na serwer:"
  printf '     %s\n' "${DNS_BAD[@]}"
  echo "     Uwaga: przy catch-all wildcardzie na domenie brakujący rekord nie zwróci"
  echo "     błędu, tylko cudze IP. Popraw DNS i odczekaj TTL przed instalacją."
fi

# --- 5. Porty 80/443 ---------------------------------------------------------
section "Porty 80/443"
if command -v ss >/dev/null 2>&1; then
  LISTEN="$(ss -tlnp 2>/dev/null | grep -E ':(80|443)\s' || true)"
  if [ -z "$LISTEN" ]; then
    warn_line "nikt nie słucha na 80/443 — czy nginx-proxy-manager na pewno działa?"
  else
    echo "$LISTEN" | sed 's/^/     /'
    c_ok "porty zajęte — spodziewane, trzyma je nginx-proxy-manager"
  fi
else
  warn_line "brak 'ss' — sprawdź porty ręcznie"
fi

# --- 6. nginx-proxy-manager --------------------------------------------------
section "nginx-proxy-manager"
if docker network inspect "$NPM_NETWORK" >/dev/null 2>&1; then
  c_ok "sieć '${NPM_NETWORK}' istnieje"
else
  fail "sieć docker '${NPM_NETWORK}' nie istnieje — sprawdź 'docker network ls'
     i wpisz właściwą nazwę do .env.dynamic (NPM_NETWORK=...)"
fi

NPM_C="$(detect_npm_container || true)"
if [ -z "$NPM_C" ]; then
  warn_line "nie wykryto kontenera NPM — jeśli działa pod nietypowym obrazem,
   ustaw NPM_CONTAINER=<nazwa> w .env.dynamic"
else
  c_ok "kontener: ${NPM_C}"
  NETS="$(npm_container_networks "$NPM_C")"
  if echo "$NETS" | grep -qx "$NPM_NETWORK"; then
    c_ok "stoi w sieci '${NPM_NETWORK}' — dosięgnie kontenery n8n po nazwie"
  else
    fail "NPM nie jest w sieci '${NPM_NETWORK}' (jest w: $(echo "$NETS" | tr '\n' ' ')) — dostaniesz 502.
     Popraw NPM_NETWORK w .env.dynamic albo: docker network connect ${NPM_NETWORK} ${NPM_C}"
  fi
fi

# --- 7. Zasoby ---------------------------------------------------------------
section "Zasoby"
TOTAL_MB="$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)"
AVAIL_MB="$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)"
NEED_MB=$(( ${#SLUGS[@]} * 450 + 400 ))
echo "     RAM total: ${TOTAL_MB} MB, dostępne: ${AVAIL_MB} MB"
echo "     Szacowane zapotrzebowanie: ${NEED_MB} MB (${#SLUGS[@]} × ~450 MB + Postgres)"
if [ "$AVAIL_MB" -ge "$NEED_MB" ]; then
  c_ok "pamięci wystarczy"
else
  warn_line "może zabraknąć RAM-u — rozważ mniej instancji, większy serwer albo swap"
fi
echo "     CPU: $(nproc 2>/dev/null || echo '?') rdzeni"
echo "     Dysk /: $(df -h / | awk 'NR==2 {print $4" wolne"}')"

# --- Podsumowanie ------------------------------------------------------------
echo ""
echo "════════════════════════════════════════════════════════════════════"
if [ "$ERRORS" -gt 0 ]; then
  echo -e " \033[1;31mBŁĘDY: ${ERRORS}\033[0m, ostrzeżenia: ${WARNS} — napraw przed instalacją."
  echo "════════════════════════════════════════════════════════════════════"
  exit 1
fi
echo -e " \033[1;32mGotowe do instalacji\033[0m (ostrzeżenia: ${WARNS})"
echo " Następny krok:  for i in \$(seq 1 ${#SLUGS[@]}); do bash add-instance.sh user\$i; done"
echo "════════════════════════════════════════════════════════════════════"
