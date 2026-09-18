#!/usr/bin/env bash
# =============================================================================
# setup-fleet.sh — JEDNO polecenie: cała flota n8n gotowa do rozdania
# =============================================================================
# Robi po kolei:
#   1. konfiguracja (.env.dynamic — dopyta o brakujące wartości)
#   2. sprawdzenie serwera (DNS, porty, RAM, widoczność nginx-proxy-managera)
#   3. instancje n8n — osobny kontener, baza i klucz szyfrowania na uczestnika
#   4. Proxy Hosty w nginx-proxy-managerze (subdomena + SSL) — jeśli NPM z przodu
#   5. wypis: uczestnik, adres, login, hasło, kontener  (+ plik dostepy.md)
#
# Użycie:
#   bash setup-fleet.sh                          # 16 uczestników: user1..user16
#   bash setup-fleet.sh --count 20               # user1..user20
#   bash setup-fleet.sh --prefix kursant --count 8
#   bash setup-fleet.sh --users ala,bartek,celina
#   bash setup-fleet.sh --users ala=ala@firma.pl,bartek=bartek@firma.pl
#
# Dodatkowo:
#   --skip-npm         nie dotykaj nginx-proxy-managera (hosty założysz ręcznie)
#   --skip-preflight   pomiń sprawdzenie serwera (odradzane)
#   --yes              nie pytaj o potwierdzenie
#
# Skrypt jest idempotentny — można go puścić ponownie. Istniejące instancje
# zachowują swoje hasła, klucze i dane; dokładane są tylko brakujące.
# =============================================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

HANDOUT="$ROOT/dostepy.md"

COUNT=16
PREFIX="user"
USERS_ARG=""
SKIP_NPM=0
SKIP_PREFLIGHT=0
ASSUME_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --count)          COUNT="${2:-}"; shift 2 ;;
    --prefix)         PREFIX="${2:-}"; shift 2 ;;
    --users)          USERS_ARG="${2:-}"; shift 2 ;;
    --skip-npm)       SKIP_NPM=1; shift ;;
    --skip-preflight) SKIP_PREFLIGHT=1; shift ;;
    --yes|-y)         ASSUME_YES=1; shift ;;
    -h|--help)        sed -n '2,30p' "$0"; exit 0 ;;
    *) c_err "Nieznany argument: $1 (zobacz: bash setup-fleet.sh --help)" ;;
  esac
done

# ---------------------------------------------------------------------------
# 1. Konfiguracja
# ---------------------------------------------------------------------------
ask() {  # ask <zmienna> <pytanie> <domyślna>
  local var="$1" question="$2" default="${3:-}" answer=""
  if [ ! -t 0 ]; then
    printf -v "$var" '%s' "$default"
    return 0
  fi
  if [ -n "$default" ]; then
    read -r -p "   ${question} [${default}]: " answer
  else
    read -r -p "   ${question}: " answer
  fi
  printf -v "$var" '%s' "${answer:-$default}"
}

ask_secret() {  # ask_secret <zmienna> <pytanie>
  local var="$1" answer=""
  if [ -t 0 ]; then
    read -r -s -p "   $2: " answer
    echo ""
  fi
  printf -v "$var" '%s' "$answer"
}

create_config() {
  c_blue "Pierwsze uruchomienie — tworzę .env.dynamic"

  local base_domain acme_email npm_network npm_email npm_password npm_url detected
  ask base_domain "Domena bazowa (subdomeny powstaną jako user1.<domena>)" "n8n.easyautomate.pl"
  ask acme_email  "E-mail do certyfikatów Let's Encrypt" ""

  # Sieć docker nginx-proxy-managera — podpowiedz tę, w której faktycznie stoi
  detected="$NPM_NETWORK_DEFAULT"
  local npm_c
  npm_c="$(detect_npm_container || true)"
  if [ -n "$npm_c" ]; then
    local first
    first="$(npm_container_networks "$npm_c" | head -1)"
    [ -n "$first" ] && detected="$first"
    echo "   (wykryty nginx-proxy-manager: ${npm_c}, sieci: $(npm_container_networks "$npm_c" | tr '\n' ' '))"
  fi
  ask npm_network "Sieć docker nginx-proxy-managera" "$detected"

  npm_url="http://127.0.0.1:81"
  echo "   (login do panelu NPM — potrzebny tylko do automatycznego zakładania Proxy Hostów;"
  echo "    zostaw puste, jeśli wolisz wpisać hosty ręcznie)"
  ask        npm_url      "Adres panelu NPM" "$npm_url"
  ask        npm_email    "Login (e-mail) do NPM" ""
  ask_secret npm_password "Hasło do NPM"

  # Znaki specjalne sed-a w hasłach/adresach nie mogą rozwalić podstawienia
  esc() { printf '%s' "$1" | sed -e 's/[\\|&]/\\\\&/g'; }

  umask 077
  sed -e "s|^BASE_DOMAIN=.*|BASE_DOMAIN=$(esc "$base_domain")|" \
      -e "s|^ACME_EMAIL=.*|ACME_EMAIL=$(esc "$acme_email")|" \
      -e "s|^NPM_NETWORK=.*|NPM_NETWORK=$(esc "$npm_network")|" \
      -e "s|^NPM_URL=.*|NPM_URL=$(esc "$npm_url")|" \
      -e "s|^NPM_EMAIL=.*|NPM_EMAIL=$(esc "$npm_email")|" \
      -e "s|^NPM_PASSWORD=.*|NPM_PASSWORD=$(esc "$npm_password")|" \
      -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(openssl rand -hex 16)|" \
      -e "s|^N8N_DB_PASSWORD=.*|N8N_DB_PASSWORD=$(openssl rand -hex 16)|" \
      "$ROOT/.env.dynamic.example" > "$ENV_DYNAMIC"
  chmod 600 "$ENV_DYNAMIC"
  c_ok "Zapisano $ENV_DYNAMIC (hasła do bazy wygenerowane losowo)"
}

[ -f "$ENV_DYNAMIC" ] || create_config

require_env

if grep -v '^[[:space:]]*#' "$ENV_DYNAMIC" | grep -q "CHANGE_ME"; then
  c_err "W $ENV_DYNAMIC zostały wartości CHANGE_ME — uzupełnij je i uruchom ponownie"
fi

# ---------------------------------------------------------------------------
# 2. Lista uczestników
# ---------------------------------------------------------------------------
SLUGS=()
declare -A EMAIL_OF=()

if [ -n "$USERS_ARG" ]; then
  IFS=',' read -r -a RAW <<< "$USERS_ARG"
  for entry in "${RAW[@]}"; do
    entry="$(echo "$entry" | tr -d ' ')"
    [ -n "$entry" ] || continue
    local_slug="$(slugify "${entry%%=*}")"
    SLUGS+=("$local_slug")
    [[ "$entry" == *"="* ]] && EMAIL_OF["$local_slug"]="${entry#*=}"
  done
else
  [[ "$COUNT" =~ ^[0-9]+$ ]] && [ "$COUNT" -ge 1 ] || c_err "--count musi być liczbą dodatnią"
  for i in $(seq 1 "$COUNT"); do SLUGS+=("$(slugify "${PREFIX}${i}")"); done
fi

[ ${#SLUGS[@]} -gt 0 ] || c_err "Pusta lista uczestników — sprawdź --users / --count"

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo " PLAN"
echo "════════════════════════════════════════════════════════════════════"
echo " Uczestników:  ${#SLUGS[@]}"
echo " Adresy:       https://${SLUGS[0]}.${BASE_DOMAIN} ... https://${SLUGS[-1]}.${BASE_DOMAIN}"
echo " Ruch:         nginx-proxy-manager (sieć ${NPM_NETWORK}) -> osobny kontener na subdomenę"
echo " Proxy Hosty:  $([ "$SKIP_NPM" = "1" ] && echo 'pomijam (--skip-npm)' || echo 'zakładam automatycznie')"
echo " Szacowany RAM: ~$(( ${#SLUGS[@]} * 450 + 400 )) MB"
echo "════════════════════════════════════════════════════════════════════"

if [ "$ASSUME_YES" != "1" ] && [ -t 0 ]; then
  read -r -p "Ruszamy? (t/n) [t]: " go
  case "${go:-t}" in [tTyY]*) ;; *) echo "Przerwane."; exit 0 ;; esac
fi

# ---------------------------------------------------------------------------
# 3. Sprawdzenie serwera
# ---------------------------------------------------------------------------
if [ "$SKIP_PREFLIGHT" != "1" ]; then
  if ! bash "$ROOT/preflight.sh" "${SLUGS[@]}"; then
    echo ""
    c_err "Preflight zgłosił błędy — napraw je i uruchom ponownie
   (albo wymuś: bash setup-fleet.sh --skip-preflight)"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Instancje
# ---------------------------------------------------------------------------
c_blue "Stawiam ${#SLUGS[@]} instancji n8n..."
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

i=0
for s in "${SLUGS[@]}"; do
  i=$((i + 1))
  printf "   [%2d/%2d] %-16s " "$i" "${#SLUGS[@]}" "$s"
  if bash "$ROOT/add-instance.sh" "$s" "${EMAIL_OF[$s]:-}" > "$LOG" 2>&1; then
    echo -e "\033[1;32mOK\033[0m"
  else
    echo -e "\033[1;31mBŁĄD\033[0m"
    echo "──────── log instancji '${s}' ────────"
    cat "$LOG"
    echo "──────────────────────────────────────"
    c_err "Instancja '${s}' się nie postawiła — napraw przyczynę i uruchom skrypt ponownie
   (już postawione instancje zostaną pominięte bez utraty danych)"
  fi
done

# ---------------------------------------------------------------------------
# 5. nginx-proxy-manager
# ---------------------------------------------------------------------------
if [ "$SKIP_NPM" != "1" ]; then
  if [ -n "${NPM_EMAIL:-}" ] && [ -n "${NPM_PASSWORD:-}" ]; then
    bash "$ROOT/npm-hosts.sh" --create --update || c_warn "Nie wszystkie Proxy Hosty się założyły — szczegóły wyżej.
   Brakujące dodasz w panelu NPM albo ponownie: bash npm-hosts.sh --create"
  else
    c_warn "Brak NPM_EMAIL/NPM_PASSWORD w .env.dynamic — Proxy Hosty trzeba wpisać ręcznie:"
    bash "$ROOT/npm-hosts.sh"
  fi
fi

# ---------------------------------------------------------------------------
# 6. Dostępy
# ---------------------------------------------------------------------------
{
  echo "# Dostępy do n8n — szkolenie"
  echo ""
  echo "Wygenerowano: $(date '+%Y-%m-%d %H:%M') — ${#SLUGS[@]} uczestników z tego uruchomienia."
  echo "Pełna lista wszystkich instancji na serwerze: access-list-dynamic.csv"
  echo ""
  echo "| Uczestnik | Adres | Login | Hasło | Kontener |"
  echo "|---|---|---|---|---|"
} > "$HANDOUT"

echo ""
RULE="══════════════════════════════════════════════════════════════════════════════════════════════════════"
echo "$RULE"
printf " %-10s %-40s %-34s %-15s %-12s\n" "UCZESTNIK" "ADRES" "LOGIN" "HASŁO" "KONTENER"
echo "${RULE//═/─}"
for s in "${SLUGS[@]}"; do
  ek="$(envkey "$s")"
  email="$(get_secret "N8N_ADMIN_EMAIL_${ek}")"
  pass="$(get_secret "N8N_ADMIN_PASS_${ek}")"
  url="https://${s}.${BASE_DOMAIN}"
  cont="$(container_of "$s")"
  printf " %-10s %-40s %-34s %-15s %-12s\n" "$s" "$url" "$email" "$pass" "$cont"
  echo "| ${s} | ${url} | ${email} | \`${pass}\` | \`${cont}\` |" >> "$HANDOUT"
done
echo "$RULE"

{
  echo ""
  echo "## Do rozesłania (jeden blok = jeden uczestnik)"
  for s in "${SLUGS[@]}"; do
    ek="$(envkey "$s")"
    echo ""
    echo "### ${s}"
    echo ""
    echo "- Adres: https://${s}.${BASE_DOMAIN}"
    echo "- Login: $(get_secret "N8N_ADMIN_EMAIL_${ek}")"
    echo "- Hasło: $(get_secret "N8N_ADMIN_PASS_${ek}")"
  done
} >> "$HANDOUT"
chmod 600 "$HANDOUT"

echo ""
c_ok "Dostępy do rozesłania:  ${HANDOUT}"
c_ok "Ten sam zestaw w CSV:   ${ACCESS_CSV}"
echo ""
echo " Kontenery:        docker ps --filter name=n8n-"
echo " Status floty:     bash list-instances.sh"
echo " Logi uczestnika:  docker logs $(container_of "${SLUGS[0]}")"
echo " Dodać kogoś:      bash add-instance.sh ${PREFIX}$(( ${#SLUGS[@]} + 1 )) && bash npm-hosts.sh --create"
echo ""
echo " Zanim rozdasz dostępy: wejdź na https://${SLUGS[0]}.${BASE_DOMAIN} i sprawdź, czy login"
echo " z tabeli działa. Część wersji n8n zakłada konto właściciela dopiero przy pierwszym"
echo " wejściu w przeglądarce — wtedy pierwszym punktem agendy jest założenie konta."
echo ""
