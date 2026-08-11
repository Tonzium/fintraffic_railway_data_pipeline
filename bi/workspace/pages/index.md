---
title: Finnish Railway Performance Dashboard 🚆
---

# Are Finnish trains on time?

```sql overall_metrics
SELECT
    total_trains,
    total_events,
    on_time_percentage as otp_percentage,
    avg_delay_minutes,
    total_stations as stations_served
FROM warehouse.on_time_performance
WHERE metric_scope = 'Overall'
```

```sql rush_stats
SELECT
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as morning_rush_otp
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
    AND time_of_day_category = 'morning_rush'
```

```sql category_extremes
SELECT
    metric_scope as category,
    on_time_percentage
FROM warehouse.on_time_performance
WHERE metric_scope IN ('Long-distance', 'Commuter', 'Cargo', 'Locomotive')
ORDER BY on_time_percentage DESC
```

```sql worst_hour
SELECT
    scheduled_hour,
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
GROUP BY scheduled_hour
ORDER BY otp_percentage ASC
LIMIT 1
```

**{overall_metrics[0]?.otp_percentage}% of trains are on time overall** — but the morning rush (6–9 AM) tells a different story, where on-time performance drops to **{rush_stats[0]?.morning_rush_otp}%**.

<Grid cols=3>
    <Alert status="success">
        🏆 <strong>Best category:</strong> {category_extremes[0]?.category} at {category_extremes[0]?.on_time_percentage}% OTP
    </Alert>
    <Alert status="warning">
        ⚠️ <strong>Toughest category:</strong> {category_extremes[category_extremes.length - 1]?.category} at {category_extremes[category_extremes.length - 1]?.on_time_percentage}% OTP
    </Alert>
    <Alert status="warning">
        🕐 <strong>Worst hour:</strong> {worst_hour[0]?.scheduled_hour}:00 at {worst_hour[0]?.otp_percentage}% OTP
    </Alert>
</Grid>

<BigValue
    data={overall_metrics}
    value=otp_percentage
    fmt='#,##0.0"%"'
    title="Overall On-Time Performance"
/>

<Grid cols=3>
    <BigValue
        data={overall_metrics}
        value=total_trains
        fmt='#,###'
        title="Total Trains Analyzed"
    />
    <BigValue
        data={overall_metrics}
        value=avg_delay_minutes
        fmt='#,##0.0" min"'
        title="Average Delay"
    />
    <BigValue
        data={overall_metrics}
        value=stations_served
        fmt='#,###'
        title="Stations Served"
    />
</Grid>

---

## Performance by Train Category

```sql train_category_performance
SELECT
    metric_scope as train_category,
    total_trains as trains,
    total_events as stops,
    on_time_percentage as otp_percentage,
    avg_delay_minutes as avg_delay
FROM warehouse.on_time_performance
WHERE metric_scope IN ('Long-distance', 'Commuter', 'Cargo', 'Locomotive')
ORDER BY on_time_percentage DESC
```

<BarChart
    data={train_category_performance}
    x=train_category
    y=otp_percentage
    title="On-Time Performance by Train Category"
    yFmt='#,##0.0"%"'
    colorPalette={['#22c55e', '#3b82f6', '#f59e0b', '#ef4444']}
/>

<DataTable data={train_category_performance}>
    <Column id=train_category title="Train Category"/>
    <Column id=trains title="Trains" fmt='#,###'/>
    <Column id=stops title="Total Stops" fmt='#,###'/>
    <Column id=otp_percentage title="OTP %" fmt='#,##0.00"%"'/>
    <Column id=avg_delay title="Avg Delay (min)" fmt='#,##0.00'/>
</DataTable>

---

[See detailed IC vs HDM comparison →](/ic_vs_hdm)

---

## Hourly Performance Pattern

```sql hourly_performance
SELECT
    scheduled_hour,
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    COUNT(*) as events
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
GROUP BY scheduled_hour
ORDER BY scheduled_hour
```

<LineChart
    data={hourly_performance}
    x=scheduled_hour
    y=otp_percentage
    title="On-Time Performance Throughout the Day"
    yAxisTitle="OTP %"
    xAxisTitle="Hour of Day (24h)"
    yFmt='#,##0.0"%"'
    lineColor='#3b82f6'
    chartAreaHeight=300
    labels=True
    yMin={80}
    yMax={100}
>
    <ReferenceArea xMin={6} xMax={9} label="Morning rush" color="warning"/>
    <ReferenceArea xMin={16} xMax={19} label="Evening rush" color="warning"/>
</LineChart>

---

```sql freshness
SELECT
    strftime(MAX(actual_time), '%Y-%m-%d %H:%M') as latest_timestamp
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
```

## Quick Links

- **[🗺️ Station Map](/stations)** - Delay and traffic volume across every station in Finland
- **[🎯 IC vs HDM Analysis](/ic_vs_hdm)** - Deep dive into InterCity vs Helsinki-Turku performance comparison
- **[📊 Train Performance](/train_performance)** - Detailed performance metrics by all train types
- **[⏰ Time Patterns](/time_analysis)** - Hourly, daily, and weekly performance patterns
- **[ℹ️ About this Project](/about)** - Architecture, stack rationale, and source code

---

*Data through **{freshness[0]?.latest_timestamp ?? 'unknown'}**, refreshed daily at 07:00 EET | Source: VR Digitraffic API*
