{% docs gold_layer_overview %}

# 🏆 Gold Layer: Business Intelligence & Analytics

The **Gold Layer** represents the final, business-ready analytical models that power executive dashboards, reporting, and data-driven decision making.

## Purpose

Gold models transform cleaned silver-layer data into:
- 📊 **KPI Dashboards**: Executive-level performance metrics
- 🎯 **Business Questions**: Specific analytical insights
- 📈 **Trend Analysis**: Time-series and comparative analytics
- 💡 **Actionable Insights**: Data that drives operational improvements

## Data Quality Standards

✅ **Aggregated**: Pre-calculated metrics for fast querying
✅ **Tested**: All metrics validated against business rules
✅ **Documented**: Clear definitions for every measure
✅ **Performant**: Optimized for BI tool consumption

## Models in Gold Layer

1. **`gold_on_time_performance`** - Overall OTP metrics across all dimensions
2. **`gold_ic_vs_hdm_comparison`** - Detailed IC vs HDM competitive analysis
3. **`gold_station_performance`** - Per-station volume and OTP for the station map
4. **Evidence page aggregates** - `gold_daily_performance`, `gold_hourly_delay_categories`,
   `gold_delay_histogram`, `gold_train_spans`, `gold_station_presence`,
   `gold_ic_hdm_station_daily`, `gold_ic_hdm_hourly_daily`, `gold_timetable_coverage`
   (see `gold_page_aggregates`)

---

**Upstream Dependencies**: Silver layer (cleaned, flattened event data)  
**Downstream Consumers**: Dashboards, Reports, Data Science notebooks

{% enddocs %}

{% docs gold_on_time_performance %}

# 📊 On-Time Performance (OTP) Dashboard Model

## Overview

Comprehensive **On-Time Performance** metrics providing executive-level visibility into Finnish railway punctuality across multiple dimensions.

## Business Value

This model answers critical business questions:
- 🎯 What is our overall on-time performance?
- 🚂 Which train types are most/least reliable?
- 📦 How do Long-distance vs Commuter services compare?
- 📉 What percentage of trains are severely delayed?
- 💰 Where should we invest to improve service quality?

## Key Metrics Defined

### On-Time Threshold
- **Definition**: Train arrives/departs within **≤5 minutes** of schedule
- **Industry Standard**: Aligned with European railway benchmarks

### Delay Categories

| Category | Delay Range | Business Impact |  
|----------|-------------|-----------------|  
| **Early** | < 0 minutes | Potential connection issues |  
| **On-Time** | 0-5 minutes | Target performance |  
| **Slightly Late** | 6-15 minutes | Passenger inconvenience |  
| **Late** | 16-30 minutes | Compensation triggers |  
| **Very Late** | > 30 minutes | Severe service disruption |  

## Aggregation Dimensions

### 1️⃣ Overall Metrics
- **Scope**: All trains, all stations, entire date range
- **Use Case**: Executive dashboard headline numbers
- **KPIs**: Overall OTP%, average delay, volume

### 2️⃣ By Train Type
- **Scope**: IC, S, HDM, P, MV, etc.
- **Use Case**: Service-type performance comparison
- **KPIs**: OTP by type, identifying worst performers

### 3️⃣ By Train Category
- **Scope**: Long-distance, Commuter, Cargo
- **Use Case**: Business segment analysis
- **KPIs**: Category-level reliability benchmarking

## Statistical Measures

- **Mean Delay**: Average delay across all events
- **Median Delay**: 50th percentile (robust to outliers)
- **Max/Min Delay**: Range boundaries for understanding extremes
- **Distribution %**: Breakdown across delay categories

## Data Filters Applied

✅ **Commercial Stops Only**: Focus on passenger-facing performance  
✅ **Completed Events Only**: Exclude scheduled-but-not-yet-occurred events  
✅ **Non-Cancelled Trains**: Only analyze trains that actually ran  

## Build Memory

The commercial-event CTE is read four times: by the train-level CTE and by three aggregations
(overall, per type, per category).
DuckDB 1.4 materialises a CTE that is referenced more than once, so it is declared
`NOT MATERIALIZED` and selects only the eight columns the aggregations use. Train counts come
from a small train-level CTE (one row per trainNumber, departureDate, type and category) instead
of `COUNT(DISTINCT trainNumber || '_' || departureDate)` over every event. The output is
unchanged. At 365 days (10.4M commercial stops) the model's peak RSS fell from about 4.2 GB to
about 0.8 GB.

## Example Query

```sql
-- Get overall performance
SELECT * FROM gold_on_time_performance
WHERE metric_scope = 'Overall';

-- Compare train types
SELECT * FROM gold_on_time_performance
WHERE metric_scope IN ('IC', 'HDM', 'S')
ORDER BY on_time_percentage DESC;
```

## Refresh Frequency

🔄 **Recommendation**: Daily refresh after new data ingestion  

## Model Lineage

```
bronze_train_departures
    ↓
silver_fact_timetable_events
    ↓
gold_on_time_performance ← YOU ARE HERE
```

## Change Log

- **2024-12-10**: Initial model creation
- **2026-09-30**: Event CTE not materialised and projected, train counts from a train-level CTE (memory)
- **Materialization**: Table (fast query performance)

{% enddocs %}

{% docs gold_ic_hdm_comparison %}

# 🚄 IC vs HDM Competitive Analysis

## Overview

**Deep-dive comparison** between IC (InterCity) and HDM (Helsinki-Turku) train services, answering the business question: *"Which train type delivers better on-time performance?"*

## Business Context

### IC (InterCity) Trains
- **Route Scope**: Nationwide long-distance network
- **Complexity**: High (71 stations, multiple routes)
- **Service Level**: Premium intercity connections
- **Volume**: ~3,500+ trains analyzed

### HDM Trains
- **Route Scope**: Helsinki-Turku corridor
- **Complexity**: Lower (27 stations, single route)
- **Service Level**: High-speed intercity shuttle
- **Volume**: ~1,000+ trains analyzed

## Analysis Dimensions

### 1️⃣ Overall Performance Metrics
- On-time percentage (primary KPI)
- Average/median delay
- Volume (trains, stops, stations)
- Operating days coverage

### 2️⃣ Statistical Distribution
- **Percentiles**: P25, P50 (median), P75, P90, P95
- **Standard Deviation**: Consistency measure
- **Min/Max**: Boundary cases

### 3️⃣ Delay Category Breakdown
Five-tier classification from "Early" to "Very Late"

### 4️⃣ Event Type Analysis
- **Arrival OTP**: End-to-end journey reliability
- **Departure OTP**: Origin punctuality
- Identifies whether delays originate at start or accumulate en route

### 5️⃣ Performance Verdict
- Automated winner determination
- Based on on-time percentage comparison
- Binary classification: "Winner: Better OTP" or "Behind [competitor]"

## Key Insights Delivered

📈 **Performance Gap**: Quantified percentage point difference  
🎯 **Winner Identification**: Clear verdict with statistical backing  
📊 **Volume Context**: Performance normalized for operational complexity  
⚙️ **Operational Patterns**: Arrival vs departure punctuality splits  
🔍 **Outlier Detection**: P95/P99 delays highlight systematic issues  

## Interpretation Guide

### High OTP + Low Complexity = Expected Excellence
*Example: HDM with 96%+ OTP on a single route*

### High OTP + High Complexity = Operational Excellence
*Benchmark: IC maintaining 90%+ OTP across 71 stations*

### Statistical Significance
- **Sample Size**: Both types have 1,000+ trains (statistically robust)
- **Confidence**: Differences >1% are operationally significant

## Business Applications

### 1. Resource Allocation
Identify which service needs more investment

### 2. Marketing Claims
Data-backed reliability statements

### 3. Service Planning
Route complexity vs performance trade-offs

### 4. Benchmarking
Set realistic OTP targets based on service type

### 5. Root Cause Analysis
Deep-dive into why one outperforms the other

## Example Queries

```sql
-- Get the verdict
SELECT train_type, on_time_percentage, performance_verdict
FROM gold_ic_vs_hdm_comparison
ORDER BY on_time_percentage DESC;

-- Compare delay distributions
SELECT
    train_type,
    early_pct, on_time_pct,
    slightly_late_pct, late_pct, very_late_pct
FROM gold_ic_vs_hdm_comparison;

-- Statistical comparison
SELECT
    train_type,
    avg_delay_minutes,
    median_delay_minutes,
    p95_delay
FROM gold_ic_vs_hdm_comparison;
```

## Advanced Analysis Opportunities

This model provides foundation for:
- 📅 **Time-of-day** performance patterns (already collected in base data)
- 🗓️ **Day-of-week** trends (weekday vs weekend)
- 🚉 **Station-level** deep-dives
- 📈 **Trend analysis** (requires historical model snapshots)

## Model Architecture

### Approach
- Single comprehensive CTE-based query
- Multi-dimensional aggregations in parallel
- Winner determination via correlated subquery

## Extensibility

To add more train types to comparison:
```sql
-- Modify the WHERE clause in CTE:
WHERE trainType IN ('IC', 'HDM', 'S')  -- Add 'S' for example
```

## Model Lineage

```
bronze_train_departures
    ↓
silver_fact_timetable_events
    ↓
gold_ic_vs_hdm_comparison ← YOU ARE HERE
```

## Data Quality Tests

✅ **train_type**: Must be IC or HDM  
✅ **on_time_percentage**: Not null  
✅ **performance_verdict**: Not null  
✅ **Implicit**: Both train types must exist in data  

## Maintenance Notes

- **Auto-updates**: Rebuilds when upstream silver model changes
- **Historical Tracking**: Consider adding snapshot model for trend analysis
- **Alerting**: Set up monitoring if IC/HDM gap exceeds threshold

---

**Model Owner**: Data Analytics Team  
**Created**: 2024-12-10  
**Last Modified**: 2024-12-10  
**Materialization**: Table  

{% enddocs %}

{% docs gold_delay_categories %}

## 🏷️ Delay Category Classification

### Business Logic

Delay categories are calculated based on the `differenceInMinutes` field from the raw timetable data:

```sql
CASE
    WHEN differenceInMinutes IS NULL THEN 'unknown'
    WHEN differenceInMinutes < 0 THEN 'early'
    WHEN differenceInMinutes <= 5 THEN 'on_time'
    WHEN differenceInMinutes <= 15 THEN 'slightly_late'
    WHEN differenceInMinutes <= 30 THEN 'late'
    ELSE 'very_late'
END
```

### Category Definitions

| Category | Minutes | Symbol | Passenger Impact | Action Required |  
|----------|---------|--------|------------------|-----------------|  
| **Early** | < 0 | 🟢 | Minimal - may miss connections | Monitor connection patterns |  
| **On-Time** | 0-5 | ✅ | None - acceptable service | Maintain standards |  
| **Slightly Late** | 6-15 | 🟡 | Minor inconvenience | Track root causes |  
| **Late** | 16-30 | 🟠 | Significant disruption | Investigate delays |  
| **Very Late** | 30+ | 🔴 | Severe - compensation may apply | Immediate action |  

### Regulatory Context

- **EU Regulation 1371/2007**: Compensation rights for delays >60 minutes
- **VR Service Promise**: 5-minute tolerance aligns with customer expectations
- **Industry Benchmark**: European railways typically use 5.9 minutes threshold

### Usage in Models

These categories are calculated in **silver_fact_timetable_events** and aggregated in all gold models to provide consistent delay analysis across the platform.

{% enddocs %}

{% docs gold_page_aggregates %}

## Evidence page aggregates

The Evidence site (`bi/workspace`) used to load `silver_fact_timetable_events` as a source: one
row per arrival/departure (~64,000 rows per day). `npm run sources` then needed memory that grew
with history (about 6 GB at 30 days, out of memory at ~55 days), and the browser had to download
every event. These eight small tables replace it. Every page query is answered exactly from them,
and at 365 days of history each has at most a few tens of thousands of rows.

| Model | Grain | Filters used by pages |
|-------|-------|-----------------------|
| `gold_daily_performance` | actual day x trainType x trainCategory x day_of_week x scheduled_month | date range (Train Performance) |
| `gold_hourly_delay_categories` | scheduled_hour x trainType x trainCategory x delay_category (all time) | none |
| `gold_delay_histogram` | trainType x integer delay_minutes (all time) | none |
| `gold_train_spans` | departureDate x trainType x trainCategory x first/last actual day x midnight_days x has_* flags | period, date range |
| `gold_station_presence` | trainType x trainCategory x station x run of consecutive actual days | date range |
| `gold_ic_hdm_station_daily` | departureDate x trainType (IC/HDM) x station | period (IC vs HDM) |
| `gold_ic_hdm_hourly_daily` | departureDate x trainType (IC/HDM) x scheduled_hour x delay_category | period (IC vs HDM) |
| `gold_timetable_coverage` | departureDate x trainType x trainCategory, **all** events | none |

All models except `gold_timetable_coverage` cover commercial stops with an actual time
(`commercial_stop = true AND actual_time IS NOT NULL`), the filter every page query used.

### Additive measures

| Column | Definition |
|--------|------------|
| `events` | COUNT(*) |
| `on_time_events` | stops with `delay_minutes <= 5` (`is_on_time`) |
| `delay_sum` | SUM(delay_minutes) |
| `delay_sumsq` | SUM(delay_minutes^2) |
| `delay_count` | COUNT(delay_minutes) |

Roll-ups that reproduce the event-level SQL:

```sql
ROUND(100.0 * SUM(on_time_events) / SUM(events), 2)          -- AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END)
ROUND(SUM(delay_sum) / SUM(delay_count), 2)                   -- AVG(delay_minutes)
ROUND(SQRT((SUM(delay_count) * SUM(delay_sumsq) - SUM(delay_sum) * SUM(delay_sum))
      / NULLIF(SUM(delay_count) * (SUM(delay_count) - 1), 0)), 2)  -- STDDEV(delay_minutes)
```

`delay_minutes` is an integer, so `gold_delay_histogram` holds the full delay distribution of
each train type: PERCENTILE_CONT/MEDIAN, MIN and MAX are exact (median = mean of the values at
0-based positions floor((n-1)/2) and ceil((n-1)/2) of the cumulative counts). Its NULL
`delay_minutes` row keeps the stops without a delay, so every train type is present.

The two all-time tables have no date column and do not grow with the number of days:
`gold_hourly_delay_categories` is bounded by 24 hours x type/category pairs x 6 categories, and
`gold_delay_histogram` grows only with the spread of delay values per train type.

### Distinct counts

`COUNT(DISTINCT trainNumber || departureDate)` and `COUNT(DISTINCT stationShortCode)` cannot be
summed across rows, so they get their own models:

* `gold_train_spans.n_trains` can be summed over departureDate, trainType and trainCategory,
  because a train has exactly one of each. Per time of day or weekday/weekend, use
  `SUM(n_trains) FILTER (WHERE has_...)`: a train in both groups counts in both, as before.
* Date range `actual_time BETWEEN '<start>' AND '<end>'` (both `YYYY-MM-DD`), for a train
  (`gold_train_spans`) or a station run (`gold_station_presence`):
  * `<start>` < `<end>`: it had a stop in the range when
    `first_actual_bucket <= '<end>' AND last_actual_bucket >= '<start>'`. The range is then at
    least 24 h long, so it cannot fall inside the gap between two buckets of one train or one
    station run. For `gold_train_spans` this needs every train to stay within two UTC days, i.e.
    no more than 24 h between the actual days of its commercial stops (warn test on
    `gold_train_spans`). `gold_station_presence` needs no such condition, because its runs are
    built to break at every gap of more than 24 h.
  * `<start>` = `<end>`: the range is the single instant `<start> 00:00:00`, which only stops
    stamped exactly at midnight match. The overlap test would also match every train or station
    run whose buckets merely straddle that midnight without a stop at it, so both models carry
    `midnight_days`, the sorted comma-separated `YYYY-MM-DD` days with such a stop (`''` when
    none), and the filter is `contains(midnight_days, '<start>')`. This is exact.
  * `<start>` > `<end>`: empty, as `BETWEEN` is.

  The Train Performance page writes the three cases as one `CASE` in its `WHERE` clause.
  `midnight_days` is a non-null VARCHAR on purpose: Evidence ships a timestamp column that is NULL
  on every row as a DOUBLE, which could not be compared with a date string.
* The page SQL joins these distinct counts to the additive measures with
  `IS NOT DISTINCT FROM`, so a NULL trainType or trainCategory stays its own row, as it did with
  `GROUP BY` on the events.

### Actual-day buckets

`actual_bucket` / `first_actual_bucket` / `last_actual_bucket` are the UTC day of `actual_time`
stamped at 12:00. A stop recorded exactly at 00:00:00 keeps its own timestamp. With the
`YYYY-MM-DD` strings that Evidence's DateRange input produces,
`actual_bucket BETWEEN '<start>' AND '<end>'` selects exactly the same stops as
`actual_time BETWEEN '<start>' AND '<end>'`: stops on days start .. end-1, plus stops at exactly
00:00:00 on the end day.

### Page SQL conventions

* Count outputs (`events`, `stops`, `trains`, `total_stops`, `total_trains`) are
  `CAST(... AS BIGINT)`. They are sums over parquet columns that Evidence stores as DOUBLE, and the
  event-level `COUNT(*)` they replace returned BIGINT. The values are the same either way.
* Every `ORDER BY` on a rounded measure has a tiebreaker (hour, weekday, type and category,
  station), so tied rows, and the row a `LIMIT` picks among ties, come out the same on every build.
  The event-level queries did not fix the order of ties.

{% enddocs %}
