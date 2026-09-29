-- gold_daily_performance.sql
-- Description: Daily event measures per train type and category (commercial stops only)
-- Materialization: Table
-- Purpose: Base aggregate for the Evidence pages (time_analysis, train_performance).
--          Replaces event-level reads of silver_fact_timetable_events.
--
-- Grain: one row per actual_bucket x trainType x trainCategory x day_of_week x scheduled_month.
--        is_weekend is a function of day_of_week, so it adds no rows.
--
-- actual_bucket is the UTC calendar day of actual_time, stamped at 12:00. Page filters of the form
-- "actual_bucket BETWEEN '<start>' AND '<end>'" (dates as YYYY-MM-DD) therefore select exactly the
-- events that "actual_time BETWEEN '<start>' AND '<end>'" selected: an event after midnight is
-- in range when start <= its day < end. Events stamped exactly 00:00:00 keep their own timestamp
-- so they still match when their day equals <end>.
--
-- Measures are additive, so any roll-up gives exact results:
--   OTP %       = 100.0 * SUM(on_time_events) / SUM(events)
--   avg delay   = SUM(delay_sum) / SUM(delay_count)
--   stddev_samp = SQRT((SUM(delay_count) * SUM(delay_sumsq) - SUM(delay_sum)^2)
--                      / (SUM(delay_count) * (SUM(delay_count) - 1)))

{{ config(
    materialized='table',
    schema='gold'
) }}

WITH commercial_events AS (
    SELECT
        CASE
            WHEN actual_time = date_trunc('day', actual_time) THEN actual_time
            ELSE date_trunc('day', actual_time) + INTERVAL 12 HOUR
        END as actual_bucket,
        trainType,
        trainCategory,
        day_of_week,
        scheduled_month,
        is_weekend,
        is_on_time,
        delay_minutes
    FROM {{ ref('silver_fact_timetable_events') }}
    WHERE commercial_stop = true
    AND actual_time IS NOT NULL
)

SELECT
    actual_bucket,
    trainType,
    trainCategory,
    day_of_week,
    scheduled_month,
    is_weekend,

    CAST(COUNT(*) AS BIGINT) as events,
    CAST(COUNT(*) FILTER (WHERE is_on_time) AS BIGINT) as on_time_events,
    CAST(SUM(delay_minutes) AS BIGINT) as delay_sum,
    CAST(SUM(delay_minutes * delay_minutes) AS BIGINT) as delay_sumsq,
    CAST(COUNT(delay_minutes) AS BIGINT) as delay_count

FROM commercial_events
GROUP BY actual_bucket, trainType, trainCategory, day_of_week, scheduled_month, is_weekend
