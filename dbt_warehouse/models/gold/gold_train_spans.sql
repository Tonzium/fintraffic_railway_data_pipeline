-- gold_train_spans.sql
-- Description: Train counts (distinct trainNumber + departureDate) aggregated as far as the page
--              filters allow (commercial stops only)
-- Materialization: Table
-- Purpose: Exact "number of trains" figures on the Evidence pages without shipping one row
--          per train.
--
-- Grain: one row per departureDate x trainType x trainCategory x first_actual_bucket x
--        last_actual_bucket x the five has_* flags; n_trains = trains sharing that combination.
--
-- How the pages use it:
--   * trains per type/category/departure date: SUM(n_trains) (a train has one departure date,
--     type and category, so the sums are exact).
--   * trains per time_of_day_category or weekday/weekend: SUM(n_trains) FILTER (WHERE has_x);
--     a train with events in both groups counts in both, as COUNT(DISTINCT ...) GROUP BY did.
--   * trains with an event in "actual_time BETWEEN '<start>' AND '<end>'" (start < end):
--     SUM(n_trains) WHERE first_actual_bucket <= '<end>' AND last_actual_bucket >= '<start>'.
--     This is exact as long as no train has a gap of more than 24 h between the actual days of
--     its commercial stops (checked by a test: a train spans at most two actual days).
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
    has_morning_rush,
    has_off_peak,
    has_evening_rush,
    has_weekday,
    has_weekend,
    CAST(COUNT(*) AS BIGINT) as n_trains
FROM trains
GROUP BY ALL
