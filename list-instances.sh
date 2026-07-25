#!/usr/bin/env bash
# =============================================================================
# list-instances.sh — pokazuje wszystkie zdefiniowane instancje i ich status
# =============================================================================
# Użycie:  bash list-instances.sh
# =============================================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

require_env

shopt -s nullglob
FILES=("$INSTANCES_DIR"/*.yaml)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "Brak zdefiniowanych instancji. Dodaj pierwszą:  bash add-instance.sh 1"
  exit 0
fi

printf "%-16s %-45s %-12s\n" "INSTANCJA" "URL" "STATUS"
printf "%-16s %-45s %-12s\n" "----------------" "---------------------------------------------" "------------"

for f in "${FILES[@]}"; do
  slug="$(basename "$f" .yaml)"
  cname="n8n-fleet-n8n-${slug}-1"
  status="$(docker inspect -f '{{.State.Status}}' "$cname" 2>/dev/null || echo "—")"
  printf "%-16s %-45s %-12s\n" "$slug" "https://${slug}.${BASE_DOMAIN}" "$status"
done

echo ""
echo "Infrastruktura:"
for svc in postgres traefik; do
  cname="n8n-fleet-${svc}-1"
  status="$(docker inspect -f '{{.State.Status}}' "$cname" 2>/dev/null || echo "—")"
  printf "  %-12s %s\n" "$svc" "$status"
done
