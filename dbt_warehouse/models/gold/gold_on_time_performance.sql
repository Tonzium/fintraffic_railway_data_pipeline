-- gold_on_time_performance.sql
-- Description: Overall on-time performance metrics and KPIs
-- Materialization: Table
-- Purpose: Executive dashboard and high-level performance tracking

{{ config(
    materialized='table',
    schema='gold'
) }}

-- Memory: DuckDB 1.4 materialises a CTE that is referenced more than once. The
-- event CTE below is read three times, so it is NOT MATERIALIZED and projects only
-- the columns used; otherwise every column of every commercial event is buffered
-- (about 4.2 GB RSS at 365 days). Train counts come from a small train-level CTE
-- instead of COUNT(DISTINCT trainNumber || '_' || departureDate) over every event.

WITH commercial_events AS NOT MATERIALIZED (
    -- Focus only on commercial stops where passengers board/alight
    SELECT
        trainNumber,
        departureDate,
        trainType,
        trainCategory,
        stationShortCode,
        is_on_time,
        delay_minutes,
        delay_category
    FROM {{ ref('silver_fact_timetable_events') }}
    WHERE commercial_stop = true
    AND actual_time IS NOT NULL  -- Only completed events
),

-- One row per train run (trainNumber, departureDate) and type/category.
-- A NULL key made the old concatenated key NULL, which COUNT(DISTINCT) skipped.
train_runs AS (
    SELECT DISTINCT trainNumber, departureDate, trainType, trainCategory
    FROM commercial_events
    WHERE trainNumber IS NOT NULL
    AND departureDate IS NOT NULL
),

trains_overall AS (
    SELECT COUNT(*) as total_trains
    FROM (SELECT DISTINCT trainNumber, departureDate FROM train_runs)
),

trains_by_type AS (
    SELECT trainType, COUNT(*) as total_trains
    FROM (SELECT DISTINCT trainNumber, departureDate, trainType FROM train_runs)
    GROUP BY trainType
),

trains_by_category AS (
    SELECT trainCategory, COUNT(*) as total_trains
    FROM (SELECT DISTINCT trainNumber, departureDate, trainCategory FROM train_runs)
    GROUP BY trainCategory
),

overall_metrics AS (
    SELECT
        'Overall' as metric_scope,
        COUNT(*) as total_events,
        (SELECT total_trains FROM trains_overall) as total_trains,
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
        e.trainType as metric_scope,
        COUNT(*) as total_events,
        COALESCE(t.total_trains, 0) as total_trains,
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

    FROM commercial_events e
    LEFT JOIN trains_by_type t
        ON t.trainType IS NOT DISTINCT FROM e.trainType
    GROUP BY e.trainType, t.total_trains
),

by_train_category AS (
    SELECT
        e.trainCategory as metric_scope,
        COUNT(*) as total_events,
        COALESCE(t.total_trains, 0) as total_trains,
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

    FROM commercial_events e
    LEFT JOIN trains_by_category t
        ON t.trainCategory IS NOT DISTINCT FROM e.trainCategory
    GROUP BY e.trainCategory, t.total_trains
),

combined AS (
    SELECT 1 as scope_rank, * FROM overall_metrics
    UNION ALL
    SELECT 2, * FROM by_train_type
    UNION ALL
    SELECT 3, * FROM by_train_category
)

SELECT * EXCLUDE (scope_rank) FROM combined
ORDER BY
    CASE
        WHEN metric_scope = 'Overall' THEN 1
        WHEN metric_scope IN ('Long-distance', 'Commuter') THEN 2
        ELSE 3
    END,
    metric_scope,
    -- a NULL trainType and a NULL trainCategory tie on metric_scope: type row first
    scope_rank
