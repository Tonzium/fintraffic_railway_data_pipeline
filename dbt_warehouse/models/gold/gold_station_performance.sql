-- gold_station_performance.sql
-- Description: Per-station traffic volume and on-time performance
-- Materialization: Table
-- Purpose: Station map visualization on the dashboard

{{ config(
    materialized='table',
    schema='gold'
) }}

WITH commercial_events AS (
    SELECT *
    FROM {{ ref('silver_fact_timetable_events') }}
    WHERE commercial_stop = true
    AND actual_time IS NOT NULL
),

station_metrics AS (
    SELECT
        stationShortCode,
        COUNT(*) as total_events,
        COUNT(DISTINCT trainNumber || '_' || departureDate) as total_trains,
        SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) as on_time_count,
        ROUND(100.0 * SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) / COUNT(*), 2) as on_time_percentage,
        ROUND(AVG(delay_minutes), 2) as avg_delay_minutes
    FROM commercial_events
    GROUP BY stationShortCode
)

SELECT
    s.stationShortCode as station_code,
    s.stationName as station_name,
    s.latitude,
    s.longitude,
    s.region,
    m.total_events,
    m.total_trains,
    m.on_time_percentage,
    m.avg_delay_minutes
FROM station_metrics m
JOIN {{ ref('silver_dim_stations') }} s
    ON m.stationShortCode = s.stationShortCode
WHERE s.passengerTraffic = true
    AND m.total_events >= 100
ORDER BY m.total_events DESC
