#!/bin/bash
# Czyta participants.csv i generuje:
#   .env.prod       — zmienne dla docker-compose.prod.yaml (NIE commituj!)
#   access-list.txt — tabela URL / email / hasło dla uczestników
set -eu
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi

CSV="participants.csv"
ENV_OUT=".env.prod"
ACCESS_OUT="access-list.txt"
BASE_PORT=5678

command -v openssl >/dev/null 2>&1 || { echo "BŁĄD: openssl nie jest zainstalowany"; exit 1; }
[ -f "$CSV" ] || { echo "BŁĄD: brak pliku $CSV"; exit 1; }

if [ -f "$ENV_OUT" ]; then
  read -rp "$ENV_OUT już istnieje. Nadpisać? (t/N) " ans
  [[ "$ans" =~ ^[tT]$ ]] || { echo "Anulowano."; exit 0; }
fi

PG_PASS=$(openssl rand -hex 16)
N8N_DB_PASS=$(openssl rand -hex 16)

cat > "$ENV_OUT" <<EOF
# Wygenerowano: $(date)
# Źródło: $CSV
# !! NIE commituj tego pliku do repozytorium !!

POSTGRES_USER=postgres_admin
POSTGRES_PASSWORD=${PG_PASS}
N8N_DB_USER=n8n_user
N8N_DB_PASSWORD=${N8N_DB_PASS}

# Ustaw publiczny adres IP lub domenę serwera (bez http://, bez portu):
VPS_IP=51.83.32.60

EOF

cat > "$ACCESS_OUT" <<EOF
Lista dostępów — SZKOLENIE n8n
Wygenerowano: $(date)

Nr  Imię i Nazwisko        URL (HTTPS)                       Login (e-mail)                Hasło
--- ---------------------- --------------------------------- ----------------------------- ----------------
EOF

while IFS=, read -r nr name email; do
  # pomiń nagłówek i puste linie
  [[ "$nr" =~ ^[[:space:]]*(nr|#) ]] && continue
  [[ -z "${nr// }" ]] && continue

  NUM=$(printf '%02d' $((10#${nr// })))
  PORT=$(( BASE_PORT + 10#${nr// } - 1 ))
  KEY=$(openssl rand -hex 24)
  PASS=$(openssl rand -base64 18 | tr -d '+/=\n' | cut -c1-14)
  EMAIL="${email// }"
  NAME="${name}"

  cat >> "$ENV_OUT" <<EOF
# ── Uczestnik ${NUM}: ${NAME} ──────────────────────────────────────────
N8N_${NUM}_ENCRYPTION_KEY=${KEY}
N8N_${NUM}_ADMIN_EMAIL=${EMAIL}
N8N_${NUM}_ADMIN_PASSWORD=${PASS}

EOF

  URL="https://VPS_IP/${NUM}/"
  printf "%-3s %-22s %-33s %-29s %s\n" \
    "${NUM}" "${NAME}" "${URL}" "${EMAIL}" "${PASS}" >> "$ACCESS_OUT"

done < "$CSV"

cat >> "$ACCESS_OUT" <<'EOF'

─────────────────────────────────────────────────────────────────────────────
Zastąp VPS_IP rzeczywistym adresem IP serwera przed wysłaniem uczestnikom.
EOF

# Podstaw VPS_IP w access-list.txt rzeczywistym adresem z .env.prod
VPS_IP_VAL=$(grep -E '^VPS_IP=' "$ENV_OUT" | cut -d= -f2 | tr -d '"' | tr -d "'")
if [ -n "$VPS_IP_VAL" ] && [ "$VPS_IP_VAL" != "CHANGE_ME" ]; then
  sed -i "s|VPS_IP|${VPS_IP_VAL}|g" "$ACCESS_OUT"
fi

echo ""
echo "────────────────────────────────────────────"
echo "Wygenerowano:"
echo "  $ENV_OUT"
echo "  $ACCESS_OUT"
echo ""
echo "NASTĘPNE KROKI:"
echo "  1. Sprawdź VPS_IP w $ENV_OUT (obecnie: ${VPS_IP_VAL:-CHANGE_ME})"
echo "  2. bash generate-certs.sh           # certyfikat SSL"
echo "  3. docker compose -f docker-compose.prod.yaml --env-file .env.prod up -d"
echo "────────────────────────────────────────────"
