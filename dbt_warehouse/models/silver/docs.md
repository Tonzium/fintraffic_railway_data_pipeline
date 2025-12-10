{% docs silver_timetable_unnested %}

# 📂 Silver: Timetable Unnested (Technical Transformation)

## Overview

**Technical unnesting layer** that transforms nested timeTableRows arrays from bronze into flat, one-row-per-event structure.

## Purpose

This model performs the **core technical transformation** - unnesting nested JSON without adding business logic. It serves as a foundation for downstream fact tables.

## Why Separate This?

### Separation of Concerns
- **Technical** transformation (unnesting) separated from **business** logic
- Easier to maintain and troubleshoot
- Reusable for multiple downstream use cases

### Performance
- Single unnesting operation
- Downstream models query flat table (no repeated unnesting)
- Can be materialized efficiently

## Data Model

### Input
- Bronze: 1 train → 1 row with nested array (10-30+ stops)

### Output
- Silver: 1 train → 20-60 rows (one per event)

### Grain
**One row per timetable event** (arrival or departure at a station)

## Transformations Applied

### 1️⃣ UNNEST Operation
```sql
CROSS JOIN UNNEST(t.timeTableRows) as t2(row)
```

Expands nested array into individual rows.

### 2️⃣ Filters Applied
- `WHERE NOT cancelled` - Exclude cancelled trains
- `WHERE row.scheduledTime IS NOT NULL` - Only scheduled events

### 3️⃣ Column Selection
Minimal processing - just selecting needed columns:
- Train identification (trainNumber, departureDate, etc.)
- Station info (stationShortCode, stationUICCode)
- Event details (event_type, scheduledTime, actualTime, delay_minutes)
- Lineage metadata

### 4️⃣ What's NOT Done Here
❌ No timestamp parsing  
❌ No business logic  
❌ No derived metrics  
❌ No surrogate keys  

*These are handled in the fact table layer*

## Column Details

### Train Attributes (from parent train)
- `trainNumber`: Train identifier
- `departureDate`: Original departure date
- `operatorShortCode`: Operating company
- `trainType`: IC, S, HDM, etc.
- `trainCategory`: Long-distance, Commuter, etc.

### Event Attributes (from unnested row)
- `stationShortCode`: Station code
- `stationUICCode`: International station ID
- `event_type`: ARRIVAL or DEPARTURE
- `train_stopping`: Boolean
- `commercial_stop`: Whether passengers can board
- `scheduledTime`: ISO8601 string (NOT parsed yet)
- `actualTime`: ISO8601 string (NOT parsed yet)
- `delay_minutes`: Raw difference in minutes

### Lineage
- `_loaded_at`: When loaded into bronze
- `_source_file`: Source JSON file path

## Performance Characteristics

### Volume
Based on 40 days of data:
- **Input**: ~50,000 trains
- **Output**: ~950,000 events
- **Expansion**: ~19x

### Build Time
- ~3-4 seconds for 40 days
- Scales linearly with data volume

## Usage

This model is **not typically queried directly**. It serves as input to:
- `silver_fact_timetable_events` - Adds business logic
- Other potential fact tables

## Example Output

```sql
SELECT * FROM silver_timetable_unnested LIMIT 3;
```

| trainNumber | departureDate | stationShortCode | event_type | scheduledTime | delay_minutes |  
|-------------|---------------|------------------|------------|---------------|---------------|  
| 123 | 2024-12-01 | HKI | DEPARTURE | 2024-12-01T10:00:00.000Z | 0 |  
| 123 | 2024-12-01 | PSL | ARRIVAL | 2024-12-01T10:15:00.000Z | 2 |  
| 123 | 2024-12-01 | PSL | DEPARTURE | 2024-12-01T10:17:00.000Z | 1 |  

---

**Model Type**: Transformation (unnesting)  
**Materialization**: Table  
**Upstream**: bronze_train_departures  
**Downstream**: silver_fact_timetable_events  

{% enddocs %}

{% docs silver_fact_timetable_events %}

# 🎯 Silver: Fact Timetable Events (Main Analytical Table)

## Overview

**Event-level fact table** containing all timetable events with parsed timestamps, derived metrics, and business logic applied. This is the **primary table for analytics**.

## Business Value

This table powers all on-time performance analysis by providing:
- ✅ Clean, typed timestamps for time-based analysis
- ✅ Derived on-time flags and delay categories
- ✅ Surrogate keys for data warehouse best practices
- ✅ Time components (hour, day of week, month)
- ✅ Business categorizations (rush hour, weekend)

## Data Model

### Grain
**One row per timetable event** with unique surrogate key

### Surrogate Key
```sql
sk_event = MD5(trainNumber || departureDate || stationShortCode ||
               event_type || scheduledTime)
```

Ensures each event is uniquely identified.

## Key Features

### 1️⃣ Parsed Timestamps

**From string to TIMESTAMP:**
```sql
strptime(scheduledTime, '%Y-%m-%dT%H:%M:%S.%fZ') as scheduled_time
```

Enables:
- Date/time arithmetic
- Filtering by time ranges
- Accurate time component extraction

### 2️⃣ On-Time Classification

```sql
is_on_time = CASE
    WHEN delay_minutes <= 5 THEN true
    ELSE false
END
```

**Industry Standard**: 5-minute threshold
**Usage**: Simple boolean for calculating OTP%

### 3️⃣ Delay Categories

| Category | Range | Use Case |  
|----------|-------|----------|  
| **early** | < 0 min | Connection risk analysis |  
| **on_time** | 0-5 min | Target performance |  
| **slightly_late** | 6-15 min | Service quality monitoring |  
| **late** | 16-30 min | Compensation thresholds |  
| **very_late** | 30+ min | Critical incidents |  

### 4️⃣ Time Components

**Extracted for analysis:**
- `scheduled_hour` (0-23): For hourly patterns
- `day_of_week` (0-6): For weekly trends
- `scheduled_month` (1-12): For seasonality
- `scheduled_year`: For year-over-year comparisons

### 5️⃣ Business Categories

#### Time of Day
```sql
time_of_day_category:
- 'morning_rush' (6-9 AM)
- 'evening_rush' (4-7 PM)
- 'off_peak' (other hours)
```

#### Weekend Flag
```sql
is_weekend = CASE
    WHEN day_of_week IN (0, 6) THEN true
    ELSE false
END
```

## Column Reference

### Identifiers
- `sk_event`: Surrogate key (unique)
- `trainNumber`: Train identifier
- `departureDate`: Departure date
- `stationShortCode`: Station code

### Dimensions
- `operatorShortCode`: Operating company
- `trainType`: IC, S, HDM, P, etc.
- `trainCategory`: Long-distance, Commuter, Cargo
- `event_type`: ARRIVAL or DEPARTURE

### Facts
- `delay_minutes`: Actual delay (negative = early)
- `scheduled_time`: When supposed to happen
- `actual_time`: When it actually happened

### Derived Metrics
- `is_on_time`: Boolean (delay <= 5 min)
- `delay_category`: Categorical classification
- `time_of_day_category`: Rush hour vs off-peak
- `is_weekend`: Weekend flag

### Time Components
- `scheduled_hour`: Hour (0-23)
- `day_of_week`: Day (0=Sun, 6=Sat)
- `scheduled_month`: Month (1-12)
- `scheduled_year`: Year

## Analytical Use Cases

### On-Time Performance by Hour
```sql
SELECT
    scheduled_hour,
    ROUND(100.0 * SUM(CASE WHEN is_on_time THEN 1 ELSE 0 END) / COUNT(*), 2) as otp
FROM silver_fact_timetable_events
WHERE commercial_stop = true
  AND actual_time IS NOT NULL
GROUP BY scheduled_hour
ORDER BY scheduled_hour;
```

### Rush Hour vs Off-Peak
```sql
SELECT
    time_of_day_category,
    AVG(delay_minutes) as avg_delay,
    COUNT(*) as events
FROM silver_fact_timetable_events
WHERE actual_time IS NOT NULL
GROUP BY time_of_day_category;
```

### Weekend Performance
```sql
SELECT
    is_weekend,
    trainType,
    ROUND(AVG(delay_minutes), 2) as avg_delay
FROM silver_fact_timetable_events
WHERE actual_time IS NOT NULL
GROUP BY is_weekend, trainType;
```

## Data Quality

### Tests Applied
✅ `sk_event` is unique  
✅ `trainNumber` not null  
✅ `event_type` in ('ARRIVAL', 'DEPARTURE')  
✅ `delay_category` in valid values  

### Filters
- Only non-cancelled trains (applied upstream)
- Only events with scheduled times

## Performance

### Volume
- ~950,000 events for 40 days of data
- ~200 MB table size

### Query Performance
- Indexed on `sk_event`, `trainNumber`, `departureDate`
- Typical aggregation: 0.3-0.5 seconds

## Model Lineage

```
bronze_train_departures
    ↓
silver_timetable_unnested
    ↓
silver_fact_timetable_events ← YOU ARE HERE
    ↓
gold_on_time_performance
gold_ic_vs_hdm_comparison
```

---

**Model Type**: Fact Table
**Materialization**: Table
**Grain**: One row per timetable event
**Primary Key**: sk_event
**Created**: 2024-12-10

{% enddocs %}

{% docs silver_dim_stations %}

# 🚉 Silver: Station Dimension (Enhanced Reference Data)

## Overview

**Enhanced station dimension table** providing reference data for all railway stations with derived attributes for analysis.

## Purpose

Dimensional table that:
- 📍 Provides station master data
- 🏷️ Adds business classifications
- 🗺️ Includes geographic groupings
- 🔗 Joins with fact tables for enriched analysis

## Data Model

### Grain
**One row per station** (slowly changing dimension - SCD Type 1)

### Primary Key
- **Surrogate**: `sk_station` (MD5 hash)
- **Natural**: `stationShortCode` (3-letter code)

## Source Data

Base data from `bronze_stations`:
- Station codes and names
- GPS coordinates
- Station type
- Passenger service flags

## Enhancements Added

### 1️⃣ Station Type Labels

Human-readable classification:
```sql
station_type_label:
- 'Major Station' (STATION)
- 'Stopping Point' (STOPPING_POINT)
- 'Turnout' (TURNOUT_IN_THE_OPEN_LINE)
```

### 2️⃣ Passenger Service Labels

```sql
passenger_service_label:
- 'Passenger Service' (passengerTraffic = true)
- 'No Passenger Service' (passengerTraffic = false)
```

### 3️⃣ Regional Classification

Simplified geographic regions:
- **Helsinki Region**: HKI, PSL, LPV, MLO, KÄP, OLK, etc.
- **Tampere Region**: TPE, LPR, VKS, TRE
- **Turku Region**: TKU, KRS, LIA, SAV
- **Northern Finland**: OUL, KEM, ROI
- **Central Finland**: JY, JPH, JYS
- **Other Region**: All other stations

**Note**: This is a simplified mapping. Enhance with actual geographic data for production use.

## Column Reference

### Identifiers
- `sk_station`: Surrogate key (MD5 hash)
- `stationShortCode`: 3-letter code (e.g., HKI)
- `stationUICCode`: International station identifier

### Attributes
- `stationName`: Full station name (e.g., "Helsinki")
- `latitude`: GPS latitude
- `longitude`: GPS longitude
- `passengerTraffic`: Boolean (serves passengers?)
- `type`: Technical type code
- `countryCode`: ISO country code (FI)

### Derived Attributes
- `station_type_label`: Human-readable type
- `passenger_service_label`: Service classification
- `region`: Geographic region grouping

### Metadata
- `_loaded_at`: When loaded into bronze
- `_source_file`: Source file
- `dim_updated_at`: Last dimension update timestamp

## Analytical Use Cases

### Regional Performance Analysis
```sql
SELECT
    s.region,
    COUNT(DISTINCT f.trainNumber) as trains,
    ROUND(AVG(f.delay_minutes), 2) as avg_delay
FROM silver_fact_timetable_events f
JOIN silver_dim_stations s ON f.stationShortCode = s.stationShortCode
WHERE f.actual_time IS NOT NULL
GROUP BY s.region
ORDER BY avg_delay DESC;
```

### Station Characteristics
```sql
SELECT
    station_type_label,
    passenger_service_label,
    COUNT(*) as station_count
FROM silver_dim_stations
GROUP BY station_type_label, passenger_service_label;
```

### Map Integration
```sql
SELECT
    stationName,
    latitude,
    longitude,
    region,
    passenger_service_label
FROM silver_dim_stations
WHERE passengerTraffic = true
ORDER BY region, stationName;
```

## Star Schema Integration

This dimension joins with fact tables:

```sql
SELECT
    s.stationName,
    s.region,
    f.trainType,
    COUNT(*) as events,
    AVG(f.delay_minutes) as avg_delay
FROM silver_fact_timetable_events f
JOIN silver_dim_stations s
    ON f.stationShortCode = s.stationShortCode
GROUP BY s.stationName, s.region, f.trainType;
```

## Extensibility

### Add More Attributes

Potential enhancements:
```sql
-- Population of city
city_population INTEGER

-- Station amenities
has_restaurant BOOLEAN
has_parking BOOLEAN

-- Elevation
elevation_meters FLOAT

-- Climate zone
climate_zone VARCHAR
```

### Improve Regional Classification

Use actual geographic data:
```sql
-- Instead of CASE WHEN, use a reference table
LEFT JOIN ref_station_regions ON ...
```

## Data Quality

### Tests Applied
✅ `sk_station` is unique  
✅ `stationShortCode` is unique  
✅ `stationShortCode` not null  

### Referential Integrity
All `stationShortCode` in fact tables should exist in this dimension.

## SCD Type 1 Strategy

**Current Implementation**: Type 1 (overwrite)
- Changes to station data overwrite existing record
- No history tracking

**Future Enhancement**: Consider SCD Type 2 for:
- Tracking station name changes
- Historical passenger service flags
- Regional reassignments

## Model Lineage

```
bronze_stations
    ↓
silver_dim_stations ← YOU ARE HERE
    ↓
(joins with silver_fact_timetable_events)
    ↓
gold models (enriched analysis)
```

---

**Model Type**: Dimension Table (SCD Type 1)  
**Materialization**: Table  
**Grain**: One row per station  
**Primary Key**: sk_station, stationShortCode (natural key)  
**Created**: 2024-12-10  

{% enddocs %}