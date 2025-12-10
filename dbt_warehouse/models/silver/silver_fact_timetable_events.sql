-- silver_fact_timetable_events.sql
-- Description: Fact table for timetable events with business logic
-- Purpose: Event-level facts with derived metrics for analytics
-- Materialization: Table

{{ config(
    materialized='table',
    schema='silver'
) }}

WITH unnested_events AS (
    SELECT * FROM {{ ref('silver_timetable_unnested') }}
),

events_with_business_logic AS (
    SELECT
        -- Generate surrogate key for each event
        {{ dbt_utils.generate_surrogate_key([
            'trainNumber',
            'departureDate',
            'stationShortCode',
            'event_type',
            'scheduledTime'
        ]) }} as sk_event,

        -- Train identification
        trainNumber,
        departureDate,
        operatorShortCode,
        trainType,
        trainCategory,

        -- Station info
        stationShortCode,
        stationUICCode,

        -- Event details
        event_type,
        train_stopping,
        commercial_stop,

        -- Timing (parsed to proper timestamps)
        strptime(scheduledTime, '%Y-%m-%dT%H:%M:%S.%fZ') as scheduled_time,
        strptime(actualTime, '%Y-%m-%dT%H:%M:%S.%fZ') as actual_time,
        delay_minutes,

        -- Extract date/time components for analysis
        date_part('hour', strptime(scheduledTime, '%Y-%m-%dT%H:%M:%S.%fZ')) as scheduled_hour,
        date_part('dow', strptime(scheduledTime, '%Y-%m-%dT%H:%M:%S.%fZ')) as day_of_week,
        date_part('month', strptime(scheduledTime, '%Y-%m-%dT%H:%M:%S.%fZ')) as scheduled_month,
        date_part('year', strptime(scheduledTime, '%Y-%m-%dT%H:%M:%S.%fZ')) as scheduled_year,

        -- Derived metrics: On-time classification
        CASE
            WHEN delay_minutes IS NULL THEN NULL
            WHEN delay_minutes <= 5 THEN true
            ELSE false
        END as is_on_time,

        -- Derived metrics: Delay categories
        CASE
            WHEN delay_minutes IS NULL THEN 'unknown'
            WHEN delay_minutes < 0 THEN 'early'
            WHEN delay_minutes <= 5 THEN 'on_time'
            WHEN delay_minutes <= 15 THEN 'slightly_late'
            WHEN delay_minutes <= 30 THEN 'late'
            ELSE 'very_late'
        END as delay_category,

        -- Derived metrics: Time of day categories
        CASE
            WHEN date_part('hour', strptime(scheduledTime, '%Y-%m-%dT%H:%M:%S.%fZ')) BETWEEN 6 AND 9 THEN 'morning_rush'
            WHEN date_part('hour', strptime(scheduledTime, '%Y-%m-%dT%H:%M:%S.%fZ')) BETWEEN 16 AND 19 THEN 'evening_rush'
            ELSE 'off_peak'
        END as time_of_day_category,

        -- Derived metrics: Weekend flag
        CASE
            WHEN date_part('dow', strptime(scheduledTime, '%Y-%m-%dT%H:%M:%S.%fZ')) IN (0, 6) THEN true
            ELSE false
        END as is_weekend,

        -- Lineage
        _loaded_at,
        _source_file

    FROM unnested_events
)

SELECT * FROM events_with_business_logic
