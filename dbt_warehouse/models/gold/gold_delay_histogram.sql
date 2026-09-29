-- gold_delay_histogram.sql
-- Description: All-time delay histogram per train type (commercial stops only)
-- Materialization: Table
-- Purpose: Exact medians, MIN/MAX and standard deviations per train type on the Evidence
--          Train Performance page (consistency analysis).
--
-- Grain: one row per trainType x delay_minutes. delay_minutes is NULL for stops without a
--        recorded delay; that row keeps their events so every train type with commercial stops
--        is present, as it was in the event-level queries.
--
-- delay_minutes (Digitraffic differenceInMinutes) is an integer, so the histogram holds the
-- whole delay distribution of each train type: PERCENTILE_CONT/MEDIAN, MIN and MAX are exact
-- (median = mean of the values at 0-based positions floor((n-1)/2) and ceil((n-1)/2) of the
-- cumulative delay_count). The additive measures are the same as in gold_daily_performance.
-- No date column: the table is rebuilt daily and always covers the full retained history, so
-- its size depends on the spread of delay values, not on the number of days.

{{ config(
    materialized='table',
    schema='gold'
) }}

WITH commercial_events AS (
    SELECT
        trainType,
        delay_minutes,
        is_on_time
    FROM {{ ref('silver_fact_timetable_events') }}
    WHERE commercial_stop = true
    AND actual_time IS NOT NULL
)

SELECT
    trainType,
    delay_minutes,

    CAST(COUNT(*) AS BIGINT) as events,
    CAST(COUNT(*) FILTER (WHERE is_on_time) AS BIGINT) as on_time_events,
    CAST(SUM(delay_minutes) AS BIGINT) as delay_sum,
    CAST(SUM(delay_minutes * delay_minutes) AS BIGINT) as delay_sumsq,
    CAST(COUNT(delay_minutes) AS BIGINT) as delay_count

FROM commercial_events
GROUP BY trainType, delay_minutes
