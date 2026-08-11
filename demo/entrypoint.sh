#!/bin/bash
# Runs the pipeline once at startup, then every day at UPDATE_HOUR (default 07:00, TZ from env).
set -uo pipefail

run() {
    if bash /app/demo/run_pipeline.sh; then
        echo "[scheduler] Pipeline succeeded."
    else
        echo "[scheduler] Pipeline FAILED (exit $?). Keeping previous site; retrying at next schedule." >&2
    fi
}

echo "[scheduler] Initial run..."
run

while true; do
    now=$(date +%s)
    next=$(date -d "today ${UPDATE_HOUR:-7}:00" +%s)
    if [ "$next" -le "$now" ]; then
        next=$(date -d "tomorrow ${UPDATE_HOUR:-7}:00" +%s)
    fi
    sleep_s=$((next - now))
    echo "[scheduler] Next run at $(date -d "@$next"). Sleeping ${sleep_s}s."
    sleep "$sleep_s"
    run
done
