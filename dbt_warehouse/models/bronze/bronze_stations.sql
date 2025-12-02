-- bronze_stations.sql
-- Description: Load Finnish railway stations from staging JSON into bronze layer
-- Materialization: Full refresh (table is small, ~455 rows)
-- Source: data/staging/stations/stations.json

{{ config(
    materialized='table'
) }}

WITH source_data AS (
    SELECT
        -- Source columns
        stationShortCode,
        stationName,
        stationUICCode,
        latitude,
        longitude,
        passengerTraffic,
        type,
        countryCode,

        -- Metadata
        CURRENT_TIMESTAMP AS _loaded_at,
        'stations/stations.json' AS _source_file,
        '{{ invocation_id }}' AS _dbt_run_id

    FROM read_json_auto(
        '{{ var("staging_path") }}/stations/stations.json',
        format='array',
        ignore_errors=false
    )
)

SELECT * FROM source_data
