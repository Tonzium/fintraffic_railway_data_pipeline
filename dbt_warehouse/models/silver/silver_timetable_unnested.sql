-- silver_timetable_unnested.sql
-- Description: Unnest timeTableRows from bronze into flat structure
-- Purpose: Technical transformation - just unnesting, minimal processing
-- Materialization: Table

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

        -- Station info from unnested row
        unnest.stationShortCode,
        unnest.stationUICCode,

        -- Event type
        unnest.type as event_type,
        unnest.trainStopping as train_stopping,
        unnest.commercialStop as commercial_stop,

        -- Timing
        unnest.scheduledTime,
        unnest.actualTime,
        unnest.differenceInMinutes as delay_minutes,

        -- Lineage
        t._loaded_at,
        t._source_file

    FROM train_base t,
         UNNEST(t.timeTableRows)
    WHERE unnest.scheduledTime IS NOT NULL
)

SELECT * FROM flattened
