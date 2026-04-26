#!/bin/bash
set -e

# Tworzy jednego użytkownika n8n oraz 20 osobnych baz danych (po jednej per uczestnik).
# Zmienne N8N_DB_USER i N8N_DB_PASSWORD muszą być ustawione w środowisku kontenera.

if [ -z "${N8N_DB_USER:-}" ] || [ -z "${N8N_DB_PASSWORD:-}" ]; then
  echo "SETUP ERROR: N8N_DB_USER lub N8N_DB_PASSWORD nie są ustawione!"
  exit 1
fi

echo "SETUP START: tworzę użytkownika '${N8N_DB_USER}'..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
	DO \$\$
	BEGIN
	  IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '${N8N_DB_USER}') THEN
	    CREATE USER ${N8N_DB_USER} WITH PASSWORD '${N8N_DB_PASSWORD}';
	    RAISE NOTICE 'Użytkownik % utworzony.', '${N8N_DB_USER}';
	  ELSE
	    ALTER USER ${N8N_DB_USER} WITH PASSWORD '${N8N_DB_PASSWORD}';
	    RAISE NOTICE 'Użytkownik % już istniał — zaktualizowano hasło.', '${N8N_DB_USER}';
	  END IF;
	END
	\$\$;
EOSQL

for i in $(seq -w 1 20); do
  DB="n8n_${i}"
  echo "Tworzę bazę: $DB"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
	SELECT 'CREATE DATABASE ${DB}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB}')\gexec
	GRANT ALL PRIVILEGES ON DATABASE ${DB} TO ${N8N_DB_USER};
EOSQL
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB" <<-EOSQL
	GRANT CREATE ON SCHEMA public TO ${N8N_DB_USER};
EOSQL
done

echo "SETUP DONE: utworzono użytkownika '${N8N_DB_USER}' i 20 baz danych n8n_01…n8n_20."
