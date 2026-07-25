#!/usr/bin/env bash
# =============================================================================
# Wspólna biblioteka dla add-instance.sh / remove-instance.sh / list-instances.sh
# =============================================================================
# Nie uruchamiaj bezpośrednio — jest ładowana przez `source`.
# =============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

ENV_DYNAMIC="$ROOT/.env.dynamic"
ENV_INSTANCES="$ROOT/.env.instances"
INSTANCES_DIR="$ROOT/instances"
COMPOSE_BASE="$ROOT/docker-compose.dynamic.yaml"
COMPOSE_NPM="$ROOT/docker-compose.behind-npm.yaml"
ACCESS_CSV="$ROOT/access-list-dynamic.csv"

# Kolory
c_blue()  { echo -e "\n\033[1;34m==>\033[0m $*"; }
c_ok()    { echo -e "\033[1;32m✓\033[0m $*"; }
c_warn()  { echo -e "\033[1;33m!\033[0m $*" >&2; }
c_err()   { echo -e "\033[1;31mBŁĄD:\033[0m $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Wymagania i konfiguracja
# ---------------------------------------------------------------------------
require_env() {
  command -v docker  >/dev/null 2>&1 || c_err "docker nie jest zainstalowany"
  command -v openssl >/dev/null 2>&1 || c_err "openssl nie jest zainstalowany"
  docker compose version >/dev/null 2>&1 || c_err "plugin 'docker compose' nie działa"
  [ -f "$ENV_DYNAMIC" ] || c_err "Brak $ENV_DYNAMIC — skopiuj: cp .env.dynamic.example .env.dynamic i uzupełnij"

  # Wczytaj zmienne bazowe do środowiska (dla operacji na Postgresie po stronie hosta)
  set -a; . "$ENV_DYNAMIC"; set +a

  : "${BASE_DOMAIN:?Ustaw BASE_DOMAIN w .env.dynamic}"
  : "${POSTGRES_USER:?Ustaw POSTGRES_USER w .env.dynamic}"
  : "${N8N_DB_USER:?Ustaw N8N_DB_USER w .env.dynamic}"
  : "${N8N_DB_PASSWORD:?Ustaw N8N_DB_PASSWORD w .env.dynamic}"

  mkdir -p "$INSTANCES_DIR"
  touch "$ENV_INSTANCES"
}

# ---------------------------------------------------------------------------
# Slug: nazwa instancji sprowadzona do bezpiecznej etykiety DNS [a-z0-9-]
# ---------------------------------------------------------------------------
slugify() {
  local s
  s="$(echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//')"
  [ -n "$s" ] || c_err "Pusta lub nieprawidłowa nazwa instancji"
  [ "${#s}" -le 40 ] || c_err "Nazwa zbyt długa (max 40 znaków po normalizacji)"
  echo "$s"
}

# Nazwa zmiennej środowiskowej dla sekretów danej instancji (np. '1' -> '1', 'ala-b' -> 'ALA_B')
envkey() { echo "$1" | tr '[:lower:]-' '[:upper:]_'; }

# ---------------------------------------------------------------------------
# Lista plików compose do złożenia jednego projektu
# ---------------------------------------------------------------------------
compose_args() {
  local args=(-f "$COMPOSE_BASE")
  local f
  for f in "$INSTANCES_DIR"/*.yaml; do
    [ -e "$f" ] && args+=(-f "$f")
  done
  # Override dla trybu "za nginx-proxy-manager" (musi być OSTATNI)
  if [ "${USE_BEHIND_NPM:-0}" = "1" ]; then
    args+=(-f "$COMPOSE_NPM")
  fi
  printf '%s\n' "${args[@]}"
}

# Owijka na docker compose z właściwymi plikami i env-file
dc() {
  local files=()
  mapfile -t files < <(compose_args)
  local envs=(--env-file "$ENV_DYNAMIC")
  [ -s "$ENV_INSTANCES" ] && envs+=(--env-file "$ENV_INSTANCES")
  docker compose "${envs[@]}" "${files[@]}" "$@"
}

# ---------------------------------------------------------------------------
# Postgres — uruchomienie infrastruktury i tworzenie bazy per instancja
# ---------------------------------------------------------------------------
ensure_infra() {
  c_blue "Uruchamiam infrastrukturę (postgres + traefik)..."
  dc up -d postgres traefik

  c_blue "Czekam aż PostgreSQL będzie gotowy..."
  local i
  for i in $(seq 1 30); do
    if dc exec -T postgres pg_isready -U "$POSTGRES_USER" -d postgres >/dev/null 2>&1; then
      c_ok "PostgreSQL gotowy"
      return 0
    fi
    sleep 2
  done
  c_err "PostgreSQL nie wystartował w wyznaczonym czasie"
}

psql_admin() { dc exec -T postgres psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" "$@"; }

ensure_db() {
  local slug="$1" db="n8n_$1"

  # Użytkownik n8n (idempotentnie)
  if ! dc exec -T postgres psql -U "$POSTGRES_USER" -d postgres -tAc \
       "SELECT 1 FROM pg_roles WHERE rolname='${N8N_DB_USER}'" 2>/dev/null | grep -q 1; then
    psql_admin -d postgres -c "CREATE ROLE \"${N8N_DB_USER}\" LOGIN PASSWORD '${N8N_DB_PASSWORD}'"
    c_ok "Utworzono użytkownika bazy '${N8N_DB_USER}'"
  fi

  # Baza danych instancji (idempotentnie)
  if dc exec -T postgres psql -U "$POSTGRES_USER" -d postgres -tAc \
       "SELECT 1 FROM pg_database WHERE datname='${db}'" 2>/dev/null | grep -q 1; then
    c_warn "Baza ${db} już istnieje — pomijam CREATE DATABASE"
  else
    psql_admin -d postgres -c "CREATE DATABASE \"${db}\" OWNER \"${N8N_DB_USER}\""
    c_ok "Utworzono bazę ${db}"
  fi
  psql_admin -d "$db" -c "GRANT ALL ON SCHEMA public TO \"${N8N_DB_USER}\"" >/dev/null
}

drop_db() {
  local db="n8n_$1"
  psql_admin -d postgres -c \
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${db}'" >/dev/null 2>&1 || true
  psql_admin -d postgres -c "DROP DATABASE IF EXISTS \"${db}\"" >/dev/null 2>&1 || true
  c_ok "Usunięto bazę ${db}"
}

# ---------------------------------------------------------------------------
# Sekrety instancji w .env.instances (idempotentnie — istniejące zachowuje)
# ---------------------------------------------------------------------------
ensure_secrets() {
  local slug="$1" ek email pass
  ek="$(envkey "$slug")"

  if grep -q "^N8N_KEY_${ek}=" "$ENV_INSTANCES" 2>/dev/null; then
    c_warn "Sekrety dla '${slug}' już istnieją — zachowuję (klucz szyfrowania bez zmian)"
    return 0
  fi

  local key admin_email admin_pass
  key="$(openssl rand -hex 24)"
  admin_email="${INSTANCE_EMAIL:-admin+${slug}@${BASE_DOMAIN}}"
  admin_pass="$(openssl rand -base64 18 | tr -d '+/=\n' | cut -c1-14)"

  {
    echo "# ── instancja: ${slug} ──"
    echo "N8N_KEY_${ek}=${key}"
    echo "N8N_ADMIN_EMAIL_${ek}=${admin_email}"
    echo "N8N_ADMIN_PASS_${ek}=${admin_pass}"
    echo ""
  } >> "$ENV_INSTANCES"
  c_ok "Wygenerowano sekrety dla '${slug}'"
}

get_secret() { grep -E "^$1=" "$ENV_INSTANCES" | head -1 | cut -d= -f2-; }

remove_secrets() {
  local slug="$1" ek
  ek="$(envkey "$slug")"
  # Usuń blok komentarza + 3 linie + pustą, filtrując po prefiksach
  sed -i -E "/^# ── instancja: ${slug} ──$/d; /^N8N_KEY_${ek}=/d; /^N8N_ADMIN_EMAIL_${ek}=/d; /^N8N_ADMIN_PASS_${ek}=/d" "$ENV_INSTANCES"
  c_ok "Usunięto sekrety instancji '${slug}'"
}

# ---------------------------------------------------------------------------
# Render pliku instances/<slug>.yaml
# ---------------------------------------------------------------------------
render_instance() {
  local slug="$1" ek out
  ek="$(envkey "$slug")"
  out="$INSTANCES_DIR/${slug}.yaml"

  # Etykiety Traefik zależne od trybu SSL
  local router_labels
  if [ "${USE_BEHIND_NPM:-0}" = "1" ]; then
    # SSL terminuje nginx-proxy-manager z przodu; Traefik tylko routuje po http
    router_labels="\
      - traefik.enable=true
      - \"traefik.http.routers.n8n-${slug}.rule=Host(\`${slug}.\${BASE_DOMAIN}\`)\"
      - traefik.http.routers.n8n-${slug}.entrypoints=web
      - traefik.http.services.n8n-${slug}.loadbalancer.server.port=5678"
  else
    # Traefik jest brzegiem i sam wystawia certyfikat Let's Encrypt
    router_labels="\
      - traefik.enable=true
      - \"traefik.http.routers.n8n-${slug}.rule=Host(\`${slug}.\${BASE_DOMAIN}\`)\"
      - traefik.http.routers.n8n-${slug}.entrypoints=websecure
      - traefik.http.routers.n8n-${slug}.tls.certresolver=le
      - traefik.http.services.n8n-${slug}.loadbalancer.server.port=5678"
  fi

  cat > "$out" <<EOF
# Wygenerowano przez add-instance.sh — instancja: ${slug}
# URL: https://${slug}.${BASE_DOMAIN}
# Aby usunąć: bash remove-instance.sh ${slug}
services:
  n8n-${slug}:
    image: docker.n8n.io/n8nio/n8n
    restart: always
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: "5432"
      DB_POSTGRESDB_DATABASE: n8n_${slug}
      DB_POSTGRESDB_USER: \${N8N_DB_USER}
      DB_POSTGRESDB_PASSWORD: \${N8N_DB_PASSWORD}
      N8N_ENCRYPTION_KEY: \${N8N_KEY_${ek}}
      N8N_HOST: ${slug}.\${BASE_DOMAIN}
      N8N_PROTOCOL: https
      N8N_PORT: "5678"
      N8N_PROXY_HOPS: "1"
      WEBHOOK_URL: https://${slug}.\${BASE_DOMAIN}/
      N8N_EDITOR_BASE_URL: https://${slug}.\${BASE_DOMAIN}/
      N8N_SECURE_COOKIE: "true"
      NODE_FUNCTION_ALLOW_BUILTIN: crypto
      N8N_DEFAULT_ADMIN_EMAIL: \${N8N_ADMIN_EMAIL_${ek}}
      N8N_DEFAULT_ADMIN_PASSWORD: \${N8N_ADMIN_PASS_${ek}}
    volumes:
      - n8n_data_${slug}:/home/node/.n8n
    networks:
      - fleet
    labels:
${router_labels}

volumes:
  n8n_data_${slug}:
EOF
  c_ok "Zapisano $out"
}
