#!/usr/bin/env bash
# =============================================================================
# npm-hosts.sh — Proxy Hosty w nginx-proxy-manager dla całej floty n8n
# =============================================================================
# Każda subdomena = osobny kontener. Ten skrypt pokazuje (lub zakłada przez API)
# po jednym Proxy Hoście na instancję:
#
#   userN.<BASE_DOMAIN>  ->  http://n8n-userN:5678   (+ Websockets + Let's Encrypt)
#
# Użycie:
#   bash npm-hosts.sh                 # tylko wypisz, co wpisać w NPM (nic nie zmienia)
#   bash npm-hosts.sh --create        # załóż brakujące Proxy Hosty przez API NPM
#   bash npm-hosts.sh --create --no-ssl   # bez zamawiania certyfikatów
#
# Dane logowania do API bierze z .env.dynamic:
#   NPM_URL=http://127.0.0.1:81
#   NPM_EMAIL=admin@example.com
#   NPM_PASSWORD=...
# =============================================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

require_env

CREATE=0
WANT_SSL=1
for a in "$@"; do
  case "$a" in
    --create) CREATE=1 ;;
    --no-ssl) WANT_SSL=0 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) c_err "Nieznany argument: $a (dozwolone: --create, --no-ssl)" ;;
  esac
done

shopt -s nullglob
FILES=("$INSTANCES_DIR"/*.yaml)
[ ${#FILES[@]} -gt 0 ] || c_err "Brak instancji. Dodaj pierwszą:  bash add-instance.sh user1"

SLUGS=()
for f in "${FILES[@]}"; do SLUGS+=("$(basename "$f" .yaml)"); done

warn_if_npm_elsewhere

# ---------------------------------------------------------------------------
# Podgląd
# ---------------------------------------------------------------------------
echo ""
printf "%-38s %-18s %-6s\n" "DOMAIN NAMES" "FORWARD HOSTNAME" "PORT"
printf "%-38s %-18s %-6s\n" "--------------------------------------" "------------------" "------"
for s in "${SLUGS[@]}"; do
  printf "%-38s %-18s %-6s\n" "${s}.${BASE_DOMAIN}" "$(container_of "$s")" "5678"
done
echo ""
echo "Dla każdego hosta w NPM: Scheme=http, Websockets Support=ON, Block Common Exploits=ON,"
echo "zakładka SSL: Let's Encrypt + Force SSL."
echo ""

if [ "$CREATE" != "1" ]; then
  echo "To był tylko podgląd. Aby założyć te hosty automatycznie:  bash npm-hosts.sh --create"
  exit 0
fi

# ---------------------------------------------------------------------------
# Zakładanie przez API NPM
# ---------------------------------------------------------------------------
command -v python3 >/dev/null 2>&1 || c_err "Do trybu --create potrzebny jest python3"
command -v curl    >/dev/null 2>&1 || c_err "Do trybu --create potrzebny jest curl"

: "${NPM_URL:=http://127.0.0.1:81}"
[ -n "${NPM_EMAIL:-}" ]    || c_err "Ustaw NPM_EMAIL w .env.dynamic (login do panelu nginx-proxy-manager)"
[ -n "${NPM_PASSWORD:-}" ] || c_err "Ustaw NPM_PASSWORD w .env.dynamic"
: "${ACME_EMAIL:=$NPM_EMAIL}"

c_blue "Zakładam Proxy Hosty w nginx-proxy-manager (${NPM_URL})..."

NPM_URL="$NPM_URL" NPM_EMAIL="$NPM_EMAIL" NPM_PASSWORD="$NPM_PASSWORD" \
ACME_EMAIL="$ACME_EMAIL" BASE_DOMAIN="$BASE_DOMAIN" WANT_SSL="$WANT_SSL" \
SLUGS="${SLUGS[*]}" python3 - <<'PY'
import json, os, urllib.error, urllib.request

BASE   = os.environ["NPM_URL"].rstrip("/")
DOMAIN = os.environ["BASE_DOMAIN"]
SSL    = os.environ["WANT_SSL"] == "1"
SLUGS  = os.environ["SLUGS"].split()

GREEN, YELLOW, RED, OFF = "\033[1;32m", "\033[1;33m", "\033[1;31m", "\033[0m"
ok   = lambda m: print(f"{GREEN}✓{OFF} {m}")
warn = lambda m: print(f"{YELLOW}!{OFF} {m}")
bad  = lambda m: print(f"{RED}✗{OFF} {m}")


def call(path, payload=None, token=None, method=None):
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(payload).encode() if payload is not None else None,
        method=method or ("POST" if payload is not None else "GET"),
    )
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            body = r.read().decode()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode()[:400]
        raise RuntimeError(f"HTTP {e.code}: {detail}") from None
    except urllib.error.URLError as e:
        raise RuntimeError(f"brak połączenia z {BASE} ({e.reason})") from None


try:
    token = call("/api/tokens", {
        "identity": os.environ["NPM_EMAIL"],
        "secret": os.environ["NPM_PASSWORD"],
    })["token"]
except RuntimeError as e:
    bad(f"Logowanie do API nginx-proxy-manager nie powiodło się: {e}")
    print("   Sprawdź NPM_URL / NPM_EMAIL / NPM_PASSWORD w .env.dynamic.")
    raise SystemExit(1)
ok("Zalogowano do API nginx-proxy-manager")

existing = {}
for h in call("/api/nginx/proxy-hosts", token=token):
    for d in h.get("domain_names", []):
        existing[d] = h["id"]

created = skipped = failed = 0

for slug in SLUGS:
    fqdn = f"{slug}.{DOMAIN}"
    if fqdn in existing:
        warn(f"{fqdn} — Proxy Host już istnieje (id={existing[fqdn]}), pomijam")
        skipped += 1
        continue

    cert_id = 0
    if SSL:
        try:
            cert = call("/api/nginx/certificates", {
                "provider": "letsencrypt",
                "nice_name": fqdn,
                "domain_names": [fqdn],
                "meta": {
                    "letsencrypt_email": os.environ["ACME_EMAIL"],
                    "letsencrypt_agree": True,
                    "dns_challenge": False,
                },
            }, token=token)
            cert_id = cert["id"]
        except RuntimeError as e:
            warn(f"{fqdn} — certyfikat się nie udał ({e}); zakładam host po HTTP, "
                 f"cert zamówisz w panelu ('Request a new SSL Certificate')")

    try:
        call("/api/nginx/proxy-hosts", {
            "domain_names": [fqdn],
            "forward_scheme": "http",
            "forward_host": f"n8n-{slug}",
            "forward_port": 5678,
            "allow_websocket_upgrade": True,   # n8n bez tego nie działa poprawnie
            "block_exploits": True,
            "caching_enabled": False,
            "http2_support": True,
            "certificate_id": cert_id,
            "ssl_forced": bool(cert_id),
            "hsts_enabled": False,
            "hsts_subdomains": False,
            "access_list_id": 0,
            "advanced_config": "",
            "locations": [],
            "meta": {"letsencrypt_agree": False, "dns_challenge": False},
        }, token=token)
        ok(f"{fqdn} -> n8n-{slug}:5678" + ("  (SSL)" if cert_id else "  (bez SSL)"))
        created += 1
    except RuntimeError as e:
        bad(f"{fqdn} — nie udało się założyć Proxy Hosta: {e}")
        failed += 1

print(f"\nPodsumowanie: utworzone={created}, pominięte={skipped}, błędy={failed}")
raise SystemExit(1 if failed else 0)
PY
