# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Infrastructure-as-config for running an n8n training workshop. The whole repo is a Docker Compose deployment plus shell scripts — there is no application source code, build step, lint, or test suite. The deliverable is 22 fully isolated n8n instances on a single VPS, one per workshop participant. Polish-language training material and example workflow exports (`*.json`, `szkolenie-n8n-ul.md`, `URUCHOMIENIE.md`) live alongside the infra.

The three workflow JSON files at the repo root (`Wizytówki.json`, `Raport.json`, `Email AI Agent…json`) are n8n workflow exports used as teaching examples — they are imported into n8n via its UI, not executed by this repo.

## Two compose stacks — don't conflate them

- `docker-compose.yaml` + `.env.example` + `init-data.sh` — **dev/single-instance** stack. One n8n main + one worker, queue mode via Redis, hardcoded `N8N_HOST=szkolenie-n8n.easyautomate.pl`. Used for local testing only.
- `docker-compose.prod.yaml` + `.env.prod` (generated) + `init-data-prod.sh` — **production workshop** stack. 22 n8n services (`n8n-01` … `n8n-22`) + nginx + single Postgres with 22 databases (`n8n_01` … `n8n_22`). No Redis, no queue mode, no workers. This is what actually gets deployed.

Editing one does not update the other. When changing instance count, env structure, or per-participant config, the prod stack, `init-data-prod.sh` (loops `seq -w 1 22`), `generate-env.sh`, `generate-certs.sh` (loops `seq 1 22`), and `nginx/nginx.conf` (22 `location /NN/` blocks) all must stay in sync.

Note: `URUCHOMIENIE.md` still documents **20** instances and ports 5678–5697 — the code is the source of truth (22 instances, 5678–5699). Update the doc if you touch instance count.

## Production deployment flow

1. Edit `participants.csv` (header `nr,name,email`; `nr` is `01`…`22` and maps to port `5678 + nr - 1`).
2. `bash generate-env.sh` — reads CSV, writes `.env.prod` (Postgres + per-participant `N8N_NN_ENCRYPTION_KEY` / `N8N_NN_ADMIN_EMAIL` / `N8N_NN_ADMIN_PASSWORD`) and human-readable `access-list.txt`. Idempotency: prompts before overwriting `.env.prod`.
3. Set `VPS_IP=` in `.env.prod` (replaces `CHANGE_ME`).
4. `bash generate-certs.sh [IP]` — self-signed SSL cert in `nginx/certs/` (reads `VPS_IP` from `.env.prod` if no arg).
5. `docker compose -f docker-compose.prod.yaml --env-file .env.prod up -d`

Tear down with `down` (keep data) or `down -v` (wipe volumes — destroys all participant data).

## Routing model (prod)

Two parallel access paths exist for each instance — both must keep working:

- **Direct TCP**: host port `5678 + (nr-1)` → container `:5678`. Plain HTTP.
- **HTTPS via nginx**: `https://VPS_IP/NN/` → `n8n-NN:5678`. Nginx (`nginx/nginx.conf`) terminates TLS and routes by path prefix using `proxy_pass http://$up` with the Docker DNS resolver `127.0.0.11` (so missing upstreams don't block nginx startup).

Each n8n service therefore has `N8N_PATH=/NN/` and `WEBHOOK_URL=https://${VPS_IP}/NN/` set in `docker-compose.prod.yaml`. If you add/remove an instance, update **both** the compose file and `nginx/nginx.conf`.

## Per-instance isolation guarantees

Each participant gets: their own n8n container, their own Postgres database (`n8n_NN`), their own Docker volume (`n8n_storage_NN`), their own `N8N_ENCRYPTION_KEY`, and their own pre-seeded admin user (via `N8N_DEFAULT_ADMIN_EMAIL` / `N8N_DEFAULT_ADMIN_PASSWORD`). Postgres role `n8n_user` is shared across all 22 databases — `init-data-prod.sh` creates it once and grants per-DB privileges in a loop. The script is idempotent (CREATE USER falls back to ALTER USER; CREATE DATABASE swallows errors).

## Common ops

```bash
docker compose -f docker-compose.prod.yaml ps        # status of all 22 + nginx + postgres
docker logs n8n-01                                    # logs for one participant
docker restart n8n-01                                 # restart one instance
docker stats                                          # RAM/CPU per container
```

## Conventions when editing

- Per-instance blocks in `docker-compose.prod.yaml` are intentionally repeated (not generated). When adding a participant, copy an existing block and bump `NN`, the host port, `DB_POSTGRESDB_DATABASE`, `WEBHOOK_URL`, `N8N_PATH`, the volume name, and the env-var prefix consistently.
- All user-facing strings (scripts, docs, comments) are in Polish — match that style if editing them.
- `.env.prod`, `access-list.txt`, and `nginx/certs/` are generated artifacts; don't commit them (`.gitignore` already excludes `.env*`).
