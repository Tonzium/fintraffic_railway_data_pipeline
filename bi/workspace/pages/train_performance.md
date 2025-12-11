---
title: Train Type Performance Analysis 📊
---

# Performance Analysis by Train Type

## Overall Rankings

```sql train_rankings
SELECT
    trainType as train_type,
    trainCategory as category,
    COUNT(DISTINCT trainNumber || departureDate) as trains,
    COUNT(*) as total_stops,
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    ROUND(AVG(delay_minutes), 2) as avg_delay,
    ROUND(STDDEV(delay_minutes), 2) as delay_stddev,
    COUNT(DISTINCT stationShortCode) as stations_served
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
GROUP BY trainType, trainCategory
HAVING COUNT(DISTINCT trainNumber || departureDate) >= 50
ORDER BY otp_percentage DESC
```

<BarChart
    data={train_rankings}
    x=train_type
    y=otp_percentage
    title="On-Time Performance by Train Type"
    yFmt='#,##0.0"%"'
    swapXY=true
    colorPalette={['#22c55e', '#3b82f6', '#f59e0b', '#ef4444', '#8b5cf6']}
    chartAreaHeight=400
/>

---

## Performance Scoreboard

<DataTable data={train_rankings} rows=20>
    <Column id=train_type title="Train Type" />
    <Column id=category title="Category"/>
    <Column id=trains title="Trains" fmt='#,###'/>
    <Column id=total_stops title="Stops" fmt='#,###'/>
    <Column id=otp_percentage title="OTP %" fmt='#,##0.00"%"' contentType=colorscale scaleColor=green/>
    <Column id=avg_delay title="Avg Delay (min)" fmt='#,##0.00' contentType=colorscale scaleColor=red/>
    <Column id=delay_stddev title="Std Dev" fmt='#,##0.00'/>
    <Column id=stations_served title="Stations" fmt='#,###'/>
</DataTable>

---

## Performance by Category

```sql category_performance
SELECT
    trainCategory as category,
    COUNT(DISTINCT trainType) as train_types,
    COUNT(DISTINCT trainNumber || departureDate) as trains,
    COUNT(*) as stops,
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    ROUND(AVG(delay_minutes), 2) as avg_delay
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
GROUP BY trainCategory
ORDER BY otp_percentage DESC
```

<DataTable data={category_performance}>
    <Column id=category title="Category"/>
    <Column id=train_types title="Train Types" fmt='#,###'/>
    <Column id=trains title="Trains" fmt='#,###'/>
    <Column id=stops title="Stops" fmt='#,###'/>
    <Column id=otp_percentage title="OTP %" fmt='#,##0.00"%"' contentType=colorscale scaleColor=green/>
    <Column id=avg_delay title="Avg Delay (min)" fmt='#,##0.00' contentType=colorscale scaleColor=red/>
</DataTable>

---

## Delay Distribution by Train Type

```sql delay_by_type
SELECT
    trainType as train_type,
    delay_category,
    COUNT(*) as events,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY trainType), 2) as percentage
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
    AND trainType IN (
        SELECT DISTINCT trainType
        FROM warehouse.timetable_events
        GROUP BY trainType
        HAVING COUNT(*) >= 1000
    )
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
    data={delay_by_type}
    x=train_type
    y=percentage
    series=delay_category
    title="Delay Category Distribution by Train Type"
    yFmt='#,##0.0"%"'
    type="stacked100"
    colorPalette={['#3b82f6', '#22c55e', '#f59e0b', '#ef4444', '#dc2626']}
    chartAreaHeight=400
/>

---

## Best Performers: Top 5

```sql top_performers
SELECT
    trainType as train_type,
    trainCategory as category,
    COUNT(DISTINCT trainNumber || departureDate) as trains,
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    ROUND(AVG(delay_minutes), 2) as avg_delay
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
GROUP BY trainType, trainCategory
HAVING COUNT(DISTINCT trainNumber || departureDate) >= 50
ORDER BY otp_percentage DESC
LIMIT 5
```

<Alert status="success">
    🏆 <strong>Top Performer:</strong> {top_performers[0]?.train_type ?? 'N/A'} trains with {top_performers[0]?.otp_percentage ?? 0}% on-time performance
</Alert>

<DataTable data={top_performers}>
    <Column id=train_type title="Train Type"/>
    <Column id=category title="Category"/>
    <Column id=trains title="Trains" fmt='#,###'/>
    <Column id=otp_percentage title="OTP %" fmt='#,##0.00"%"' contentType=colorscale scaleColor=green/>
    <Column id=avg_delay title="Avg Delay" fmt='#,##0.00'/>
</DataTable>

---

## Consistency Analysis

```sql consistency
SELECT
    trainType as train_type,
    COUNT(DISTINCT trainNumber || departureDate) as trains,
    ROUND(AVG(delay_minutes), 2) as avg_delay,
    ROUND(STDDEV(delay_minutes), 2) as delay_stddev,
    ROUND(MIN(delay_minutes), 2) as min_delay,
    ROUND(MAX(delay_minutes), 2) as max_delay,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delay_minutes), 2) as median_delay
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
GROUP BY trainType
HAVING COUNT(DISTINCT trainNumber || departureDate) >= 50
ORDER BY delay_stddev ASC
```

<ScatterPlot
    data={consistency}
    x=avg_delay
    y=delay_stddev
    series=train_type
    title="Delay Consistency: Average vs Standard Deviation"
    xAxisTitle="Average Delay (min)"
    yAxisTitle="Standard Deviation"
    size=trains
    chartAreaHeight=400
/>

<DataTable data={consistency}>
    <Column id=train_type title="Train Type"/>
    <Column id=trains title="Trains" fmt='#,###'/>
    <Column id=avg_delay title="Avg" fmt='#,##0.00'/>
    <Column id=median_delay title="Median" fmt='#,##0.00'/>
    <Column id=delay_stddev title="Std Dev" fmt='#,##0.00' contentType=colorscale scaleColor=red/>
    <Column id=min_delay title="Min" fmt='#,##0.00'/>
    <Column id=max_delay title="Max" fmt='#,##0.00'/>
</DataTable>

---

## Commuter vs Long-Distance

```sql category_comparison
SELECT
    CASE
        WHEN trainCategory = 'Commuter' THEN 'Commuter'
        WHEN trainCategory = 'Long-distance' THEN 'Long-distance'
        ELSE 'Other'
    END as category_group,
    COUNT(DISTINCT trainNumber || departureDate) as trains,
    COUNT(*) as stops,
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    ROUND(AVG(delay_minutes), 2) as avg_delay
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
    AND trainCategory IN ('Commuter', 'Long-distance')
GROUP BY category_group
ORDER BY otp_percentage DESC
```

<Grid cols=2>
    <BigValue
        data={category_comparison.filter(d => d.category_group === 'Commuter')}
        value=otp_percentage
        fmt='#,##0.0"%"'
        title="Commuter OTP %"
        comparison={category_comparison.find(d => d.category_group === 'Long-distance')?.otp_percentage}
        comparisonTitle="vs Long-distance"
    />
    <BigValue
        data={category_comparison.filter(d => d.category_group === 'Long-distance')}
        value=otp_percentage
        fmt='#,##0.0"%"'
        title="Long-distance OTP %"
        comparison={category_comparison.find(d => d.category_group === 'Commuter')?.otp_percentage}
        comparisonTitle="vs Commuter"
    />
</Grid>

**Insight:** Commuter trains typically have shorter routes and higher frequency, contributing to better on-time performance. Long-distance trains face more complex operational challenges.

---

## Weekend vs Weekday Performance

```sql weekend_comparison
SELECT
    trainType as train_type,
    is_weekend,
    COUNT(*) as stops,
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    ROUND(AVG(delay_minutes), 2) as avg_delay
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
    AND trainType IN ('IC', 'HDM', 'S', 'P')
GROUP BY trainType, is_weekend
ORDER BY trainType, is_weekend
```

<BarChart
    data={weekend_comparison}
    x=train_type
    y=otp_percentage
    series=is_weekend
    title="Weekday vs Weekend Performance"
    yFmt='#,##0.0"%"'
    type="grouped"
    colorPalette={['#3b82f6', '#f59e0b']}
    seriesLabels={{
        true: 'Weekend',
        false: 'Weekday'
    }}
/>

---

[← Back to Dashboard](/) | [IC vs HDM Analysis →](/ic_vs_hdm) | [Time Patterns →](/time_analysis)
