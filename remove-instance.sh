#!/usr/bin/env bash
# =============================================================================
# remove-instance.sh — usuwa instancję n8n
# =============================================================================
# Użycie:
#   bash remove-instance.sh <nazwa>            # zatrzymuje i usuwa kontener,
#                                              # ZOSTAWIA dane (baza + wolumen)
#   bash remove-instance.sh <nazwa> --purge    # usuwa TAKŻE bazę, wolumen i sekrety
#
# --purge kasuje dane BEZPOWROTNIE (workflowy, credentiale danej instancji).
# =============================================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

[ $# -ge 1 ] || c_err "Podaj nazwę instancji, np: bash remove-instance.sh 1"

require_env

SLUG="$(slugify "$1")"
PURGE=0
[ "${2:-}" = "--purge" ] && PURGE=1

FILE="$INSTANCES_DIR/${SLUG}.yaml"
[ -f "$FILE" ] || c_warn "Brak pliku ${FILE} — spróbuję i tak usunąć kontener/wolumen"

c_blue "Zatrzymuję i usuwam kontener n8n-${SLUG}..."
dc rm -sf "n8n-${SLUG}" 2>/dev/null || docker rm -f "n8n-fleet-n8n-${SLUG}-1" 2>/dev/null || true

# Usuń definicję instancji, żeby nie wróciła przy kolejnym `up`
rm -f "$FILE"
c_ok "Usunięto definicję ${FILE}"

# Wyczyść wpis w CSV
if [ -f "$ACCESS_CSV" ]; then
  grep -v -E "^\"?${SLUG}\"?," "$ACCESS_CSV" > "${ACCESS_CSV}.tmp" 2>/dev/null || true
  mv "${ACCESS_CSV}.tmp" "$ACCESS_CSV" 2>/dev/null || true
fi

if [ "$PURGE" = "1" ]; then
  c_warn "PURGE: kasuję dane instancji '${SLUG}' bezpowrotnie"
  drop_db "$SLUG"
  docker volume rm "n8n-fleet_n8n_data_${SLUG}" 2>/dev/null || \
    c_warn "Nie znaleziono wolumenu n8n-fleet_n8n_data_${SLUG} (mógł już nie istnieć)"
  remove_secrets "$SLUG"
  c_ok "Instancja '${SLUG}' całkowicie usunięta"
else
  echo ""
  c_ok "Kontener '${SLUG}' usunięty. Dane (baza n8n_${SLUG} + wolumen + sekrety) ZACHOWANE."
  echo "   Aby przywrócić: bash add-instance.sh ${SLUG}"
  echo "   Aby skasować dane na stałe: bash remove-instance.sh ${SLUG} --purge"
fi
