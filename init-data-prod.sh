#!/bin/bash
set -e

# Tworzy jednego użytkownika n8n oraz 20 osobnych baz danych (po jednej per uczestnik).
# Zmienne N8N_DB_USER i N8N_DB_PASSWORD muszą być ustawione w środowisku kontenera.

if [ -z "${N8N_DB_USER:-}" ] || [ -z "${N8N_DB_PASSWORD:-}" ]; then
  echo "SETUP ERROR: N8N_DB_USER lub N8N_DB_PASSWORD nie są ustawione!"
  exit 1
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
  CREATE USER ${N8N_DB_USER} WITH PASSWORD '${N8N_DB_PASSWORD}';
EOSQL

for i in $(seq -w 1 20); do
  DB="n8n_${i}"
  echo "Tworzę bazę: $DB"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE ${DB};
    GRANT ALL PRIVILEGES ON DATABASE ${DB} TO ${N8N_DB_USER};
EOSQL
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB" <<-EOSQL
    GRANT CREATE ON SCHEMA public TO ${N8N_DB_USER};
EOSQL
done

echo "SETUP DONE: utworzono użytkownika '${N8N_DB_USER}' i 20 baz danych n8n_01…n8n_20."
