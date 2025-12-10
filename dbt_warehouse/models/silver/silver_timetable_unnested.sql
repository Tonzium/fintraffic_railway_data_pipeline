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

        -- Lineage
        t._loaded_at,
        t._source_file

    FROM train_base t
    CROSS JOIN UNNEST(t.timeTableRows) as t2(row)
    WHERE row.scheduledTime IS NOT NULL
)

SELECT * FROM flattened
