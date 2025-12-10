-- bronze_train_departures.sql
-- Description: Load train departure data with nested timeTableRows structure
-- Materialization: Incremental (append new dates only)
-- Source: data/staging/train_departure_date/**/*.json
-- Partitioning: By departureDate

{{ config(
    materialized='incremental',
    unique_key=['trainNumber', 'departureDate']
) }}

WITH trains_raw AS (
    SELECT *
    FROM read_json(
        '{{ var("staging_path") }}/train_departure_date/**/*.json',
        format='array',
        filename=true,
        union_by_name=true,
        ignore_errors=false,
        maximum_object_size=52428800,  -- 50MB per object
        columns={
            'trainNumber': 'INTEGER',
            'departureDate': 'DATE',
            'operatorUICCode': 'INTEGER',
            'operatorShortCode': 'VARCHAR',
            'trainType': 'VARCHAR',
            'trainCategory': 'VARCHAR',
            'commuterLineID': 'VARCHAR',
            'runningCurrently': 'BOOLEAN',
            'cancelled': 'BOOLEAN',
            'version': 'BIGINT',
            'timetableType': 'VARCHAR',
            'timetableAcceptanceDate': 'TIMESTAMP',
            'timeTableRows': 'JSON'  -- Keep nested as JSON
        }
    )
),

surrogate_key_added AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['trainNumber', 'departureDate']) }} as sk_train_departure,

        -- Train identification
        trainNumber,
        departureDate,

        -- Operator information
        operatorUICCode,
        operatorShortCode,

        -- Train classification
        trainType,
        trainCategory,
        commuterLineID,

        -- Status flags
        runningCurrently,
        cancelled,

        -- Metadata from source
        version,
        timetableType,
        timetableAcceptanceDate,

        -- KEEP NESTED: timeTableRows as JSON
        -- Contains: stationShortCode, type, scheduledTime, actualTime,
        -- differenceInMinutes, commercialTrack, trainReady, etc.
        timeTableRows,

        -- Lineage metadata
        CURRENT_TIMESTAMP AS _loaded_at,
        regexp_extract(filename, 'train_departure_date/.*\.json') AS _source_file,
        '{{ invocation_id }}' AS _dbt_run_id

    FROM trains_raw

    {% if is_incremental() %}
    -- Only load files not yet processed
    WHERE regexp_extract(filename, 'train_departure_date/.*\.json') NOT IN (
        SELECT DISTINCT _source_file FROM {{ this }}
    )
    {% endif %}
)

SELECT * FROM surrogate_key_added
