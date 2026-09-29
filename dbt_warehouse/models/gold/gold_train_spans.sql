-- gold_train_spans.sql
-- Description: Train counts (distinct trainNumber + departureDate) aggregated as far as the page
--              filters allow (commercial stops only)
-- Materialization: Table
-- Purpose: Exact "number of trains" figures on the Evidence pages without shipping one row
--          per train.
--
-- Grain: one row per departureDate x trainType x trainCategory x first_actual_bucket x
--        last_actual_bucket x midnight_days x the five has_* flags; n_trains = trains sharing
--        that combination.
--
-- How the pages use it:
--   * trains per type/category/departure date: SUM(n_trains) (a train has one departure date,
--     type and category, so the sums are exact).
--   * trains per time_of_day_category or weekday/weekend: SUM(n_trains) FILTER (WHERE has_x);
--     a train with events in both groups counts in both, as COUNT(DISTINCT ...) GROUP BY did.
--   * trains with an event in "actual_time BETWEEN '<start>' AND '<end>'":
--       - start < end: SUM(n_trains) WHERE first_actual_bucket <= '<end>'
--         AND last_actual_bucket >= '<start>'. This is exact as long as no train has a gap of
--         more than 24 h between the actual days of its commercial stops (checked by a test: a
--         train spans at most two actual days).
--       - start = end: the range is the single instant <start> 00:00:00, so only stops stamped
--         exactly at midnight match: SUM(n_trains) WHERE contains(midnight_days, '<start>').
--       - start > end: no train.
--
-- midnight_days lists, as sorted comma-separated 'YYYY-MM-DD' strings, the days on which the
-- train had a commercial stop stamped exactly 00:00:00 ('' when none, which is almost every
-- train). It is a non-null VARCHAR so that Evidence keeps its type even when it is '' on every
-- row (an all-NULL timestamp column would be shipped as a DOUBLE).
--
-- first/last_actual_bucket use the same day stamp as gold_daily_performance.actual_bucket.

{{ config(
    materialized='table',
    schema='gold'
) }}

WITH commercial_events AS (
    SELECT
        trainNumber,
        departureDate,
        trainType,
        trainCategory,
        CASE
            WHEN actual_time = date_trunc('day', actual_time) THEN actual_time
            ELSE date_trunc('day', actual_time) + INTERVAL 12 HOUR
        END as actual_bucket,
        CASE
            WHEN actual_time = date_trunc('day', actual_time) THEN strftime(actual_time, '%Y-%m-%d')
        END as midnight_day,
        time_of_day_category,
        is_weekend
    FROM {{ ref('silver_fact_timetable_events') }}
    WHERE commercial_stop = true
    AND actual_time IS NOT NULL
    -- COUNT(DISTINCT trainNumber || departureDate) ignored trains with a NULL key part
    AND trainNumber IS NOT NULL
    AND departureDate IS NOT NULL
),

trains AS (
    SELECT
        trainNumber,
        departureDate,
        trainType,
        trainCategory,
        MIN(actual_bucket) as first_actual_bucket,
        MAX(actual_bucket) as last_actual_bucket,
        COALESCE(string_agg(DISTINCT midnight_day, ',' ORDER BY midnight_day), '') as midnight_days,
        bool_or(time_of_day_category = 'morning_rush') as has_morning_rush,
        bool_or(time_of_day_category = 'off_peak') as has_off_peak,
        bool_or(time_of_day_category = 'evening_rush') as has_evening_rush,
        bool_or(NOT is_weekend) as has_weekday,
        bool_or(is_weekend) as has_weekend
    FROM commercial_events
    GROUP BY trainNumber, departureDate, trainType, trainCategory
)

SELECT
    departureDate,
    trainType,
    trainCategory,
    first_actual_bucket,
    last_actual_bucket,
    midnight_days,
    has_morning_rush,
    has_off_peak,
    has_evening_rush,
    has_weekday,
    has_weekend,
    CAST(COUNT(*) AS BIGINT) as n_trains
FROM trains
GROUP BY ALL
