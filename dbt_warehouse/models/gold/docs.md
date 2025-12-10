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
⚡ **Build Time**: ~0.3 seconds (optimized aggregations)  

## Model Lineage

```
bronze_train_departures
    ↓
silver_timetable_events
    ↓
gold_on_time_performance ← YOU ARE HERE
```

## Change Log

- **2024-12-10**: Initial model creation
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
silver_timetable_events
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

These categories are calculated in **silver_timetable_events** and aggregated in all gold models to provide consistent delay analysis across the platform.

{% enddocs %}
