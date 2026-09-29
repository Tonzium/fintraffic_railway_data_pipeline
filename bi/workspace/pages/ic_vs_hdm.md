---
title: IC vs HDM Performance Analysis 🎯
sidebar_position: 2
---

# InterCity vs Helsinki-Turku: Head-to-Head Comparison

```sql data_period
SELECT
    MIN(CAST(departureDate AS DATE)) as first_day,
    MAX(CAST(departureDate AS DATE)) as last_day,
    COUNT(DISTINCT departureDate) as days_covered
FROM warehouse.timetable_coverage
```

_Data covers **{fmt(data_period[0]?.first_day, 'longdate')} – {fmt(data_period[0]?.last_day, 'longdate')}** ({data_period[0]?.days_covered} days). All numbers on this page follow the time period selected below._

<Dropdown name=period title="Time period" defaultValue=7>
    <DropdownOption value=1 valueLabel="Last 1 day"/>
    <DropdownOption value=3 valueLabel="Last 3 days"/>
    <DropdownOption value=7 valueLabel="Last 7 days"/>
    <DropdownOption value=30 valueLabel="Last 30 days"/>
    <DropdownOption value=100000 valueLabel="All time"/>
</Dropdown>

```sql metrics_filtered
WITH stops AS (
    SELECT
        trainType,
        SUM(events) as events,
        SUM(on_time_events) as on_time_events,
        SUM(delay_sum) as delay_sum,
        SUM(delay_count) as delay_count,
        COUNT(DISTINCT stationShortCode) as stations
    FROM warehouse.ic_hdm_station_daily
    WHERE CAST(departureDate AS DATE) > (SELECT MAX(CAST(departureDate AS DATE)) FROM warehouse.timetable_coverage) - CAST('${inputs.period.value}' AS INTEGER) * INTERVAL '1 day'
    GROUP BY trainType
),
trains AS (
    SELECT
        trainType,
        SUM(n_trains) as trains
    FROM warehouse.train_spans
    WHERE trainType IN ('IC', 'HDM')
        AND CAST(departureDate AS DATE) > (SELECT MAX(CAST(departureDate AS DATE)) FROM warehouse.timetable_coverage) - CAST('${inputs.period.value}' AS INTEGER) * INTERVAL '1 day'
    GROUP BY trainType
)
SELECT
    s.trainType as train_type,
    ROUND(100.0 * s.on_time_events / s.events, 2) as on_time_percentage,
    ROUND(s.delay_sum / s.delay_count, 2) as avg_delay_minutes,
    CAST(t.trains AS BIGINT) as total_trains,
    CAST(s.events AS BIGINT) as total_stops,
    s.stations as stations_served
FROM stops s
LEFT JOIN trains t ON t.trainType = s.trainType
```

```sql hdm_metrics
SELECT * FROM ${metrics_filtered}
WHERE train_type = 'HDM'
```

```sql ic_metrics
SELECT * FROM ${metrics_filtered}
WHERE train_type = 'IC'
```

```sql comparison_summary
SELECT * FROM ${metrics_filtered}
ORDER BY on_time_percentage DESC, train_type
```

## 🏆 Performance Winner

<Alert status="success">
    <strong>{comparison_summary[0]?.train_type}</strong> wins this period: <strong>{comparison_summary[0]?.on_time_percentage}%</strong> on-time vs <strong>{comparison_summary[1]?.train_type}</strong> at <strong>{comparison_summary[1]?.on_time_percentage}%</strong>.
    Note that IC faces more operational complexity ({(ic_metrics[0]?.total_trains && hdm_metrics[0]?.total_trains) ? Math.round(ic_metrics[0].total_trains / hdm_metrics[0].total_trains * 10) / 10 : '?'}x more trains, {(ic_metrics[0]?.stations_served && hdm_metrics[0]?.stations_served) ? Math.round(ic_metrics[0].stations_served / hdm_metrics[0].stations_served * 10) / 10 : '?'}x more stations), which helps explain the gap.
</Alert>

<DataTable data={comparison_summary}>
    <Column id=train_type title="Train Type"/>
    <Column id=on_time_percentage title="OTP %" fmt='#,##0.00"%"'/>
    <Column id=avg_delay_minutes title="Avg Delay (min)" fmt='#,##0.00'/>
    <Column id=total_trains title="Trains" fmt='#,###'/>
    <Column id=total_stops title="Stops" fmt='#,###'/>
    <Column id=stations_served title="Stations" fmt='#,###'/>
</DataTable>

---

## Key Metrics Comparison

### 🚄 HDM (Helsinki-Turku)

<BigValue
    data={hdm_metrics}
    value=on_time_percentage
    fmt='#,##0.00"%"'
    title="On-Time Performance"
/>

<Grid cols=4>
    <BigValue
        data={hdm_metrics}
        value=avg_delay_minutes
        fmt='#,##0.00" min"'
        title="Average Delay"
    />
    <BigValue
        data={hdm_metrics}
        value=total_trains
        fmt='#,###'
        title="Total Trains"
    />
    <BigValue
        data={hdm_metrics}
        value=total_stops
        fmt='#,###'
        title="Total Stops"
    />
    <BigValue
        data={hdm_metrics}
        value=stations_served
        fmt='#,###'
        title="Stations Served"
    />
</Grid>

### 🚂 IC (InterCity)

<BigValue
    data={ic_metrics}
    value=on_time_percentage
    fmt='#,##0.00"%"'
    title="On-Time Performance"
/>

<Grid cols=4>
    <BigValue
        data={ic_metrics}
        value=avg_delay_minutes
        fmt='#,##0.00" min"'
        title="Average Delay"
    />
    <BigValue
        data={ic_metrics}
        value=total_trains
        fmt='#,###'
        title="Total Trains"
    />
    <BigValue
        data={ic_metrics}
        value=total_stops
        fmt='#,###'
        title="Total Stops"
    />
    <BigValue
        data={ic_metrics}
        value=stations_served
        fmt='#,###'
        title="Stations Served"
    />
</Grid>

---

## Delay Category Breakdown

```sql delay_distribution
SELECT
    trainType as train_type,
    delay_category,
    CAST(SUM(events) AS BIGINT) as events,
    ROUND(100.0 * SUM(events) / SUM(SUM(events)) OVER (PARTITION BY trainType), 2) as percentage
FROM warehouse.ic_hdm_hourly_daily
WHERE CAST(departureDate AS DATE) > (SELECT MAX(CAST(departureDate AS DATE)) FROM warehouse.timetable_coverage) - CAST('${inputs.period.value}' AS INTEGER) * INTERVAL '1 day'
GROUP BY trainType, delay_category
ORDER BY trainType,
    CASE delay_category
        WHEN 'early' THEN 1
        WHEN 'on_time' THEN 2
        WHEN 'slightly_late' THEN 3
        WHEN 'late' THEN 4
        WHEN 'very_late' THEN 5
        ELSE 6
    END
```

<BarChart
    data={delay_distribution}
    x=delay_category
    y=percentage
    series=train_type
    title="Delay Distribution: IC vs HDM"
    yFmt='#,##0.0"%"'
    swapXY=false
    colorPalette={['#ef4444', '#22c55e']}
    type="grouped"
    labels=true
/>

<DataTable data={delay_distribution}>
    <Column id=train_type title="Train Type"/>
    <Column id=delay_category title="Delay Category"/>
    <Column id=events title="Events" fmt='#,###'/>
    <Column id=percentage title="Percentage" fmt='#,##0.00"%"'/>
</DataTable>

---

## Hourly Performance Comparison

```sql hourly_comparison
SELECT
    scheduled_hour,
    trainType as train_type,
    ROUND(100.0 * SUM(on_time_events) / SUM(events), 2) as otp_percentage,
    ROUND(SUM(delay_sum) / SUM(delay_count), 2) as avg_delay,
    CAST(SUM(events) AS BIGINT) as events
FROM warehouse.ic_hdm_hourly_daily
WHERE CAST(departureDate AS DATE) > (SELECT MAX(CAST(departureDate AS DATE)) FROM warehouse.timetable_coverage) - CAST('${inputs.period.value}' AS INTEGER) * INTERVAL '1 day'
GROUP BY scheduled_hour, trainType
ORDER BY scheduled_hour, trainType
```

<LineChart
    data={hourly_comparison}
    x=scheduled_hour
    y=otp_percentage
    series=train_type
    title="On-Time Performance by Hour of Day"
    yAxisTitle="OTP %"
    xAxisTitle="Hour (24h)"
    yFmt='#,##0.0"%"'
    colorPalette={['#ef4444', '#22c55e']}
    chartAreaHeight=350
    labels=True
    yMin={80}
    yMax={100}
/>

---

## Key Insights

### 🎯 Performance Gap

```sql performance_gap
SELECT
    ROUND(MAX(CASE WHEN train_type = 'HDM' THEN on_time_percentage END) -
          MAX(CASE WHEN train_type = 'IC' THEN on_time_percentage END), 2) as otp_gap,
    ROUND(MAX(CASE WHEN train_type = 'IC' THEN avg_delay_minutes END) -
          MAX(CASE WHEN train_type = 'HDM' THEN avg_delay_minutes END), 2) as delay_gap,
    ROUND(MAX(CASE WHEN train_type = 'IC' THEN avg_delay_minutes END) /
          MAX(CASE WHEN train_type = 'HDM' THEN avg_delay_minutes END), 2) as delay_multiplier
FROM ${metrics_filtered}
```

<Grid cols=3>
    <BigValue
        data={performance_gap}
        value=otp_gap
        fmt='#,##0.00" pp"'
        title="OTP Percentage Point Gap"
    />
    <BigValue
        data={performance_gap}
        value=delay_gap
        fmt='#,##0.00" min"'
        title="Average Delay Gap"
    />
    <BigValue
        data={performance_gap}
        value=delay_multiplier
        fmt='#,##0.0"x"'
        title="IC Delay Multiplier"
    />
</Grid>

### 📊 Why the Difference?

1. **Network Complexity**
   - HDM: Direct route, 27 stations
   - IC: Nationwide network, 71 stations
   - More stations = more delay accumulation points

2. **Volume Handling**
   - IC handles **{ic_metrics[0]?.total_trains ?? 0}** trains vs HDM's **{hdm_metrics[0]?.total_trains ?? 0}**
   - Higher volume increases operational complexity

3. **Route Characteristics**
   - HDM: Dedicated fast corridor (Helsinki-Turku)
   - IC: Mixed traffic, more scheduling constraints

4. **Delay Severity**
   - HDM: Only **{delay_distribution.find(d => d.train_type === 'HDM' && d.delay_category === 'very_late')?.percentage ?? 0}%** very late
   - IC: **{delay_distribution.find(d => d.train_type === 'IC' && d.delay_category === 'very_late')?.percentage ?? 0}%** very late (much higher)

---

## Top Performing Stations

### HDM Route Performance

```sql hdm_stations
SELECT
    s.stationName,
    s.stationShortCode,
    CAST(SUM(f.events) AS BIGINT) as stops,
    ROUND(100.0 * SUM(f.on_time_events) / SUM(f.events), 2) as otp_percentage,
    ROUND(SUM(f.delay_sum) / SUM(f.delay_count), 2) as avg_delay
FROM warehouse.ic_hdm_station_daily f
JOIN warehouse.dim_stations s
    ON f.stationShortCode = s.stationShortCode
WHERE f.trainType = 'HDM'
GROUP BY s.stationName, s.stationShortCode
HAVING SUM(f.events) >= 100
ORDER BY otp_percentage DESC, s.stationShortCode
LIMIT 10
```

<DataTable data={hdm_stations}>
    <Column id=stationName title="Station"/>
    <Column id=stationShortCode title="Code"/>
    <Column id=stops title="Stops" fmt='#,###'/>
    <Column id=otp_percentage title="OTP %" fmt='#,##0.0"%"' contentType=colorscale scaleColor=green/>
    <Column id=avg_delay title="Avg Delay" fmt='#,##0.00'/>
</DataTable>

### IC Route Performance

```sql ic_stations
SELECT
    s.stationName,
    s.stationShortCode,
    CAST(SUM(f.events) AS BIGINT) as stops,
    ROUND(100.0 * SUM(f.on_time_events) / SUM(f.events), 2) as otp_percentage,
    ROUND(SUM(f.delay_sum) / SUM(f.delay_count), 2) as avg_delay
FROM warehouse.ic_hdm_station_daily f
JOIN warehouse.dim_stations s
    ON f.stationShortCode = s.stationShortCode
WHERE f.trainType = 'IC'
GROUP BY s.stationName, s.stationShortCode
HAVING SUM(f.events) >= 100
ORDER BY otp_percentage DESC, s.stationShortCode
LIMIT 10
```

<DataTable data={ic_stations}>
    <Column id=stationName title="Station"/>
    <Column id=stationShortCode title="Code"/>
    <Column id=stops title="Stops" fmt='#,###'/>
    <Column id=otp_percentage title="OTP %" fmt='#,##0.0"%"' contentType=colorscale scaleColor=green/>
    <Column id=avg_delay title="Avg Delay" fmt='#,##0.00'/>
</DataTable>

---

[← Back to Dashboard](/) | [View All Train Types →](/train_performance)
