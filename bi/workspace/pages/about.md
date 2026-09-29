---
title: About this Project ℹ️
sidebar_position: 5
---

This dashboard is the front end of a small end-to-end data platform: it fetches real
Finnish railway data, transforms it through a layered warehouse, and rebuilds itself
every day without anyone touching it.

## Architecture

<div style="overflow-x:auto; margin: 1.5rem 0;">
<svg viewBox="0 0 700 300" xmlns="http://www.w3.org/2000/svg" style="width:100%; max-width:700px; height:auto; font-family:inherit;">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="#64748b"/>
    </marker>
  </defs>

  <!-- connectors (drawn first, under the boxes) -->
  <g stroke="#64748b" stroke-width="2" fill="none" marker-end="url(#arrow)">
    <line x1="225" y1="52" x2="243" y2="52"/>
    <line x1="455" y1="52" x2="473" y2="52"/>
    <path d="M685,84 L685,130 L15,130 L15,178"/>
    <line x1="225" y1="212" x2="243" y2="212"/>
    <line x1="455" y1="212" x2="473" y2="212"/>
  </g>

  <!-- boxes -->
  <g font-size="13" text-anchor="middle">
    <!-- 1. Digitraffic -->
    <rect x="15" y="20" width="210" height="64" rx="8" fill="#236aa4"/>
    <text x="120" y="48" fill="white" font-weight="600">Digitraffic</text>
    <text x="120" y="66" fill="#e2e8f0" font-size="11">Fintraffic Railway API</text>

    <!-- 2. Python ingestion -->
    <rect x="245" y="20" width="210" height="64" rx="8" fill="#45a1bf"/>
    <text x="350" y="48" fill="white" font-weight="600">Python Ingestion</text>
    <text x="350" y="66" fill="#e2e8f0" font-size="11">uv + requests</text>

    <!-- 3. dbt -->
    <rect x="475" y="20" width="210" height="64" rx="8" fill="#8f3d56"/>
    <text x="580" y="45" fill="white" font-weight="600">dbt</text>
    <text x="580" y="61" fill="#f4ded9" font-size="11">bronze → silver → gold</text>
    <text x="580" y="76" fill="#f4ded9" font-size="10">on DuckDB, tested</text>

    <!-- 4. Evidence build -->
    <rect x="15" y="180" width="210" height="64" rx="8" fill="#f4b548"/>
    <text x="120" y="208" fill="#1f2937" font-weight="600">Evidence static build</text>
    <text x="120" y="226" fill="#4b3d1f" font-size="11">DuckDB WASM in-browser</text>

    <!-- 5. nginx -->
    <rect x="245" y="180" width="210" height="64" rx="8" fill="#46a485"/>
    <text x="350" y="208" fill="white" font-weight="600">nginx</text>
    <text x="350" y="226" fill="#e2f4ec" font-size="11">serves the static site</text>

    <!-- 6. Cloudflare Tunnel -->
    <rect x="475" y="180" width="210" height="64" rx="8" fill="#71b9f4"/>
    <text x="580" y="208" fill="#0f2942" font-weight="600">Cloudflare Tunnel</text>
    <text x="580" y="226" fill="#0f2942" font-size="11">railway.tonikiuru.com</text>
  </g>

  <text x="15" y="280" font-size="11" fill="#64748b">Steps 1–3 re-run daily at 07:00 EET, on Proxmox.</text>
</svg>
</div>

**Digitraffic → Python ingestion → dbt (bronze/silver/gold, DuckDB) → Evidence static build
→ nginx → Cloudflare Tunnel**, re-run on a schedule by a container on Proxmox.

## Why this stack

- **DuckDB** — an entire quarter of Finnish railway events fits comfortably in a single
  embedded file. No cluster, no server to keep alive, and the same engine runs both the
  dbt transformations and (via DuckDB WASM) the charts in your browser.
- **dbt** — the bronze/silver/gold layering keeps raw API payloads, cleaned facts, and
  business-level aggregates separate and testable, so a bad upstream field doesn't
  silently corrupt the dashboard.
- **Evidence** — dashboards as version-controlled markdown + SQL, compiled to a static
  site. No dashboard server to run in production, and every chart's query is visible in
  this repo.

## Data

Source data comes from [Fintraffic's Digitraffic API](https://www.digitraffic.fi/en/railway-traffic/),
covering VR train timetables, realized times, and station metadata across Finland. The
public demo has collected data since 5 August 2026. Every morning at 07:00 (Helsinki time)
it fetches the latest day and re-fetches the previous seven, so late realized times are
filled in. History is kept for up to one year; older days are removed automatically.

## Source

Full source, dbt models, and the ingestion pipeline are on GitHub:
[Tonzium/fintraffic_railway_data_pipeline](https://github.com/Tonzium/fintraffic_railway_data_pipeline) — see the README for local setup.

---

[← Back to Dashboard](/)
