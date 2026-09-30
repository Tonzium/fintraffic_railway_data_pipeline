#!/bin/bash
# Full daily refresh: fetch latest data -> tidy staging -> dbt build -> Evidence static build.
# Publishes the built site into /site (served by nginx).
set -euo pipefail

# Only one run at a time. Two concurrent runs would race on the warehouse file and
# on the Evidence build folder. A skipped run exits 75 (EX_TEMPFAIL) so the
# scheduler reports it as skipped rather than succeeded.
exec 200>/tmp/pipeline.lock
if ! flock -n 200; then
    echo "=== [$(date)] Another pipeline run is already in progress; skipping. ==="
    exit 75
fi
# Every step below runs with fd 200 closed (200>&-), so only this script holds the
# lock: if it dies, the lock is released even if a child process lingers.

cd /app

BACKFILL_DAYS="${BACKFILL_DAYS:-7}"
RETENTION_DAYS="${RETENTION_DAYS:-365}"
START=$(date -d "-${BACKFILL_DAYS} days" +%F)
END=$(date +%F)

echo "=== [$(date)] Pipeline start: fetching $START .. $END ==="
(cd src && uv run python data_ingestion.py --start "$START" --end "$END" --compress) 200>&-

echo "=== Tidy staging: compress, keep ${RETENTION_DAYS} days ==="
(cd src && uv run python staging_maintenance.py --retention-days "$RETENTION_DAYS") 200>&-

echo "=== dbt build ==="
mkdir -p data/warehouse
# dbt packages are installed in the image; `dbt deps` only runs if they are missing.
(cd dbt_warehouse \
    && { [ -d dbt_packages/dbt_utils ] || uv run dbt deps; } \
    && uv run dbt build --profiles-dir . \
        --vars "{reload_days: ${BACKFILL_DAYS}, retention_days: ${RETENTION_DAYS}}") 200>&-

echo "=== Copy warehouse to Evidence sources ==="
mkdir -p bi/workspace/sources/warehouse
cp data/warehouse/warehouse.duckdb bi/workspace/sources/warehouse/warehouse.duckdb

echo "=== Evidence build ==="
(cd bi/workspace && npm run sources && npm run build) 200>&-

# build-info.json lets monitoring (e.g. Home Assistant) read when the site was built
# and which days it covers.
uv run python - 200>&- <<'PY'
import datetime, json, duckdb
con = duckdb.connect("data/warehouse/warehouse.duckdb", read_only=True)
first, last, days = con.execute(
    "SELECT min(departureDate), max(departureDate), count(DISTINCT departureDate) "
    "FROM dev_bronze.bronze_train_departures").fetchone()
info = {
    "built_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "data_from": str(first),
    "data_through": str(last),
    "days": days,
}
with open("bi/workspace/build/build-info.json", "w") as f:
    json.dump(info, f)
print("Build info:", info)
PY

echo "=== Publish site ==="
rsync -a --delete bi/workspace/build/ /site/

echo "=== [$(date)] Pipeline done ==="
