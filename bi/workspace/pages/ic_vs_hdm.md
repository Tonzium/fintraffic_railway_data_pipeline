---
title: IC vs HDM Performance Analysis 🎯
---

# InterCity vs Helsinki-Turku: Head-to-Head Comparison

```sql data_period
SELECT
    MIN(CAST(departureDate AS DATE)) as first_day,
    MAX(CAST(departureDate AS DATE)) as last_day,
    COUNT(DISTINCT departureDate) as days_covered
FROM warehouse.timetable_events
```

_Data covers **{fmt(data_period[0]?.first_day, 'longdate')} – {fmt(data_period[0]?.last_day, 'longdate')}** ({data_period[0]?.days_covered} days). The summary table below is all-time; use the time period selector in Key Metrics Comparison to narrow the range._

```sql comparison_summary
SELECT
    train_type,
    on_time_percentage,
    avg_delay_minutes,
    total_trains,
    total_stops,
    stations_served,
    performance_verdict
FROM warehouse.train_compare
ORDER BY on_time_percentage DESC
```

## 🏆 Performance Winner

<Alert status="success">
    <strong>{comparison_summary.find(d => d.performance_verdict === 'Winner: Better OTP')?.train_type ?? 'N/A'}</strong> trains significantly outperform with <strong>{comparison_summary.find(d => d.performance_verdict === 'Winner: Better OTP')?.on_time_percentage ?? 0}%</strong> on-time performance.  
    <strong>HDM trains are the clear winner</strong> across all metrics. However, IC trains face significantly more operational complexity (7x more trains, 2.6x more stations) which explains the performance gap.
</Alert>

---

## Key Metrics Comparison

<Dropdown name=period title="Time period" defaultValue=7>
    <DropdownOption value=1 valueLabel="Last 1 day"/>
    <DropdownOption value=3 valueLabel="Last 3 days"/>
    <DropdownOption value=7 valueLabel="Last 7 days"/>
    <DropdownOption value=30 valueLabel="Last 30 days"/>
    <DropdownOption value=100000 valueLabel="All time"/>
</Dropdown>

```sql metrics_filtered
SELECT
    trainType as train_type,
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as on_time_percentage,
    ROUND(AVG(delay_minutes), 2) as avg_delay_minutes,
    COUNT(DISTINCT trainNumber || '_' || departureDate) as total_trains,
    COUNT(*) as total_stops,
    COUNT(DISTINCT stationShortCode) as stations_served
FROM warehouse.timetable_events
WHERE trainType IN ('IC', 'HDM')
    AND actual_time IS NOT NULL
    AND commercial_stop = true
    AND CAST(departureDate AS DATE) > (SELECT MAX(CAST(departureDate AS DATE)) FROM warehouse.timetable_events) - CAST('${inputs.period.value}' AS INTEGER) * INTERVAL '1 day'
GROUP BY trainType
```

```sql hdm_metrics
SELECT * FROM ${metrics_filtered}
WHERE train_type = 'HDM'
```

```sql ic_metrics
SELECT * FROM ${metrics_filtered}
WHERE train_type = 'IC'
```

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
    COUNT(*) as events,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY trainType), 2) as percentage
FROM warehouse.timetable_events
WHERE trainType IN ('IC', 'HDM')
    AND actual_time IS NOT NULL
    AND commercial_stop = true
    AND CAST(departureDate AS DATE) > (SELECT MAX(CAST(departureDate AS DATE)) FROM warehouse.timetable_events) - CAST('${inputs.period.value}' AS INTEGER) * INTERVAL '1 day'
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
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    ROUND(AVG(delay_minutes), 2) as avg_delay,
    COUNT(*) as events
FROM warehouse.timetable_events
WHERE trainType IN ('IC', 'HDM')
    AND actual_time IS NOT NULL
    AND commercial_stop = true
    AND CAST(departureDate AS DATE) > (SELECT MAX(CAST(departureDate AS DATE)) FROM warehouse.timetable_events) - CAST('${inputs.period.value}' AS INTEGER) * INTERVAL '1 day'
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
FROM warehouse.train_compare
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
    COUNT(*) as stops,
    ROUND(AVG(CASE WHEN f.is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    ROUND(AVG(f.delay_minutes), 2) as avg_delay
FROM warehouse.timetable_events f
JOIN warehouse.dim_stations s
    ON f.stationShortCode = s.stationShortCode
WHERE f.trainType = 'HDM'
    AND f.actual_time IS NOT NULL
    AND f.commercial_stop = true
GROUP BY s.stationName, s.stationShortCode
HAVING COUNT(*) >= 100
ORDER BY otp_percentage DESC
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
    COUNT(*) as stops,
    ROUND(AVG(CASE WHEN f.is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    ROUND(AVG(f.delay_minutes), 2) as avg_delay
FROM warehouse.timetable_events f
JOIN warehouse.dim_stations s
    ON f.stationShortCode = s.stationShortCode
WHERE f.trainType = 'IC'
    AND f.actual_time IS NOT NULL
    AND f.commercial_stop = true
GROUP BY s.stationName, s.stationShortCode
HAVING COUNT(*) >= 100
ORDER BY otp_percentage DESC
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
