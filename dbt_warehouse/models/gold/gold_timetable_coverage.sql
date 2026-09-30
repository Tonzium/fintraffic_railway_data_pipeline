-- gold_timetable_coverage.sql
-- Description: Daily row counts and actual-time range over ALL timetable events
-- Materialization: Table
-- Purpose: Data coverage, freshness, category list, date-picker bounds and "latest departure
--          date" on the Evidence pages. Unlike the other page aggregates it is not limited to
--          commercial stops with an actual time, because those page queries were not either.
--
-- Grain: one row per departureDate x trainType x trainCategory.

{{ config(
    materialized='table',
    schema='gold'
) }}

SELECT
    departureDate,
    trainType,
    trainCategory,
    CAST(COUNT(*) AS BIGINT) as events,
    MIN(actual_time) as min_actual_time,
    MAX(actual_time) as max_actual_time
FROM {{ ref('silver_fact_timetable_events') }}
GROUP BY departureDate, trainType, trainCategory
