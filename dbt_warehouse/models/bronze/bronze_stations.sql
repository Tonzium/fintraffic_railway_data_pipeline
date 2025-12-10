-- bronze_stations.sql
-- Description: Load Finnish railway stations from staging JSON into bronze layer
-- Materialization: Full refresh (table is small, ~455 rows)
-- Source: data/staging/stations/stations.json

{{ config(
    materialized='table'
) }}

WITH stations_raw AS (
    SELECT *
    FROM read_json(
        '{{ var("staging_path") }}/stations/stations.json',
        format='array',
        columns={
            'stationShortCode': 'VARCHAR',
            'stationName': 'VARCHAR',
            'stationUICCode': 'INTEGER',
            'latitude': 'DOUBLE',
            'longitude': 'DOUBLE',
            'passengerTraffic': 'BOOLEAN',
            'type': 'VARCHAR',
            'countryCode': 'VARCHAR'
        }
    )
),

surrogate_key_added AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['stationShortCode']) }} as sk_station,

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

    FROM stations_raw
)

SELECT * FROM surrogate_key_added
