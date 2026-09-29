#!/bin/bash
# Runs the pipeline once at startup, then every day at UPDATE_HOUR (default 07:00, TZ from env).
# Each run is capped at RUN_TIMEOUT (default 3h): a hung step is killed, with all its
# child processes, instead of blocking every later run.
set -uo pipefail

run() {
    timeout --kill-after=2m "${RUN_TIMEOUT:-3h}" bash /app/demo/run_pipeline.sh
    local rc=$?
    case $rc in
        0)
            echo "[scheduler] Pipeline succeeded." ;;
        75)
            echo "[scheduler] Pipeline skipped: another run holds the lock." >&2 ;;
        124|137)
            echo "[scheduler] Pipeline TIMED OUT after ${RUN_TIMEOUT:-3h} (exit $rc). Keeping previous site; retrying at next schedule." >&2 ;;
        *)
            echo "[scheduler] Pipeline FAILED (exit $rc). Keeping previous site; retrying at next schedule." >&2 ;;
    esac
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
