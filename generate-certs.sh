#!/usr/bin/env bash
# Generuje self-signed certyfikat SSL dla wszystkich 22 instancji n8n.
# Użycie: bash generate-certs.sh [IP_SERWERA]
# Przykład: bash generate-certs.sh 51.83.32.60

set -euo pipefail

VPS_IP="${1:-}"

if [[ -z "$VPS_IP" ]]; then
    # Spróbuj odczytać z .env.prod
    if [[ -f ".env.prod" ]]; then
        VPS_IP=$(grep -E '^VPS_IP=' .env.prod | cut -d= -f2 | tr -d '"' | tr -d "'")
    fi
fi

if [[ -z "$VPS_IP" || "$VPS_IP" == "CHANGE_ME" ]]; then
    echo "Błąd: Podaj IP serwera jako argument lub ustaw VPS_IP w .env.prod"
    echo "Użycie: bash generate-certs.sh 51.83.32.60"
    exit 1
fi

CERT_DIR="nginx/certs"
mkdir -p "$CERT_DIR"

echo "Generuję self-signed certyfikat SSL dla IP: $VPS_IP ..."

openssl req -x509 -nodes -newkey rsa:2048 \
    -days 365 \
    -keyout "$CERT_DIR/key.pem" \
    -out "$CERT_DIR/cert.pem" \
    -subj "/CN=$VPS_IP/O=Szkolenie n8n/C=PL" \
    -addext "subjectAltName=IP:$VPS_IP"

chmod 600 "$CERT_DIR/key.pem"

echo ""
echo "Certyfikat wygenerowany:"
echo "  $CERT_DIR/cert.pem"
echo "  $CERT_DIR/key.pem"
echo ""
echo "Ważność: 365 dni"
echo ""
echo "Instancje HTTPS (uczestnicy):"
for i in $(seq 1 22); do
    printf "  Uczestnik %02d → https://%s:90%02d\n" "$i" "$VPS_IP" "$i"
done
echo ""
echo "UWAGA: Przeglądarka pokaże ostrzeżenie o self-signed cert."
echo "Kliknij 'Zaawansowane' → 'Przejdź do strony' (lub dodaj wyjątek)."
