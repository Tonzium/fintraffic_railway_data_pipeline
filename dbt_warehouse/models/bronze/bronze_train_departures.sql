-- bronze_train_departures.sql
-- Description: Load train departure data with nested timeTableRows structure
-- Materialization: Incremental, delete+insert by departureDate
-- Source: data/staging/train_departure_date/YYYY/MM/YYYY-MM-DD.json.gz (plain .json is read too)
--
-- A full refresh (first run, or dbt build --full-refresh) reads every daily file.
-- An incremental run reads only the files of the last `reload_days` days (the
-- ingestion window, BACKFILL_DAYS in demo/run_pipeline.sh) and replaces those days
-- completely. A day first fetched at 07:00 holds only the trains run so far; the
-- re-fetches on the following days complete it. Reading only the window also keeps
-- the run fast and stops an old unreadable file from failing every build.
-- Days older than `retention_days` are deleted by the post-hook.

{% set reload_days = var('reload_days', 7) | int %}
{% set daily_glob = var('staging_path') ~ '/train_departure_date/*/*/*.json*' %}

{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='departureDate',
    on_schema_change='append_new_columns',
    post_hook="DELETE FROM {{ this }} WHERE departureDate < current_date - " ~ (var('retention_days', 365) | int)
) }}

{#- Incremental runs: list the daily files inside the reload window. glob() only lists
    names, so this costs nothing even with a year of files on disk. -#}
{% set files = [] %}
{% if execute and is_incremental() %}
    {% set files_query %}
        SELECT file
        FROM glob('{{ daily_glob }}')
        WHERE TRY_CAST(regexp_extract(file, '(\d{4}-\d{2}-\d{2})\.json', 1) AS DATE) >= current_date - {{ reload_days }}
        ORDER BY file
    {% endset %}
    {% set files = run_query(files_query).columns[0].values() | list %}
{% endif %}

WITH trains_raw AS (
{% if is_incremental() and files | length == 0 %}
    -- No daily files in the reload window: load nothing (keeps the target's shape).
    SELECT
        trainNumber, departureDate, operatorUICCode, operatorShortCode, trainType,
        trainCategory, commuterLineID, runningCurrently, cancelled, version,
        timetableType, timetableAcceptanceDate, timeTableRows,
        _source_file AS filename
    FROM {{ this }}
    WHERE false
{% else %}
    SELECT
        trainNumber::INTEGER as trainNumber,
        departureDate::DATE as departureDate,
        operatorUICCode::INTEGER as operatorUICCode,
        operatorShortCode::VARCHAR as operatorShortCode,
        trainType::VARCHAR as trainType,
        trainCategory::VARCHAR as trainCategory,
        commuterLineID::VARCHAR as commuterLineID,
        runningCurrently::BOOLEAN as runningCurrently,
        cancelled::BOOLEAN as cancelled,
        version::BIGINT as version,
        timetableType::VARCHAR as timetableType,
        timetableAcceptanceDate::TIMESTAMP as timetableAcceptanceDate,
        timeTableRows,  -- Let DuckDB auto-infer as STRUCT[]
        filename
    FROM read_json(
        {% if is_incremental() -%}
        [{% for f in files %}'{{ f }}'{% if not loop.last %}, {% endif %}{% endfor %}],
        {%- else -%}
        '{{ daily_glob }}',
        {%- endif %}
        format='array',
        filename=true,
        union_by_name=true,
        ignore_errors=false,
        maximum_object_size=52428800  -- 50MB per object
    )
{% endif %}
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

        -- Lineage metadata (path normalised to '/' so it looks the same on Windows)
        CURRENT_TIMESTAMP AS _loaded_at,
        regexp_extract(replace(filename, chr(92), '/'), 'train_departure_date/.*\.json') AS _source_file,
        '{{ invocation_id }}' AS _dbt_run_id

    FROM trains_raw

    -- One row per train and day, even if a day is ever present in two files.
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY trainNumber, departureDate
        ORDER BY version DESC, filename DESC
    ) = 1
)

SELECT * FROM surrogate_key_added
