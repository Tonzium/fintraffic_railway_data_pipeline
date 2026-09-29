-- gold_ic_hdm_hourly_daily.sql
-- Description: Daily IC and HDM measures per scheduled hour and delay category
--              (commercial stops only)
-- Materialization: Table
-- Purpose: IC vs HDM page: hourly comparison and delay-category breakdown for the selected
--          period.
--
-- Grain: one row per departureDate x trainType (IC, HDM) x scheduled_hour x delay_category.
-- Measures as in gold_daily_performance.

{{ config(
    materialized='table',
    schema='gold'
) }}

SELECT
    departureDate,
    trainType,
    scheduled_hour,
    delay_category,

    CAST(COUNT(*) AS BIGINT) as events,
    CAST(COUNT(*) FILTER (WHERE is_on_time) AS BIGINT) as on_time_events,
    CAST(SUM(delay_minutes) AS BIGINT) as delay_sum,
    CAST(SUM(delay_minutes * delay_minutes) AS BIGINT) as delay_sumsq,
    CAST(COUNT(delay_minutes) AS BIGINT) as delay_count

FROM {{ ref('silver_fact_timetable_events') }}
WHERE trainType IN ('IC', 'HDM')
AND commercial_stop = true
AND actual_time IS NOT NULL
GROUP BY departureDate, trainType, scheduled_hour, delay_category
