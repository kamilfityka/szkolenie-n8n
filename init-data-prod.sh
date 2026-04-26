#!/bin/bash

# Tworzy jednego użytkownika n8n oraz 20 osobnych baz danych (po jednej per uczestnik).
# Zmienne N8N_DB_USER i N8N_DB_PASSWORD muszą być ustawione w środowisku kontenera.
# Skrypt jest idempotentny — bezpieczny przy ponownym uruchomieniu z istniejącym woluminem.

if [ -z "${N8N_DB_USER:-}" ] || [ -z "${N8N_DB_PASSWORD:-}" ]; then
  echo "SETUP ERROR: N8N_DB_USER lub N8N_DB_PASSWORD nie są ustawione!"
  exit 1
fi

echo "SETUP START: tworzę użytkownika '${N8N_DB_USER}' (POSTGRES_USER='${POSTGRES_USER}')..."

# Utwórz użytkownika; jeśli już istnieje — zaktualizuj hasło.
# --dbname postgres wymagane: psql domyślnie łączy się z bazą o nazwie równej nazwie użytkownika.
if psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
     -c "CREATE USER ${N8N_DB_USER} WITH PASSWORD '${N8N_DB_PASSWORD}';"; then
  echo "Użytkownik '${N8N_DB_USER}' utworzony."
else
  echo "CREATE USER nie powiodło się (użytkownik już istnieje lub błąd). Próbuję ALTER USER..."
  if ! psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
       -c "ALTER USER ${N8N_DB_USER} WITH PASSWORD '${N8N_DB_PASSWORD}';"; then
    echo "SETUP ERROR: nie można utworzyć ani zaktualizować użytkownika '${N8N_DB_USER}'!"
    exit 1
  fi
  echo "Hasło użytkownika '${N8N_DB_USER}' zaktualizowane."
fi

for i in $(seq -w 1 20); do
  DB="n8n_${i}"
  echo "Tworzę bazę: $DB"
  psql --username "$POSTGRES_USER" --dbname postgres -c "CREATE DATABASE ${DB};" 2>/dev/null || true
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
    -c "GRANT ALL PRIVILEGES ON DATABASE ${DB} TO ${N8N_DB_USER};"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB" \
    -c "GRANT CREATE ON SCHEMA public TO ${N8N_DB_USER};"
done

echo "SETUP DONE: utworzono użytkownika '${N8N_DB_USER}' i 20 baz danych n8n_01…n8n_20."
