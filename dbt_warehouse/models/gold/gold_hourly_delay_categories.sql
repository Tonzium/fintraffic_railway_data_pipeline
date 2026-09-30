-- gold_hourly_delay_categories.sql
-- Description: All-time measures per scheduled hour, train type and delay category
--              (commercial stops only)
-- Materialization: Table
-- Purpose: Hourly patterns, rush-hour figures and delay-category distributions on the Evidence
--          pages (index, time_analysis, train_performance). Replaces event-level reads of
--          silver_fact_timetable_events.
--
-- Grain: one row per scheduled_hour x trainType x trainCategory x delay_category.
--        time_of_day_category is a function of scheduled_hour, so it adds no rows.
--
-- No date column: the table is rebuilt daily and always covers the full retained history.
-- Its size is bounded by 24 hours x type/category pairs x 6 delay categories and does not grow
-- with the number of days. Measures are the additive ones of gold_daily_performance, so any
-- roll-up (per hour, per time_of_day_category, per trainType, ...) is exact.

{{ config(
    materialized='table',
    schema='gold'
) }}

WITH commercial_events AS (
    SELECT
        scheduled_hour,
        time_of_day_category,
        trainType,
        trainCategory,
        delay_category,
        is_on_time,
        delay_minutes
    FROM {{ ref('silver_fact_timetable_events') }}
    WHERE commercial_stop = true
    AND actual_time IS NOT NULL
)

SELECT
    scheduled_hour,
    time_of_day_category,
    trainType,
    trainCategory,
    delay_category,

    CAST(COUNT(*) AS BIGINT) as events,
    CAST(COUNT(*) FILTER (WHERE is_on_time) AS BIGINT) as on_time_events,
    CAST(SUM(delay_minutes) AS BIGINT) as delay_sum,
    CAST(SUM(delay_minutes * delay_minutes) AS BIGINT) as delay_sumsq,
    CAST(COUNT(delay_minutes) AS BIGINT) as delay_count

FROM commercial_events
GROUP BY scheduled_hour, time_of_day_category, trainType, trainCategory, delay_category
