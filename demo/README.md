# Self-hosted demo — railway.tonikiuru.com

One Docker Compose stack that keeps a public Evidence dashboard up to date automatically.
The full operations guide (commands, troubleshooting, VM access) is in
[docs/OPERATIONS.md](../docs/OPERATIONS.md).

## How it works

- **pipeline** container: on startup and then **every day at 07:00 (Europe/Helsinki)** it
  1. fetches the last `BACKFILL_DAYS` (default 7) days from the Digitraffic API and saves
     one gzipped JSON file per day (written atomically, so a crash never leaves a half file),
  2. tidies the staging folder: compresses leftover plain files, quarantines unreadable ones,
     and deletes days older than `RETENTION_DAYS` (default 365),
  3. runs `dbt build`; bronze reloads the fetched days completely, so a day first seen at
     07:00 is completed by the next days' re-fetches,
  4. copies `warehouse.duckdb` into the Evidence workspace,
  5. runs `evidence build` (static site), writes `build-info.json`, and publishes it to a shared volume.

  If a run fails, the previously published site stays up. A run that takes longer than
  `RUN_TIMEOUT` (default 3 h) is killed and retried at the next schedule.
- **web** container: nginx serving the static site (`web:80` inside Docker, port `3000` on the host).
- **cloudflared** container: Cloudflare Tunnel exposing it as `railway.tonikiuru.com`.

Raw data and the warehouse persist in the `railway_data` volume: up to one year of history.
Compressed daily files are 0.6–0.9 MB each, roughly 0.3 GB for a full year.

## Deploy (Proxmox VM with Docker)

```bash
git clone https://github.com/Tonzium/fintraffic_railway_data_pipeline.git railway && cd railway
cp .env.example .env          # paste your tunnel token into .env
docker compose -f docker-compose.demo.yml up -d --build
docker logs -f railway-pipeline   # watch the first pipeline run
```

The first run fetches data, so the site appears after the pipeline finishes
(a few minutes). Site is then at `http://<host>:3000` and via the tunnel.

## Cloudflare Tunnel setup

1. Cloudflare Zero Trust → Networks → Tunnels → **Create a tunnel** (Cloudflared).
2. Copy the token into `.env` as `CLOUDFLARE_TUNNEL_TOKEN`.
3. Add a **Public Hostname**: `railway.tonikiuru.com` → Service `HTTP` → `web:80`
   (the cloudflared container reaches nginx by its compose service name).

## Config (.env)

| Variable | Default | Meaning |
|---|---|---|
| `CLOUDFLARE_TUNNEL_TOKEN` | — | tunnel token (required for public access) |
| `COMPOSE_FILE` | — | server only: `docker-compose.demo.yml`, so plain `docker compose` uses this stack (leave unset on a dev machine) |
| `TZ` | `Europe/Helsinki` | timezone for the 07:00 schedule |
| `UPDATE_HOUR` | `7` | hour of day for the daily refresh |
| `BACKFILL_DAYS` | `7` | how many past days to re-fetch and reload each run |
| `RETENTION_DAYS` | `365` | days of history kept; older raw files and warehouse rows are deleted |
| `RUN_TIMEOUT` | `3h` | a run taking longer is killed and retried at the next schedule |
| `NODE_OPTIONS` | `--max-old-space-size=4096` | Node heap for the Evidence build (needs at least 2048 MB) |
| `DUCKDB_MEMORY_LIMIT` | `4GB` | DuckDB memory cap for dbt; big loads spill to disk above it |
| `DUCKDB_THREADS` | `2` | DuckDB threads for dbt |

After editing `.env`, recreate the container: `docker compose -f docker-compose.demo.yml up -d pipeline`.

## Operations

```bash
# Force a refresh now (output goes to your terminal, not to docker logs)
docker exec railway-pipeline bash /app/demo/run_pipeline.sh

# One-off catch-up after missed days, logged to docker logs (does not change the daily setting)
docker exec -d -e BACKFILL_DAYS=35 railway-pipeline bash -c 'bash /app/demo/run_pipeline.sh > /proc/1/fd/1 2>&1'

# Rebuild after changing dashboards/models
docker compose -f docker-compose.demo.yml up -d --build pipeline

# Reload every day from the raw files into the warehouse (e.g. after upgrading), then force a refresh.
# It takes the pipeline lock: while a run is going it prints "Not run" at once.
docker exec -w /app/dbt_warehouse railway-pipeline flock -n -E 75 /tmp/pipeline.lock \
  uv run dbt build --profiles-dir . --full-refresh || echo "Not run: a pipeline run holds the lock, or it failed"

# Reset all fetched data (the old site stays up until the first run publishes the last 8 days)
docker compose -f docker-compose.demo.yml down && docker volume rm railway_data \
  && docker compose -f docker-compose.demo.yml up -d
```
