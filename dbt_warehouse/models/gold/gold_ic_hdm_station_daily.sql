-- gold_ic_hdm_station_daily.sql
-- Description: Daily IC and HDM measures per station (commercial stops only)
-- Materialization: Table
-- Purpose: IC vs HDM page: headline metrics and stations served for the selected period,
--          and the per-station route tables.
--
-- Grain: one row per departureDate x trainType (IC, HDM) x stationShortCode.
-- The page period filter is on departureDate, so it is kept at day level; stations served in a
-- period is COUNT(DISTINCT stationShortCode) over the selected days. Measures as in
-- gold_daily_performance.

{{ config(
    materialized='table',
    schema='gold'
) }}

SELECT
    departureDate,
    trainType,
    stationShortCode,

    CAST(COUNT(*) AS BIGINT) as events,
    CAST(COUNT(*) FILTER (WHERE is_on_time) AS BIGINT) as on_time_events,
    CAST(SUM(delay_minutes) AS BIGINT) as delay_sum,
    CAST(SUM(delay_minutes * delay_minutes) AS BIGINT) as delay_sumsq,
    CAST(COUNT(delay_minutes) AS BIGINT) as delay_count

FROM {{ ref('silver_fact_timetable_events') }}
WHERE trainType IN ('IC', 'HDM')
AND commercial_stop = true
AND actual_time IS NOT NULL
GROUP BY departureDate, trainType, stationShortCode
