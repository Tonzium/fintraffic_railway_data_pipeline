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

{#- Column types are pinned. Letting DuckDB detect them across files (union_by_name)
    keeps a reader per file: a full refresh over a year of files then needs ~10 GB and
    fails under the 4 GB memory_limit; pinned, it stays inside the limit. The STRUCT
    holds every field Digitraffic sends today. Keys that are not listed are ignored and
    a missing key reads as NULL, so new API fields cannot break a load. -#}
{% set timetable_rows_type -%}
STRUCT("type" VARCHAR, commercialTrack VARCHAR, cancelled BOOLEAN, scheduledTime VARCHAR, actualTime VARCHAR, differenceInMinutes BIGINT, commercialStop BOOLEAN, causes STRUCT(categoryCode VARCHAR, categoryCodeId BIGINT, detailedCategoryCode VARCHAR, detailedCategoryCodeId BIGINT, thirdCategoryCode VARCHAR, thirdCategoryCodeId BIGINT)[], stationShortCode VARCHAR, stationUICCode BIGINT, countryCode VARCHAR, trainReady STRUCT(accepted BOOLEAN, "source" VARCHAR, "timestamp" VARCHAR), trainStopping BOOLEAN, liveEstimateTime VARCHAR, estimateSource VARCHAR, stopSector VARCHAR, unknownDelay BOOLEAN, unknownTrack BOOLEAN)[]
{%- endset %}

{#- List the daily files to read: all of them for a full refresh, only the reload window
    for an incremental run. glob() only lists names, so this costs nothing even with a
    year of files on disk. Only finished files count, never an in-progress *.tmp. -#}
{% set files = [] %}
{% if execute %}
    {% set files_query %}
        SELECT file
        FROM glob('{{ daily_glob }}')
        WHERE regexp_matches(file, '\d{4}-\d{2}-\d{2}\.json(\.gz)?$')
        {% if is_incremental() -%}
          AND TRY_CAST(regexp_extract(file, '(\d{4}-\d{2}-\d{2})\.json', 1) AS DATE) >= current_date - {{ reload_days }}
        {%- endif %}
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
        timeTableRows,
        filename
    FROM read_json(
        {% if files | length > 0 -%}
        [{% for f in files %}'{{ f }}'{% if not loop.last %}, {% endif %}{% endfor %}],
        {%- else -%}
        '{{ daily_glob }}',  -- no daily files at all: fails loudly on a first run without data
        {%- endif %}
        format='array',
        filename=true,
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
            'timeTableRows': '{{ timetable_rows_type }}'
        },
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
        regexp_extract(replace(filename, chr(92), '/'), 'train_departure_date/.*\.json(\.gz)?') AS _source_file,
        '{{ invocation_id }}' AS _dbt_run_id

    FROM trains_raw

    -- One row per train and day, even if a day is ever present in two files.
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY trainNumber, departureDate
        ORDER BY version DESC, filename DESC
    ) = 1
)

SELECT * FROM surrogate_key_added
