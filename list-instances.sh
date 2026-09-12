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
  status="$(docker inspect -f '{{.State.Status}}' "$cname" 2>/dev/null \
            || docker inspect -f '{{.State.Status}}' "n8n-fleet-n8n-${slug}-1" 2>/dev/null \
            || echo "—")"
  printf "%-14s %-42s %-16s %-10s\n" "$slug" "https://${slug}.${BASE_DOMAIN}" "$cname" "$status"
done

echo ""
if npm_mode; then
  echo "Tryb: nginx-proxy-manager z przodu (Traefik wyłączony)"
  npm_c="$(detect_npm_container || true)"
  echo "  NPM:        ${npm_c:-nie wykryto (ustaw NPM_CONTAINER w .env.dynamic)}"
  SERVICES=(postgres)
else
  echo "Tryb: Traefik jako brzeg sieci (sam wystawia certyfikaty)"
  SERVICES=(postgres traefik)
fi

echo "Infrastruktura:"
for svc in "${SERVICES[@]}"; do
  cname="n8n-fleet-${svc}-1"
  status="$(docker inspect -f '{{.State.Status}}' "$cname" 2>/dev/null || echo "—")"
  printf "  %-12s %s\n" "$svc" "$status"
done
