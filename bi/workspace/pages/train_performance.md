---
title: Train Type Performance Analysis 📊
sidebar_position: 1
---

# Performance Analysis by Train Type

## Overall Rankings

```sql category_options
SELECT DISTINCT trainCategory as category
FROM warehouse.timetable_coverage
WHERE trainCategory IS NOT NULL
ORDER BY category
```

```sql event_dates
SELECT MIN(min_actual_time) as actual_time FROM warehouse.timetable_coverage
UNION ALL
SELECT MAX(max_actual_time) as actual_time FROM warehouse.timetable_coverage
```

<Dropdown name=category_filter data={category_options} value=category title="Train Category">
    <DropdownOption value="%" valueLabel="All Categories"/>
</Dropdown>

<DateRange name=date_filter data={event_dates} dates=actual_time title="Date Range"/>

```sql train_rankings
WITH stops AS (
    SELECT
        trainType,
        trainCategory,
        SUM(events) as events,
        SUM(on_time_events) as on_time_events,
        SUM(delay_sum) as delay_sum,
        SUM(delay_sumsq) as delay_sumsq,
        SUM(delay_count) as delay_count
    FROM warehouse.daily_performance
    WHERE trainCategory LIKE '${inputs.category_filter.value}'
        AND actual_bucket BETWEEN '${inputs.date_filter.start}' AND '${inputs.date_filter.end}'
    GROUP BY trainType, trainCategory
),
-- Trains and stations with at least one stop in the range: their actual-day span overlaps it.
-- A range whose start equals its end is the single instant <start> 00:00:00 and only matches
-- stops stamped exactly at midnight, which midnight_days lists.
trains AS (
    SELECT
        trainType,
        trainCategory,
        SUM(n_trains) as trains
    FROM warehouse.train_spans
    WHERE trainCategory LIKE '${inputs.category_filter.value}'
        AND CASE
            WHEN '${inputs.date_filter.start}' < '${inputs.date_filter.end}'
                THEN first_actual_bucket <= '${inputs.date_filter.end}' AND last_actual_bucket >= '${inputs.date_filter.start}'
            WHEN '${inputs.date_filter.start}' = '${inputs.date_filter.end}'
                THEN contains(midnight_days, '${inputs.date_filter.start}')
            ELSE false
        END
    GROUP BY trainType, trainCategory
),
stations AS (
    SELECT
        trainType,
        trainCategory,
        COUNT(DISTINCT stationShortCode) as stations_served
    FROM warehouse.station_presence
    WHERE trainCategory LIKE '${inputs.category_filter.value}'
        AND CASE
            WHEN '${inputs.date_filter.start}' < '${inputs.date_filter.end}'
                THEN first_actual_bucket <= '${inputs.date_filter.end}' AND last_actual_bucket >= '${inputs.date_filter.start}'
            WHEN '${inputs.date_filter.start}' = '${inputs.date_filter.end}'
                THEN contains(midnight_days, '${inputs.date_filter.start}')
            ELSE false
        END
    GROUP BY trainType, trainCategory
)
SELECT
    s.trainType as train_type,
    s.trainCategory as category,
    CAST(t.trains AS BIGINT) as trains,
    CAST(s.events AS BIGINT) as total_stops,
    ROUND(100.0 * s.on_time_events / s.events, 2) as otp_percentage,
    ROUND(s.delay_sum / s.delay_count, 2) as avg_delay,
    ROUND(SQRT((s.delay_count * s.delay_sumsq - s.delay_sum * s.delay_sum) / NULLIF(s.delay_count * (s.delay_count - 1), 0)), 2) as delay_stddev,
    st.stations_served
FROM stops s
-- IS NOT DISTINCT FROM keeps a NULL type or category as its own row, as GROUP BY does
JOIN trains t ON t.trainType IS NOT DISTINCT FROM s.trainType AND t.trainCategory IS NOT DISTINCT FROM s.trainCategory
LEFT JOIN stations st ON st.trainType IS NOT DISTINCT FROM s.trainType AND st.trainCategory IS NOT DISTINCT FROM s.trainCategory
WHERE t.trains >= 50
ORDER BY otp_percentage DESC, train_type, category
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
    labels=true
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
WITH stops AS (
    SELECT
        trainCategory,
        COUNT(DISTINCT trainType) as train_types,
        SUM(events) as events,
        SUM(on_time_events) as on_time_events,
        SUM(delay_sum) as delay_sum,
        SUM(delay_count) as delay_count
    FROM warehouse.daily_performance
    GROUP BY trainCategory
),
trains AS (
    SELECT
        trainCategory,
        SUM(n_trains) as trains
    FROM warehouse.train_spans
    GROUP BY trainCategory
)
SELECT
    s.trainCategory as category,
    s.train_types,
    CAST(t.trains AS BIGINT) as trains,
    CAST(s.events AS BIGINT) as stops,
    ROUND(100.0 * s.on_time_events / s.events, 2) as otp_percentage,
    ROUND(s.delay_sum / s.delay_count, 2) as avg_delay
FROM stops s
LEFT JOIN trains t ON t.trainCategory IS NOT DISTINCT FROM s.trainCategory
ORDER BY otp_percentage DESC, category
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
    CAST(SUM(events) AS BIGINT) as events,
    ROUND(100.0 * SUM(events) / SUM(SUM(events)) OVER (PARTITION BY trainType), 2) as percentage
FROM warehouse.hourly_delay_categories
WHERE trainType IN (
        -- at least 1000 timetable rows of any kind, as before
        SELECT trainType
        FROM warehouse.timetable_coverage
        GROUP BY trainType
        HAVING SUM(events) >= 1000
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
    labels=true
/>

---

## Best Performers: Top 5

```sql top_performers
WITH stops AS (
    SELECT
        trainType,
        trainCategory,
        SUM(events) as events,
        SUM(on_time_events) as on_time_events,
        SUM(delay_sum) as delay_sum,
        SUM(delay_count) as delay_count
    FROM warehouse.daily_performance
    GROUP BY trainType, trainCategory
),
trains AS (
    SELECT
        trainType,
        trainCategory,
        SUM(n_trains) as trains
    FROM warehouse.train_spans
    GROUP BY trainType, trainCategory
)
SELECT
    s.trainType as train_type,
    s.trainCategory as category,
    CAST(t.trains AS BIGINT) as trains,
    ROUND(100.0 * s.on_time_events / s.events, 2) as otp_percentage,
    ROUND(s.delay_sum / s.delay_count, 2) as avg_delay
FROM stops s
JOIN trains t ON t.trainType IS NOT DISTINCT FROM s.trainType AND t.trainCategory IS NOT DISTINCT FROM s.trainCategory
WHERE t.trains >= 50
ORDER BY otp_percentage DESC, train_type, category
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
WITH stats AS (
    SELECT
        trainType,
        SUM(delay_count) as delay_count,
        SUM(delay_sum) as delay_sum,
        SUM(delay_sumsq) as delay_sumsq,
        MIN(delay_minutes) as min_delay,
        MAX(delay_minutes) as max_delay
    FROM warehouse.delay_histogram
    GROUP BY trainType
),
cumulative AS (
    SELECT
        trainType,
        delay_minutes,
        SUM(SUM(delay_count)) OVER (PARTITION BY trainType ORDER BY delay_minutes) as cum_count
    FROM warehouse.delay_histogram
    WHERE delay_minutes IS NOT NULL
    GROUP BY trainType, delay_minutes
),
-- PERCENTILE_CONT(0.5): mean of the values at 0-based positions floor((n-1)/2) and ceil((n-1)/2)
median AS (
    SELECT
        c.trainType,
        (MIN(c.delay_minutes) FILTER (WHERE c.cum_count > FLOOR((s.delay_count - 1) / 2))
            + MIN(c.delay_minutes) FILTER (WHERE c.cum_count > CEIL((s.delay_count - 1) / 2))) / 2 as median_delay
    FROM cumulative c
    JOIN stats s ON s.trainType IS NOT DISTINCT FROM c.trainType
    GROUP BY c.trainType
),
trains AS (
    SELECT
        trainType,
        SUM(n_trains) as trains
    FROM warehouse.train_spans
    GROUP BY trainType
)
SELECT
    s.trainType as train_type,
    CAST(t.trains AS BIGINT) as trains,
    ROUND(s.delay_sum / s.delay_count, 2) as avg_delay,
    ROUND(SQRT((s.delay_count * s.delay_sumsq - s.delay_sum * s.delay_sum) / NULLIF(s.delay_count * (s.delay_count - 1), 0)), 2) as delay_stddev,
    ROUND(s.min_delay, 2) as min_delay,
    ROUND(s.max_delay, 2) as max_delay,
    ROUND(m.median_delay, 2) as median_delay
FROM stats s
JOIN trains t ON t.trainType IS NOT DISTINCT FROM s.trainType
LEFT JOIN median m ON m.trainType IS NOT DISTINCT FROM s.trainType
WHERE t.trains >= 50
ORDER BY delay_stddev ASC, train_type
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
WITH stops AS (
    SELECT
        CASE
            WHEN trainCategory = 'Commuter' THEN 'Commuter'
            WHEN trainCategory = 'Long-distance' THEN 'Long-distance'
            ELSE 'Other'
        END as category_group,
        SUM(events) as events,
        SUM(on_time_events) as on_time_events,
        SUM(delay_sum) as delay_sum,
        SUM(delay_count) as delay_count
    FROM warehouse.daily_performance
    WHERE trainCategory IN ('Commuter', 'Long-distance')
    GROUP BY category_group
),
trains AS (
    SELECT
        trainCategory as category_group,
        SUM(n_trains) as trains
    FROM warehouse.train_spans
    WHERE trainCategory IN ('Commuter', 'Long-distance')
    GROUP BY trainCategory
)
SELECT
    s.category_group,
    CAST(t.trains AS BIGINT) as trains,
    CAST(s.events AS BIGINT) as stops,
    ROUND(100.0 * s.on_time_events / s.events, 2) as otp_percentage,
    ROUND(s.delay_sum / s.delay_count, 2) as avg_delay
FROM stops s
LEFT JOIN trains t ON t.category_group = s.category_group
ORDER BY otp_percentage DESC, s.category_group
```

```sql category_pivot
SELECT
    MAX(CASE WHEN category_group = 'Commuter' THEN otp_percentage END) as commuter_otp,
    MAX(CASE WHEN category_group = 'Long-distance' THEN otp_percentage END) as long_distance_otp
FROM ${category_comparison}
```

<Grid cols=2>
    <BigValue
        data={category_pivot}
        value=commuter_otp
        fmt='#,##0.0"%"'
        title="Commuter OTP %"
        comparison=long_distance_otp
        comparisonTitle="vs Long-distance"
    />
    <BigValue
        data={category_pivot}
        value=long_distance_otp
        fmt='#,##0.0"%"'
        title="Long-distance OTP %"
        comparison=commuter_otp
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
    CAST(SUM(events) AS BIGINT) as stops,
    ROUND(100.0 * SUM(on_time_events) / SUM(events), 2) as otp_percentage,
    ROUND(SUM(delay_sum) / SUM(delay_count), 2) as avg_delay
FROM warehouse.daily_performance
WHERE trainType IN ('IC', 'HDM', 'S', 'P')
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
