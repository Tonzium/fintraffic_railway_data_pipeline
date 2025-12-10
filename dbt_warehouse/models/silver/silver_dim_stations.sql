-- silver_dim_stations.sql
-- Description: Station dimension table with enhanced attributes
-- Purpose: Reference dimension for station analysis
-- Materialization: Table

{{ config(
    materialized='table',
    schema='silver'
) }}

WITH stations_base AS (
    SELECT
        sk_station,
        stationShortCode,
        stationName,
        stationUICCode,
        latitude,
        longitude,
        passengerTraffic,
        type,
        countryCode,
        _loaded_at,
        _source_file
    FROM {{ ref('bronze_stations') }}
),

stations_enhanced AS (
    SELECT
        sk_station,
        stationShortCode,
        stationName,
        stationUICCode,
        latitude,
        longitude,
        passengerTraffic,
        type,
        countryCode,

        -- Derived attributes: Station type categories
        CASE
            WHEN type = 'STATION' THEN 'Major Station'
            WHEN type = 'STOPPING_POINT' THEN 'Stopping Point'
            WHEN type = 'TURNOUT_IN_THE_OPEN_LINE' THEN 'Turnout'
            ELSE 'Unknown'
        END as station_type_label,

        -- Derived attributes: Passenger service flag
        CASE
            WHEN passengerTraffic = true THEN 'Passenger Service'
            ELSE 'No Passenger Service'
        END as passenger_service_label,

        -- Derived attributes: Geographic region (simplified example)
        CASE
            WHEN stationShortCode IN ('HKI', 'PSL', 'LPV', 'MLO', 'KÄP', 'OLK', 'PLA', 'AVP', 'HPK', 'TKL', 'KEH') THEN 'Helsinki Region'
            WHEN stationShortCode IN ('TPE', 'LPR', 'VKS', 'TRE') THEN 'Tampere Region'
            WHEN stationShortCode IN ('TKU', 'KRS', 'LIA', 'SAV') THEN 'Turku Region'
            WHEN stationShortCode IN ('OUL', 'KEM', 'ROI') THEN 'Northern Finland'
            WHEN stationShortCode IN ('JY', 'JPH', 'JYS') THEN 'Central Finland'
            ELSE 'Other Region'
        END as region,

        -- Metadata
        _loaded_at,
        _source_file,
        CURRENT_TIMESTAMP as dim_updated_at

    FROM stations_base
)

SELECT * FROM stations_enhanced
