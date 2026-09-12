#!/usr/bin/env bash
# =============================================================================
# Wspólna biblioteka dla add-instance.sh / remove-instance.sh / list-instances.sh
# / npm-hosts.sh / preflight.sh / setup-fleet.sh
# =============================================================================
# Nie uruchamiaj bezpośrednio — jest ładowana przez `source`.
#
# Układ: frontem jest nginx-proxy-manager. Kieruje ruch po nazwie domeny
# do kontenera danego uczestnika, w sieci NPM-a:
#
#   user1.<BASE_DOMAIN>  ->  n8n-user1:5678
#
# Kontenery n8n NIE publikują portów na hosta — port 5678 jest tylko
# wystawiony (expose) wewnątrz sieci docker.
# =============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

ENV_DYNAMIC="$ROOT/.env.dynamic"
ENV_INSTANCES="$ROOT/.env.instances"
INSTANCES_DIR="$ROOT/instances"
COMPOSE_BASE="$ROOT/docker-compose.dynamic.yaml"
ACCESS_CSV="$ROOT/access-list-dynamic.csv"

# Sieć, w której stoi nginx-proxy-manager (tworzy ją compose NPM-a)
NPM_NETWORK_DEFAULT="nginx-proxy-manager_default"

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

  export NPM_NETWORK="${NPM_NETWORK:-$NPM_NETWORK_DEFAULT}"

  mkdir -p "$INSTANCES_DIR"
  touch "$ENV_INSTANCES"
}

# ---------------------------------------------------------------------------
# Nazewnictwo
# ---------------------------------------------------------------------------
# Slug: nazwa instancji sprowadzona do bezpiecznej etykiety DNS [a-z0-9-]
slugify() {
  local s
  s="$(echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//')"
  [ -n "$s" ] || c_err "Pusta lub nieprawidłowa nazwa instancji"
  [ "${#s}" -le 40 ] || c_err "Nazwa zbyt długa (max 40 znaków po normalizacji)"
  echo "$s"
}

# Nazwa zmiennej środowiskowej dla sekretów danej instancji ('ala-b' -> 'ALA_B')
envkey() { echo "$1" | tr '[:lower:]-' '[:upper:]_'; }

# Nazwa kontenera instancji — to samo wpisuje się w NPM jako Forward Hostname
container_of() { echo "n8n-$1"; }

# Status kontenera ('running', 'exited', ...) albo '—', gdy go nie ma
container_status() {
  local st
  st="$(docker inspect -f '{{.State.Status}}' "$1" 2>/dev/null | tr -d '[:space:]')"
  echo "${st:-—}"
}

# ---------------------------------------------------------------------------
# Sieć nginx-proxy-managera
# ---------------------------------------------------------------------------
detect_npm_container() {
  if [ -n "${NPM_CONTAINER:-}" ]; then
    echo "$NPM_CONTAINER"
    return 0
  fi
  docker ps --format '{{.Names}}\t{{.Image}}' 2>/dev/null \
    | awk -F'\t' 'tolower($2) ~ /nginx-?proxy-?manager/ { print $1; exit }'
}

# Sieci, do których podpięty jest kontener NPM
npm_container_networks() {
  local c="$1"
  docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' "$c" 2>/dev/null \
    | grep -v '^$' || true
}

# Sprawdza, że sieć NPM istnieje; jeśli nie — podpowiada właściwą nazwę
check_npm_network() {
  if docker network inspect "$NPM_NETWORK" >/dev/null 2>&1; then
    return 0
  fi

  local c candidates=""
  c="$(detect_npm_container || true)"
  [ -n "$c" ] && candidates="$(npm_container_networks "$c")"

  {
    echo "Sieć docker '${NPM_NETWORK}' nie istnieje."
    if [ -n "$candidates" ]; then
      echo "Kontener nginx-proxy-manager ('${c}') jest w sieci/sieciach:"
      echo "$candidates" | sed 's/^/     - /'
      echo "Wpisz właściwą do .env.dynamic:  NPM_NETWORK=<nazwa>"
    else
      echo "Sprawdź nazwę:  docker network ls"
      echo "i wpisz ją do .env.dynamic:  NPM_NETWORK=<nazwa>"
    fi
  } >&2
  exit 1
}

# Ostrzega, gdy NPM stoi w innej sieci niż ta, do której wpinamy instancje
warn_if_npm_elsewhere() {
  local c nets
  c="$(detect_npm_container || true)"
  [ -n "$c" ] || return 0
  nets="$(npm_container_networks "$c")"
  if ! echo "$nets" | grep -qx "$NPM_NETWORK"; then
    c_warn "Kontener NPM ('${c}') nie jest w sieci '${NPM_NETWORK}' — dostaniesz 502.
   Jego sieci: $(echo "$nets" | tr '\n' ' ')
   Popraw NPM_NETWORK w .env.dynamic albo podłącz go: docker network connect ${NPM_NETWORK} ${c}"
  fi
}

# ---------------------------------------------------------------------------
# Lista plików compose do złożenia jednego projektu
# ---------------------------------------------------------------------------
compose_args() {
  local args=(-f "$COMPOSE_BASE")
  local f
  for f in "$INSTANCES_DIR"/*.yaml; do
    [ -e "$f" ] && args+=(-f "$f")
  done
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
  check_npm_network

  c_blue "Uruchamiam infrastrukturę (PostgreSQL)..."
  dc up -d postgres

  c_blue "Czekam aż PostgreSQL będzie gotowy..."
  local i
  for i in $(seq 1 30); do
    if dc exec -T postgres pg_isready -U "$POSTGRES_USER" -d postgres >/dev/null 2>&1; then
      c_ok "PostgreSQL gotowy"
      warn_if_npm_elsewhere
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
  local slug="$1" ek
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
  sed -i -E "/^# ── instancja: ${slug} ──$/d; /^N8N_KEY_${ek}=/d; /^N8N_ADMIN_EMAIL_${ek}=/d; /^N8N_ADMIN_PASS_${ek}=/d" "$ENV_INSTANCES"
  c_ok "Usunięto sekrety instancji '${slug}'"
}

# ---------------------------------------------------------------------------
# Render pliku instances/<slug>.yaml
# ---------------------------------------------------------------------------
# Kontener stoi w dwóch sieciach:
#   - internal — prywatna, tylko n8n <-> PostgreSQL,
#   - npm      — sieć nginx-proxy-managera, żeby NPM mógł go dosięgnąć po nazwie.
# Port 5678 jest tylko wystawiony (expose), nie publikowany na hosta.
# ---------------------------------------------------------------------------
render_instance() {
  local slug="$1" ek out
  ek="$(envkey "$slug")"
  out="$INSTANCES_DIR/${slug}.yaml"

  cat > "$out" <<EOF
# Wygenerowano przez add-instance.sh — instancja: ${slug}
# URL: https://${slug}.${BASE_DOMAIN}
# W nginx-proxy-manager:  Forward Hostname: n8n-${slug}   Forward Port: 5678
# Aby usunąć: bash remove-instance.sh ${slug}
services:
  n8n-${slug}:
    image: docker.n8n.io/n8nio/n8n
    container_name: n8n-${slug}
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
    expose:
      - "5678"
    volumes:
      - n8n_data_${slug}:/home/node/.n8n
    networks:
      - internal
      - npm

volumes:
  n8n_data_${slug}:
EOF
  c_ok "Zapisano $out"
}
