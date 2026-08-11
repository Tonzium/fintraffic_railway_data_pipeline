# Demo Roadmap — railway.tonikiuru.com

Goal: turn the Evidence train-analytics project into a polished, live portfolio demo
hosted on Proxmox, refreshed daily, worth linking from tonikiuru.com.

Work through milestones in order — each one leaves the demo in a better, shippable
state. Check boxes as you go.

---

## M0 — Cleanup & quick wins (~half a day)

Low-effort items that remove "unfinished" signals before anything else.

- [x] **Remove Evidence template leftovers**: delete `bi/workspace/sources/needful_things/`
      (default template data — `orders.sql`, `needful_things.duckdb`). Rebuild Evidence
      to confirm nothing references it.
- [x] **Real data-freshness footer** on `bi/workspace/pages/index.md`: replace the static
      *"Data updated: Latest dbt run"* with a query
      (`SELECT MAX(actual_time) FROM warehouse.timetable_events`) rendered as
      *"Data through {date}, refreshed daily at 07:00 EET"*.
- [x] **README**: move the live-demo link/badge to the very top (currently buried in
      section 5). One-line pitch + screenshot + link before anything else.
- [x] **Page titles & favicon**: consistent `title:` frontmatter on all 4 pages; custom
      favicon (place in `bi/workspace/static/`). *(favicon is a placeholder solid-color
      glyph generated without Pillow/design tools — swap for a real logo when you have one)*

**Done when:** a fresh `docker compose build && up` shows no template data, and the
footer shows an actual date.

---

## M1 — Story & interactivity (1–2 days)

Make the landing page answer a question instead of listing metrics.

- [x] **Narrative headline** on `index.md`: lead with the answer, e.g.
      *"Are Finnish trains on time? {otp}% are — but the morning rush tells another story."*
      Interpolate query values into prose so the story stays true after each refresh.
- [x] **2–3 insight callouts** (Evidence `<Alert>` / `<BigValue>` with comparisons):
      best/worst train category, worst hour of day. *(week-over-week OTP delta skipped —
      dataset is a single 3-month backfill window, not yet enough history to make that
      comparison meaningful)*
- [x] **Annotate the hourly chart**: `ReferenceArea` bands for morning/evening rush
      hours on the existing LineChart.
- [x] **Filters** on `train_performance.md`: `Dropdown` for train category and
      `DateRange` input, applied to the Overall Rankings section. (Works on the static
      build — queries run in-browser via DuckDB WASM.)

**Done when:** a visitor with zero context understands the main finding in 10 seconds
and can filter the data themselves.

---

## M2 — Station map of Finland (~1 day) ⭐ biggest visual win

- [x] **New gold model** `gold_station_performance.sql`: per-station event count,
      avg delay, OTP %, joined to `silver_dim_stations` for `latitude`/`longitude`
      (already available). Filter to `passengerTraffic = true` stations with a minimum
      event count so the map isn't cluttered by turnouts.
- [x] **Expose it** as a new Evidence source: `bi/workspace/sources/warehouse/station_performance.sql`.
- [x] **New page** `pages/stations.md` with Evidence `<BubbleMap>`: bubble size = traffic
      volume, color = avg delay. Added `DataTable`s for both the 10 most delayed and 10
      busiest stations below it.
- [x] **Link it** from the index Quick Links. Verified rendering in `docker compose up`
      (dev stack) with Playwright — still worth a pass through
      `docker-compose.demo.yml`'s `pipeline` build before the next real deploy.

**Done when:** the dashboard opens on a map of Finland where Helsinki, Tampere, Oulu
are visibly distinguishable by delay/volume.

---

## M3 — "About this project" page (~half a day)

The dashboard itself is the portfolio piece — visitors won't read the GitHub README.

- [x] **New page** `pages/about.md`:
      - Architecture diagram: Digitraffic API → Python ingestion → dbt (bronze/silver/gold,
        DuckDB) → Evidence static build → nginx → Cloudflare Tunnel, auto-refreshed daily
        on Proxmox. *(Implemented as inline SVG directly in the page rather than an
        exported PNG/SVG in `static/` — no Mermaid dependency needed either way.)*
      - Short stack rationale (why DuckDB, why Evidence, why static build).
      - Link to the GitHub repo.
- [x] Added to the Quick Links on the index page.

**Done when:** someone can understand the full pipeline without leaving the dashboard.

---

## M4 — Proxmox deployment & hardening (~1 day)

- [ ] **Provision**: LXC with `nesting=1` (+ `keyctl=1` if unprivileged) — or a small VM
      if Docker-in-LXC misbehaves. ≥4 GB RAM (Evidence build is memory-hungry),
      ≥15 GB disk.
- [ ] **First-run backfill**: in `demo/entrypoint.sh`, if the data volume is empty,
      run once with `BACKFILL_DAYS=90` before switching to the daily 7-day refresh —
      otherwise a fresh deploy shows only one thin week of data.
- [ ] **Healthchecks** in `docker-compose.demo.yml`: `web` (`wget -q --spider localhost`),
      `pipeline` (site marker file freshness). `restart: unless-stopped` is already in place.
- [ ] **Deploy**: clone, `.env` with tunnel token, `docker compose -f docker-compose.demo.yml up -d --build`;
      verify `https://railway.tonikiuru.com` and watch `docker logs -f railway-pipeline`
      through the first full pipeline run.
- [ ] **Monitoring**: Uptime Kuma (or similar) on the Proxmox host pinging the public URL —
      a dead "live demo" is worse than none.
- [ ] **Backups**: Proxmox scheduled backup of the container/VM, or a cron
      `docker run --rm -v railway_data:/d alpine tar czf ...` for the data volume.
- [ ] **Verify the daily refresh**: next morning after 07:00, confirm the freshness
      footer (M0) advanced.

**Done when:** the site survives a host reboot unattended and you get alerted if it goes down.

---

## M5 — Stretch: Weather × delays page

The most distinctive possible page: *"Do Finnish trains slow down in snow?"*

- [ ] Promote weather data from the lake demo (`data/lake/`) into a proper dbt source +
      silver/gold models (or switch to a real API, e.g. FMI open data, fetched in the
      daily pipeline).
- [ ] Gold model joining daily weather (temp, snowfall) to daily avg delay.
- [ ] New page: scatter/line of delay vs temperature/snow, with a narrative takeaway.

**Done when:** the page answers the snow question with real data and reads as an analysis,
not a chart dump.

---

## Suggested order & pacing

| Session | Scope |
|---|---|
| 1 | M0 entirely |
| 2–3 | M1 |
| 4 | M2 (map) |
| 5 | M3 + start M4 |
| 6 | Finish M4, verify overnight refresh |
| 7+ | M5 when the rest is live |

Ship after M2 — the demo is already link-worthy then. M3–M4 make it durable, M5 makes it memorable.
