# Deploying the demo

This was the first deployment note (2026-08). It has been replaced by:

- [demo/README.md](README.md): how the demo stack works, deploy steps, `.env` settings.
- [docs/OPERATIONS.md](../docs/OPERATIONS.md): day-to-day commands, troubleshooting,
  VM access, and the incident log.

Short version:

```bash
git clone https://github.com/Tonzium/fintraffic_railway_data_pipeline.git railway && cd railway
cp .env.example .env      # paste the tunnel token
docker compose -f docker-compose.demo.yml up -d --build
```

Then in Cloudflare Zero Trust, add the public hostname railway.tonikiuru.com → `HTTP://web:80`.

Later updates: push to `main`, then run `sudo demo/deploy.sh` on the server.
