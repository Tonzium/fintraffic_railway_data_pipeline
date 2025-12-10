-- gold_ic_vs_hdm_comparison.sql
-- Description: Detailed comparison between IC (InterCity) and HDM trains
-- Materialization: Table
-- Purpose: Answer specific business question: Which train type performs better?

{{ config(
    materialized='table',
    schema='gold'
) }}

WITH ic_hdm_events AS (
    -- Filter for only IC and HDM trains at commercial stops
    SELECT *
    FROM {{ ref('silver_fact_timetable_events') }}
    WHERE trainType IN ('IC', 'HDM')
    AND commercial_stop = true
    AND actual_time IS NOT NULL
),

performance_by_type AS (
    SELECT
        trainType,

        -- Volume metrics
        COUNT(*) as total_stops,
        COUNT(DISTINCT trainNumber || '_' || departureDate) as total_trains,
        COUNT(DISTINCT stationShortCode) as stations_served,
        COUNT(DISTINCT DATE_TRUNC('day', scheduled_time)) as operating_days,

        -- On-time performance
        SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) as on_time_stops,
        ROUND(100.0 * SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) / COUNT(*), 2) as on_time_percentage,

        -- Delay statistics
        ROUND(AVG(delay_minutes), 2) as avg_delay_minutes,
        ROUND(MEDIAN(delay_minutes), 2) as median_delay_minutes,
        ROUND(STDDEV(delay_minutes), 2) as stddev_delay_minutes,
        MIN(delay_minutes) as min_delay_minutes,
        MAX(delay_minutes) as max_delay_minutes,

        -- Percentiles for delay distribution
        ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY delay_minutes), 2) as p25_delay,
        ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY delay_minutes), 2) as p75_delay,
        ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY delay_minutes), 2) as p90_delay,
        ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY delay_minutes), 2) as p95_delay,

        -- Delay categories breakdown
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'early' THEN 1 ELSE 0 END) / COUNT(*), 2) as early_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'on_time' THEN 1 ELSE 0 END) / COUNT(*), 2) as on_time_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'slightly_late' THEN 1 ELSE 0 END) / COUNT(*), 2) as slightly_late_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'late' THEN 1 ELSE 0 END) / COUNT(*), 2) as late_pct,
        ROUND(100.0 * SUM(CASE WHEN delay_category = 'very_late' THEN 1 ELSE 0 END) / COUNT(*), 2) as very_late_pct,

        -- Event type breakdown
        SUM(CASE WHEN event_type = 'ARRIVAL' THEN 1 ELSE 0 END) as arrival_count,
        SUM(CASE WHEN event_type = 'DEPARTURE' THEN 1 ELSE 0 END) as departure_count,

        -- Arrival vs Departure OTP
        ROUND(100.0 * SUM(CASE WHEN event_type = 'ARRIVAL' AND is_on_time THEN 1 ELSE 0 END) /
              NULLIF(SUM(CASE WHEN event_type = 'ARRIVAL' THEN 1 ELSE 0 END), 0), 2) as arrival_otp,
        ROUND(100.0 * SUM(CASE WHEN event_type = 'DEPARTURE' AND is_on_time THEN 1 ELSE 0 END) /
              NULLIF(SUM(CASE WHEN event_type = 'DEPARTURE' THEN 1 ELSE 0 END), 0), 2) as departure_otp

    FROM ic_hdm_events
    GROUP BY trainType
),

time_of_day_comparison AS (
    SELECT
        trainType,
        scheduled_hour,
        COUNT(*) as stops,
        ROUND(100.0 * SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) / COUNT(*), 2) as otp_pct,
        ROUND(AVG(delay_minutes), 2) as avg_delay
    FROM ic_hdm_events
    GROUP BY trainType, scheduled_hour
),

day_of_week_comparison AS (
    SELECT
        trainType,
        day_of_week,
        CASE day_of_week
            WHEN 0 THEN 'Sunday'
            WHEN 1 THEN 'Monday'
            WHEN 2 THEN 'Tuesday'
            WHEN 3 THEN 'Wednesday'
            WHEN 4 THEN 'Thursday'
            WHEN 5 THEN 'Friday'
            WHEN 6 THEN 'Saturday'
        END as day_name,
        COUNT(*) as stops,
        ROUND(100.0 * SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) / COUNT(*), 2) as otp_pct,
        ROUND(AVG(delay_minutes), 2) as avg_delay
    FROM ic_hdm_events
    GROUP BY trainType, day_of_week
),

-- Station-level performance comparison
station_comparison AS (
    SELECT
        trainType,
        stationShortCode,
        COUNT(*) as stops,
        ROUND(100.0 * SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) / COUNT(*), 2) as otp_pct,
        ROUND(AVG(delay_minutes), 2) as avg_delay
    FROM ic_hdm_events
    GROUP BY trainType, stationShortCode
    HAVING COUNT(*) >= 10  -- Only stations with sufficient data
)

-- Output overall comparison
SELECT
    trainType as train_type,
    total_stops,
    total_trains,
    stations_served,
    operating_days,
    on_time_stops,
    on_time_percentage,
    avg_delay_minutes,
    median_delay_minutes,
    stddev_delay_minutes,
    min_delay_minutes,
    max_delay_minutes,
    p25_delay,
    p75_delay,
    p90_delay,
    p95_delay,
    early_pct,
    on_time_pct,
    slightly_late_pct,
    late_pct,
    very_late_pct,
    arrival_count,
    departure_count,
    arrival_otp,
    departure_otp,

    -- Winner indicator (which train type is better)
    CASE
        WHEN trainType = 'IC' THEN
            CASE
                WHEN on_time_percentage > (SELECT on_time_percentage FROM performance_by_type WHERE trainType = 'HDM')
                THEN 'Winner: Better OTP'
                ELSE 'Behind HDM'
            END
        WHEN trainType = 'HDM' THEN
            CASE
                WHEN on_time_percentage > (SELECT on_time_percentage FROM performance_by_type WHERE trainType = 'IC')
                THEN 'Winner: Better OTP'
                ELSE 'Behind IC'
            END
    END as performance_verdict

FROM performance_by_type
ORDER BY on_time_percentage DESC
