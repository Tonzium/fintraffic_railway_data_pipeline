# Self-hosted demo — railway.tonikiuru.com

One Docker Compose stack that keeps a public Evidence dashboard up to date automatically.

## How it works

- **pipeline** container: on startup and then **every day at 07:00 (Europe/Helsinki)** it
  1. fetches the last `BACKFILL_DAYS` (default 7) days from the Digitraffic API,
  2. runs `dbt build`,
  3. copies `warehouse.duckdb` into the Evidence workspace,
  4. runs `evidence build` (static site) and publishes it to a shared volume.

  If a run fails, the previously published site stays up.
- **web** container: nginx serving the static site on port `3000`.
- **cloudflared** container: Cloudflare Tunnel exposing it as `railway.tonikiuru.com`.

Fetched raw data persists in the `railway_data` volume, so history accumulates day by day.

## Deploy (Proxmox VM/LXC with Docker)

```bash
git clone <this repo> && cd tonikiuru
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
| `TZ` | `Europe/Helsinki` | timezone for the 07:00 schedule |
| `UPDATE_HOUR` | `7` | hour of day for the daily refresh |
| `BACKFILL_DAYS` | `7` | how many past days to (re)fetch each run |

To backfill more history once: `BACKFILL_DAYS=90 docker compose -f docker-compose.demo.yml up -d`
(then set it back; already-persisted days stay in the volume).

## Operations

```bash
# Force a refresh now
docker exec railway-pipeline bash /app/demo/run_pipeline.sh

# Rebuild after changing dashboards/models
docker compose -f docker-compose.demo.yml up -d --build pipeline

# Reset all fetched data
docker compose -f docker-compose.demo.yml down && docker volume rm railway_data
```
