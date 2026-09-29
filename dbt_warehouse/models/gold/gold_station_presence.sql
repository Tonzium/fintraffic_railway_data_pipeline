-- gold_station_presence.sql
-- Description: Runs of consecutive days on which a train type served a station
--              (commercial stops only)
-- Materialization: Table
-- Purpose: Exact "stations served" per train type/category for any date range picked on the
--          Train Performance page, without shipping one row per station per day.
--
-- Grain: one row per trainType x trainCategory x stationShortCode x run, where a run is a
--        maximal sequence of actual-day buckets (same stamp as gold_daily_performance.actual_bucket)
--        with at most 24 h between consecutive buckets, i.e. consecutive days.
--
-- A station had at least one event in "actual_time BETWEEN '<start>' AND '<end>'" exactly when
-- one of its runs satisfies
--   * start < end: first_actual_bucket <= '<end>' AND last_actual_bucket >= '<start>'
--     The range is at least 24 h long, so it cannot fall inside the <= 24 h gap between two
--     buckets of the same run.
--   * start = end: contains(midnight_days, '<start>'). The range is the single instant
--     <start> 00:00:00, so only stops stamped exactly at midnight match.
--   * start > end: never.
-- Count stations with COUNT(DISTINCT stationShortCode).
--
-- midnight_days lists, as sorted comma-separated 'YYYY-MM-DD' strings, the days of the run with
-- a stop stamped exactly 00:00:00 ('' when none). Non-null VARCHAR, so Evidence keeps its type.

{{ config(
    materialized='table',
    schema='gold'
) }}

WITH presence AS (
    SELECT DISTINCT
        trainType,
        trainCategory,
        stationShortCode,
        CASE
            WHEN actual_time = date_trunc('day', actual_time) THEN actual_time
            ELSE date_trunc('day', actual_time) + INTERVAL 12 HOUR
        END as actual_bucket
    FROM {{ ref('silver_fact_timetable_events') }}
    WHERE commercial_stop = true
    AND actual_time IS NOT NULL
),

run_starts AS (
    SELECT
        *,
        CASE
            WHEN LAG(actual_bucket) OVER w IS NULL THEN 1
            WHEN epoch(actual_bucket) - epoch(LAG(actual_bucket) OVER w) > 86400 THEN 1
            ELSE 0
        END as starts_run
    FROM presence
    WINDOW w AS (PARTITION BY trainType, trainCategory, stationShortCode ORDER BY actual_bucket)
),

numbered AS (
    SELECT
        *,
        SUM(starts_run) OVER (
            PARTITION BY trainType, trainCategory, stationShortCode
            ORDER BY actual_bucket
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) as run_number
    FROM run_starts
)

SELECT
    trainType,
    trainCategory,
    stationShortCode,
    MIN(actual_bucket) as first_actual_bucket,
    MAX(actual_bucket) as last_actual_bucket,
    COALESCE(string_agg(
        CASE WHEN actual_bucket = date_trunc('day', actual_bucket) THEN strftime(actual_bucket, '%Y-%m-%d') END,
        ',' ORDER BY actual_bucket
    ), '') as midnight_days
FROM numbered
GROUP BY trainType, trainCategory, stationShortCode, run_number
