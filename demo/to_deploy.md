  To deploy on Proxmox

  git clone <repo> && cd tonikiuru
  cp .env.example .env      # paste tunnel token
  docker compose -f docker-compose.demo.yml up -d --build

  Then in Cloudflare Zero Trust, add public hostname railway.tonikiuru.com → HTTP://web:80. When you want a different
  schedule later, just change UPDATE_HOUR (and TZ if needed) in .env and restart. For a one-time deeper backfill, run
  once with BACKFILL_DAYS=90 — already-fetched days persist.

  One note: today's data is always partial when fetched at 07:00 (only trains up to that time), but since each run
  re-fetches the last 7 days, it gets completed on subsequent runs automatically.

  What I added

  - docker-compose.demo.yml — three services:
    - pipeline — runs the full refresh once at startup, then every day at 07:00 Europe/Helsinki: fetches the last
  BACKFILL_DAYS (default 7) days from Digitraffic, runs dbt deps && dbt build, copies warehouse.duckdb into Evidence,
  runs evidence build, and publishes the static site to a shared volume. If a run fails, the previous site stays up.
  Fetched data persists in a railway_data volume so history accumulates.
    - web — nginx serving the static site on port 3000 (no dev server, no Node heap issues in production).
    - cloudflared — Cloudflare Tunnel, reads CLOUDFLARE_TUNNEL_TOKEN from .env.
  - demo/ — Dockerfile (Node 20 + uv, Python pinned to 3.12 because dbt 1.x doesn't support 3.14), pipeline script,
  scheduler, nginx config, and a full deployment guide in demo/README.md.
  - .env.example, .dockerignore, and a new README section pointing to the demo.