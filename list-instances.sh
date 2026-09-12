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

printf "%-14s %-42s %-16s %-10s\n" "INSTANCJA" "URL" "KONTENER" "STATUS"
printf "%-14s %-42s %-16s %-10s\n" "--------------" "------------------------------------------" "----------------" "----------"

for f in "${FILES[@]}"; do
  slug="$(basename "$f" .yaml)"
  cname="$(container_of "$slug")"
  status="$(container_status "$cname")"
  printf "%-14s %-42s %-16s %-10s\n" "$slug" "https://${slug}.${BASE_DOMAIN}" "$cname" "$status"
done

echo ""
echo "Infrastruktura:"
status="$(container_status "n8n-fleet-postgres-1")"
printf "  %-12s %s\n" "postgres" "$status"

npm_c="$(detect_npm_container || true)"
printf "  %-12s %s\n" "npm" "${npm_c:-nie wykryto (ustaw NPM_CONTAINER w .env.dynamic)}"
printf "  %-12s %s\n" "sieć npm" "${NPM_NETWORK}$(docker network inspect "$NPM_NETWORK" >/dev/null 2>&1 && echo "" || echo "  ← nie istnieje!")"
[ -n "$npm_c" ] && warn_if_npm_elsewhere || true
