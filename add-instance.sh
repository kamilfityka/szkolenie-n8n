#!/usr/bin/env bash
# =============================================================================
# add-instance.sh — dodaje pojedynczą instancję n8n z własną subdomeną i SSL
# =============================================================================
# Użycie:
#   bash add-instance.sh <nazwa> [email-admina]
#
# Przykłady:
#   bash add-instance.sh 1                      # -> https://1.<BASE_DOMAIN>
#   bash add-instance.sh ala ala@firma.pl       # -> https://ala.<BASE_DOMAIN>
#   for i in $(seq 1 20); do bash add-instance.sh $i; done   # hurtowo 20 sztuk
#
# Tryb za nginx-proxy-manager:
#   USE_BEHIND_NPM=1 bash add-instance.sh 1
# =============================================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

[ $# -ge 1 ] || c_err "Podaj nazwę instancji, np: bash add-instance.sh 1"

require_env

SLUG="$(slugify "$1")"
export INSTANCE_EMAIL="${2:-}"

c_blue "Dodaję instancję '${SLUG}' → https://${SLUG}.${BASE_DOMAIN}"

if [ -f "$INSTANCES_DIR/${SLUG}.yaml" ]; then
  c_warn "Instancja '${SLUG}' już zdefiniowana — odświeżam konfigurację i podnoszę kontener"
fi

ensure_infra
ensure_db "$SLUG"
ensure_secrets "$SLUG"
render_instance "$SLUG"

c_blue "Podnoszę kontener n8n-${SLUG}..."
dc up -d "n8n-${SLUG}"

# --- CSV z dostępami --------------------------------------------------------
EK="$(envkey "$SLUG")"
EMAIL="$(get_secret "N8N_ADMIN_EMAIL_${EK}")"
PASS="$(get_secret "N8N_ADMIN_PASS_${EK}")"
URL="https://${SLUG}.${BASE_DOMAIN}"

if [ ! -f "$ACCESS_CSV" ]; then
  echo "name,url,email,password" > "$ACCESS_CSV"
fi
# Usuń ewentualny stary wpis i dopisz aktualny
grep -v -E "^\"?${SLUG}\"?," "$ACCESS_CSV" > "${ACCESS_CSV}.tmp" 2>/dev/null || true
mv "${ACCESS_CSV}.tmp" "$ACCESS_CSV" 2>/dev/null || true
echo "\"${SLUG}\",\"${URL}\",\"${EMAIL}\",\"${PASS}\"" >> "$ACCESS_CSV"

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo " GOTOWE — instancja '${SLUG}'"
echo "════════════════════════════════════════════════════════════════════"
echo " URL:      ${URL}"
echo " Login:    ${EMAIL}"
echo " Hasło:    ${PASS}"
echo " Dostępy:  ${ACCESS_CSV}"
echo "────────────────────────────────────────────────────────────────────"
echo " Uwaga: pierwszy certyfikat SSL Let's Encrypt może pojawić się po"
echo " kilkunastu sekundach od pierwszego wejścia na URL (wyzwanie HTTP-01)."
echo " Warunek: rekord DNS  *.${BASE_DOMAIN}  wskazuje na IP tego serwera,"
echo " a porty 80/443 są otwarte."
echo "════════════════════════════════════════════════════════════════════"
