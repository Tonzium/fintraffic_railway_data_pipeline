#!/bin/bash
# Full daily refresh: fetch latest data -> dbt build -> Evidence static build.
# Publishes the built site into /site (served by nginx).
set -euo pipefail

# Only one run at a time. Two concurrent runs race on dbt_packages/: one run's
# `dbt deps` reinstalls the packages while the other is mid-`dbt build`, which
# fails with "No dbt_project.yml found at .../dbt_packages/dbt_utils".
exec 200>/tmp/pipeline.lock
if ! flock -n 200; then
    echo "=== [$(date)] Another pipeline run is already in progress; skipping. ==="
    exit 0
fi

cd /app

START=$(date -d "-${BACKFILL_DAYS:-7} days" +%F)
END=$(date +%F)

echo "=== [$(date)] Pipeline start: fetching $START .. $END ==="
(cd src && uv run python data_ingestion.py --start "$START" --end "$END")

echo "=== dbt build ==="
mkdir -p data/warehouse
(cd dbt_warehouse && uv run dbt deps && uv run dbt build --profiles-dir .)

echo "=== Copy warehouse to Evidence sources ==="
mkdir -p bi/workspace/sources/warehouse
cp data/warehouse/warehouse.duckdb bi/workspace/sources/warehouse/warehouse.duckdb

echo "=== Evidence build ==="
(cd bi/workspace && npm run sources && npm run build)

echo "=== Publish site ==="
rsync -a --delete bi/workspace/build/ /site/

echo "=== [$(date)] Pipeline done ==="
