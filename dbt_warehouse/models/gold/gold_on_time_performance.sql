-- gold_on_time_performance.sql
-- Description: Overall on-time performance metrics and KPIs
-- Materialization: Table
-- Purpose: Executive dashboard and high-level performance tracking

{{ config(
    materialized='table',
    schema='gold'
) }}

WITH commercial_events AS (
    -- Focus only on commercial stops where passengers board/alight
    SELECT *
    FROM {{ ref('silver_fact_timetable_events') }}
    WHERE commercial_stop = true
    AND actual_time IS NOT NULL  -- Only completed events
),

overall_metrics AS (
    SELECT
        'Overall' as metric_scope,
        COUNT(*) as total_events,
        COUNT(DISTINCT trainNumber || '_' || departureDate) as total_trains,
        COUNT(DISTINCT stationShortCode) as total_stations,

        -- On-time performance
        SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) as on_time_count,
        ROUND(100.0 * SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) / COUNT(*), 2) as on_time_percentage,

        -- Delay statistics
        ROUND(AVG(delay_minutes), 2) as avg_delay_minutes,
        ROUND(MEDIAN(delay_minutes), 2) as median_delay_minutes,
        MAX(delay_minutes) as max_delay_minutes,
        MIN(delay_minutes) as min_delay_minutes,

        -- Delay distribution
        SUM(CASE WHEN delay_category = 'early' THEN 1 ELSE 0 END) as early_count,
        SUM(CASE WHEN delay_category = 'on_time' THEN 1 ELSE 0 END) as on_time_count_strict,
        SUM(CASE WHEN delay_category = 'slightly_late' THEN 1 ELSE 0 END) as slightly_late_count,
        SUM(CASE WHEN delay_category = 'late' THEN 1 ELSE 0 END) as late_count,
        SUM(CASE WHEN delay_category = 'very_late' THEN 1 ELSE 0 END) as very_late_count,

        -- Percentages
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'early' THEN 1 ELSE 0 END) / COUNT(*), 2) as early_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'on_time' THEN 1 ELSE 0 END) / COUNT(*), 2) as on_time_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'slightly_late' THEN 1 ELSE 0 END) / COUNT(*), 2) as slightly_late_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'late' THEN 1 ELSE 0 END) / COUNT(*), 2) as late_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'very_late' THEN 1 ELSE 0 END) / COUNT(*), 2) as very_late_pct

    FROM commercial_events
),

by_train_type AS (
    SELECT
        trainType as metric_scope,
        COUNT(*) as total_events,
        COUNT(DISTINCT trainNumber || '_' || departureDate) as total_trains,
        COUNT(DISTINCT stationShortCode) as total_stations,

        -- On-time performance
        SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) as on_time_count,
        ROUND(100.0 * SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) / COUNT(*), 2) as on_time_percentage,

        -- Delay statistics
        ROUND(AVG(delay_minutes), 2) as avg_delay_minutes,
        ROUND(MEDIAN(delay_minutes), 2) as median_delay_minutes,
        MAX(delay_minutes) as max_delay_minutes,
        MIN(delay_minutes) as min_delay_minutes,

        -- Delay distribution
        SUM(CASE WHEN delay_category = 'early' THEN 1 ELSE 0 END) as early_count,
        SUM(CASE WHEN delay_category = 'on_time' THEN 1 ELSE 0 END) as on_time_count_strict,
        SUM(CASE WHEN delay_category = 'slightly_late' THEN 1 ELSE 0 END) as slightly_late_count,
        SUM(CASE WHEN delay_category = 'late' THEN 1 ELSE 0 END) as late_count,
        SUM(CASE WHEN delay_category = 'very_late' THEN 1 ELSE 0 END) as very_late_count,

        -- Percentages
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'early' THEN 1 ELSE 0 END) / COUNT(*), 2) as early_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'on_time' THEN 1 ELSE 0 END) / COUNT(*), 2) as on_time_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'slightly_late' THEN 1 ELSE 0 END) / COUNT(*), 2) as slightly_late_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'late' THEN 1 ELSE 0 END) / COUNT(*), 2) as late_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'very_late' THEN 1 ELSE 0 END) / COUNT(*), 2) as very_late_pct

    FROM commercial_events
    GROUP BY trainType
),

by_train_category AS (
    SELECT
        trainCategory as metric_scope,
        COUNT(*) as total_events,
        COUNT(DISTINCT trainNumber || '_' || departureDate) as total_trains,
        COUNT(DISTINCT stationShortCode) as total_stations,

        -- On-time performance
        SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) as on_time_count,
        ROUND(100.0 * SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) / COUNT(*), 2) as on_time_percentage,

        -- Delay statistics
        ROUND(AVG(delay_minutes), 2) as avg_delay_minutes,
        ROUND(MEDIAN(delay_minutes), 2) as median_delay_minutes,
        MAX(delay_minutes) as max_delay_minutes,
        MIN(delay_minutes) as min_delay_minutes,

        -- Delay distribution
        SUM(CASE WHEN delay_category = 'early' THEN 1 ELSE 0 END) as early_count,
        SUM(CASE WHEN delay_category = 'on_time' THEN 1 ELSE 0 END) as on_time_count_strict,
        SUM(CASE WHEN delay_category = 'slightly_late' THEN 1 ELSE 0 END) as slightly_late_count,
        SUM(CASE WHEN delay_category = 'late' THEN 1 ELSE 0 END) as late_count,
        SUM(CASE WHEN delay_category = 'very_late' THEN 1 ELSE 0 END) as very_late_count,

        -- Percentages
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'early' THEN 1 ELSE 0 END) / COUNT(*), 2) as early_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'on_time' THEN 1 ELSE 0 END) / COUNT(*), 2) as on_time_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'slightly_late' THEN 1 ELSE 0 END) / COUNT(*), 2) as slightly_late_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'late' THEN 1 ELSE 0 END) / COUNT(*), 2) as late_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'very_late' THEN 1 ELSE 0 END) / COUNT(*), 2) as very_late_pct

    FROM commercial_events
    GROUP BY trainCategory
),

combined AS (
    SELECT * FROM overall_metrics
    UNION ALL
    SELECT * FROM by_train_type
    UNION ALL
    SELECT * FROM by_train_category
)

SELECT * FROM combined
ORDER BY
    CASE
        WHEN metric_scope = 'Overall' THEN 1
        WHEN metric_scope IN ('Long-distance', 'Commuter') THEN 2
        ELSE 3
    END,
    metric_scope
