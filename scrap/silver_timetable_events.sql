-- silver_timetable_events.sql
-- Description: Flatten timeTableRows from bronze layer to create one row per station stop event
-- Materialization: Table (could be incremental for large datasets)
-- Purpose: Foundation for on-time performance analysis

{{ config(
    materialized='table',
    schema='silver'
) }}

WITH train_base AS (
    SELECT
        trainNumber,
        departureDate,
        operatorShortCode,
        trainType,
        trainCategory,
        -- cancelled as train_cancelled,
        timeTableRows,
        _loaded_at,
        _source_file
    FROM {{ ref('bronze_train_departures') }}
    WHERE NOT cancelled  -- Exclude cancelled trains from analysis
),

flattened AS (
    SELECT
        -- Train identification
        t.trainNumber,
        t.departureDate,
        t.operatorShortCode,
        t.trainType,
        t.trainCategory,
        -- t.train_cancelled,

        -- Station info from unnested row
        row.stationShortCode,
        row.stationUICCode,

        -- Event type
        row.type as event_type,
        row.trainStopping as train_stopping,
        row.commercialStop as commercial_stop,

        -- Timing
        row.scheduledTime,
        row.actualTime,
        row.differenceInMinutes as delay_minutes,

        -- Additional details
        -- row.commercialTrack as platform,
        -- row.cancelled as event_cancelled

    FROM train_base t
    CROSS JOIN UNNEST(t.timeTableRows) as t2(row)
    WHERE row.scheduledTime IS NOT NULL
),

parsed_events AS (
    SELECT
        -- Train info
        trainNumber,
        departureDate,
        operatorShortCode,
        trainType,
        trainCategory,
        -- train_cancelled,

        -- Station info
        stationShortCode,
        stationUICCode,

        -- Event type
        event_type,
        train_stopping,
        commercial_stop,

        -- Timing (convert from ISO8601 to timestamp)
        strptime(scheduledTime, '%Y-%m-%dT%H:%M:%S.%fZ') as scheduled_time,
        strptime(actualTime, '%Y-%m-%dT%H:%M:%S.%fZ') as actual_time,
        delay_minutes,

        -- Additional details
        -- platform,
        -- event_cancelled,

        -- Extract date/time components for analysis
        date_part('hour', strptime(scheduledTime, '%Y-%m-%dT%H:%M:%S.%fZ')) as scheduled_hour,
        date_part('dow', strptime(scheduledTime, '%Y-%m-%dT%H:%M:%S.%fZ')) as day_of_week,

        -- Calculate if on-time (within 5 minute threshold)
        CASE
            WHEN delay_minutes IS NULL THEN NULL
            WHEN delay_minutes <= 5 THEN true
            ELSE false
        END as is_on_time,

        -- Delay categories
        CASE
            WHEN delay_minutes IS NULL THEN 'unknown'
            WHEN delay_minutes < 0 THEN 'early'
            WHEN delay_minutes <= 5 THEN 'on_time'
            WHEN delay_minutes <= 15 THEN 'slightly_late'
            WHEN delay_minutes <= 30 THEN 'late'
            ELSE 'very_late'
        END as delay_category

    FROM flattened
)

SELECT * FROM parsed_events
