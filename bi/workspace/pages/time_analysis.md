---
title: Time-Based Performance Analysis ⏰
sidebar_position: 4
---

# Performance Patterns Over Time

## Hourly Performance Pattern

```sql hourly_pattern
SELECT
    scheduled_hour,
    SUM(events) as events,
    ROUND(100.0 * SUM(on_time_events) / SUM(events), 2) as otp_percentage,
    ROUND(SUM(delay_sum) / SUM(delay_count), 2) as avg_delay,
    -- sample standard deviation from the exact sums (same as STDDEV(delay_minutes))
    ROUND(SQRT((SUM(delay_count) * SUM(delay_sumsq) - SUM(delay_sum) * SUM(delay_sum)) / NULLIF(SUM(delay_count) * (SUM(delay_count) - 1), 0)), 2) as delay_stddev
FROM warehouse.hourly_delay_categories
GROUP BY scheduled_hour
ORDER BY scheduled_hour
```

<LineChart
    data={hourly_pattern}
    x=scheduled_hour
    y=otp_percentage
    y2=avg_delay
    title="On-Time Performance and Delay Throughout the Day"
    yAxisTitle="OTP %"
    y2AxisTitle="Avg Delay (min)"
    xAxisTitle="Hour of Day (24h)"
    yFmt='#,##0.0"%"'
    y2Fmt='#,##0.00'
    chartAreaHeight=400
    labels=True
/>

### Hourly Breakdown

<DataTable data={hourly_pattern}>
    <Column id=scheduled_hour title="Hour" align=center/>
    <Column id=events title="Events" fmt='#,###'/>
    <Column id=otp_percentage title="OTP %" fmt='#,##0.00"%"' contentType=colorscale scaleColor=green/>
    <Column id=avg_delay title="Avg Delay" fmt='#,##0.00'/>
    <Column id=delay_stddev title="Std Dev" fmt='#,##0.00'/>
</DataTable>

---

## Peak Hour Analysis

```sql rush_hour_performance
WITH stops AS (
    SELECT
        time_of_day_category,
        SUM(events) as events,
        SUM(on_time_events) as on_time_events,
        SUM(delay_sum) as delay_sum,
        SUM(delay_count) as delay_count
    FROM warehouse.hourly_delay_categories
    GROUP BY time_of_day_category
),
-- a train with stops in several periods counts in each of them
trains AS (
    SELECT 'morning_rush' as time_of_day_category, SUM(n_trains) FILTER (WHERE has_morning_rush) as trains FROM warehouse.train_spans
    UNION ALL
    SELECT 'off_peak', SUM(n_trains) FILTER (WHERE has_off_peak) FROM warehouse.train_spans
    UNION ALL
    SELECT 'evening_rush', SUM(n_trains) FILTER (WHERE has_evening_rush) FROM warehouse.train_spans
)
SELECT
    s.time_of_day_category,
    s.events,
    t.trains,
    ROUND(100.0 * s.on_time_events / s.events, 2) as otp_percentage,
    ROUND(s.delay_sum / s.delay_count, 2) as avg_delay
FROM stops s
LEFT JOIN trains t ON t.time_of_day_category = s.time_of_day_category
ORDER BY
    CASE s.time_of_day_category
        WHEN 'morning_rush' THEN 1
        WHEN 'off_peak' THEN 2
        WHEN 'evening_rush' THEN 3
    END
```

<DataTable data={rush_hour_performance}>
    <Column id=time_of_day_category title="Time Period"/>
    <Column id=events title="Events" fmt='#,###'/>
    <Column id=trains title="Trains" fmt='#,###'/>
    <Column id=otp_percentage title="OTP %" fmt='#,##0.00"%"' contentType=colorscale scaleColor=green/>
    <Column id=avg_delay title="Avg Delay (min)" fmt='#,##0.00'/>
</DataTable>

<BarChart
    data={rush_hour_performance}
    x=time_of_day_category
    y=otp_percentage
    title="Performance by Time of Day"
    yFmt='#,##0.0"%"'
    colorPalette={['#f59e0b', '#3b82f6', '#f59e0b']}
    labels=true
/>

**Insight:** {
    (rush_hour_performance.find(d => d.time_of_day_category === 'morning_rush')?.otp_percentage ?? 0) >
    (rush_hour_performance.find(d => d.time_of_day_category === 'off_peak')?.otp_percentage ?? 0)
    ? 'Morning rush hour performs better than off-peak hours'
    : 'Off-peak hours show better performance than rush hours'
}

---

## Day of Week Analysis

```sql daily_performance
SELECT
    day_of_week,
    CASE day_of_week
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END as day_name,
    SUM(events) as events,
    ROUND(100.0 * SUM(on_time_events) / SUM(events), 2) as otp_percentage,
    ROUND(SUM(delay_sum) / SUM(delay_count), 2) as avg_delay
FROM warehouse.daily_performance
GROUP BY day_of_week
ORDER BY day_of_week
```

<LineChart
    data={daily_performance}
    x=day_name
    y=otp_percentage
    title="On-Time Performance by Day of Week"
    yFmt='#,##0.0"%"'
    colorPalette={['#3b82f6']}
    chartAreaHeight=350
    labels=True
/>

<LineChart
    data={daily_performance}
    x=day_name
    y=avg_delay
    title="Average Delay by Day of Week"
    yAxisTitle="Avg Delay (min)"
    yFmt='#,##0.00'
    lineColor='#ef4444'
    chartAreaHeight=300
    labels=True
/>

---

## Weekend vs Weekday Deep Dive

```sql weekend_analysis
SELECT
    is_weekend,
    trainCategory as category,
    SUM(events) as events,
    ROUND(100.0 * SUM(on_time_events) / SUM(events), 2) as otp_percentage,
    ROUND(SUM(delay_sum) / SUM(delay_count), 2) as avg_delay
FROM warehouse.daily_performance
GROUP BY is_weekend, trainCategory
ORDER BY is_weekend, otp_percentage DESC
```

<BarChart
    data={weekend_analysis}
    x=category
    y=otp_percentage
    series=is_weekend
    title="Weekday vs Weekend Performance by Category"
    yFmt='#,##0.0"%"'
    type="grouped"
    colorPalette={['#3b82f6', '#f59e0b']}
    seriesLabels={{
        true: 'Weekend',
        false: 'Weekday'
    }}
/>

```sql weekend_summary
WITH stops AS (
    SELECT
        is_weekend,
        SUM(events) as events,
        SUM(on_time_events) as on_time_events,
        SUM(delay_sum) as delay_sum,
        SUM(delay_count) as delay_count
    FROM warehouse.daily_performance
    GROUP BY is_weekend
),
-- a train with stops on both sides of the weekend boundary counts in both
trains AS (
    SELECT false as is_weekend, SUM(n_trains) FILTER (WHERE has_weekday) as trains FROM warehouse.train_spans
    UNION ALL
    SELECT true, SUM(n_trains) FILTER (WHERE has_weekend) FROM warehouse.train_spans
)
SELECT
    CASE WHEN s.is_weekend THEN 'Weekend' ELSE 'Weekday' END as period,
    s.events,
    t.trains,
    ROUND(100.0 * s.on_time_events / s.events, 2) as otp_percentage,
    ROUND(s.delay_sum / s.delay_count, 2) as avg_delay
FROM stops s
LEFT JOIN trains t ON t.is_weekend = s.is_weekend
ORDER BY s.is_weekend
```

```sql weekend_pivot
SELECT
    ROUND(SUM(CASE WHEN is_weekend = false THEN on_time_events ELSE 0 END) / SUM(CASE WHEN is_weekend = false THEN events ELSE 0 END) * 100, 2) as weekday_otp,
    ROUND(SUM(CASE WHEN is_weekend = true THEN on_time_events ELSE 0 END) / SUM(CASE WHEN is_weekend = true THEN events ELSE 0 END) * 100, 2) as weekend_otp
FROM warehouse.daily_performance
```

<Grid cols=2>
    <BigValue
        data={weekend_pivot}
        value=weekday_otp
        comparison=weekend_otp
        fmt='#,##0.0"%"'
        title="Weekday OTP %"
        comparisonTitle="vs Weekend"
    />
    <BigValue
        data={weekend_pivot}
        value=weekend_otp
        comparison=weekday_otp
        fmt='#,##0.0"%"'
        title="Weekend OTP %"
        comparisonTitle="vs Weekday"
    />
</Grid>

---

## Monthly Trends

```sql monthly_trends
SELECT
    scheduled_month,
    CASE scheduled_month
        WHEN 1 THEN 'January'
        WHEN 2 THEN 'February'
        WHEN 3 THEN 'March'
        WHEN 4 THEN 'April'
        WHEN 5 THEN 'May'
        WHEN 6 THEN 'June'
        WHEN 7 THEN 'July'
        WHEN 8 THEN 'August'
        WHEN 9 THEN 'September'
        WHEN 10 THEN 'October'
        WHEN 11 THEN 'November'
        WHEN 12 THEN 'December'
    END as month_name,
    SUM(events) as events,
    ROUND(100.0 * SUM(on_time_events) / SUM(events), 2) as otp_percentage,
    ROUND(SUM(delay_sum) / SUM(delay_count), 2) as avg_delay
FROM warehouse.daily_performance
GROUP BY scheduled_month
ORDER BY scheduled_month
```

<LineChart
    data={monthly_trends}
    x=month_name
    y=otp_percentage
    y2=events
    title="Monthly Performance Trends"
    yAxisTitle="OTP %"
    y2AxisTitle="Events"
    yFmt='#,##0.0"%"'
    y2Fmt='#,###'
    chartAreaHeight=350
/>

---

## Hourly LineChart by Train Type

```sql hourly_by_type
SELECT
    scheduled_hour,
    trainType as train_type,
    ROUND(100.0 * SUM(on_time_events) / SUM(events), 2) as otp_percentage
FROM warehouse.hourly_delay_categories
WHERE trainType IN ('IC', 'HDM', 'S', 'P', 'HL', 'T', 'SAA', 'VET')
GROUP BY scheduled_hour, trainType
ORDER BY scheduled_hour, trainType
```

<LineChart
    data={hourly_by_type}
    x=scheduled_hour
    y=otp_percentage
    series=train_type
    title="Hourly Performance by Train Type"
    yAxisTitle="OTP %"
    xAxisTitle="Hour of Day"
    yFmt='#,##0.0"%"'
    colorPalette={['#ef4444', '#22c55e', '#3b82f6', '#f59e0b']}
    chartAreaHeight=400
    yMin={70}
    yMax={100}
/>

---

## Key Insights

### 🕐 Best and Worst Hours

```sql best_worst_hours
SELECT
    scheduled_hour,
    ROUND(100.0 * SUM(on_time_events) / SUM(events), 2) as otp_percentage,
    SUM(events) as events
FROM warehouse.hourly_delay_categories
GROUP BY scheduled_hour
ORDER BY otp_percentage DESC
LIMIT 1
```

```sql worst_hour
SELECT
    scheduled_hour,
    ROUND(100.0 * SUM(on_time_events) / SUM(events), 2) as otp_percentage,
    SUM(events) as events
FROM warehouse.hourly_delay_categories
GROUP BY scheduled_hour
ORDER BY otp_percentage ASC
LIMIT 1
```

<Grid cols=2>
    <Alert status="success">
        <strong>✅ Best Hour:</strong> {best_worst_hours[0]?.scheduled_hour ?? '--'}:00 with {best_worst_hours[0]?.otp_percentage ?? 0}% OTP
    </Alert>
    <Alert status="warning">
        <strong>⚠️ Worst Hour:</strong> {worst_hour[0]?.scheduled_hour ?? '--'}:00 with {worst_hour[0]?.otp_percentage ?? 0}% OTP
    </Alert>
</Grid>

### 📅 Best and Worst Days

```sql best_worst_days
WITH daily_stats AS (
    SELECT
        day_of_week,
        CASE day_of_week
            WHEN 0 THEN 'Sunday'
            WHEN 1 THEN 'Monday'
            WHEN 2 THEN 'Tuesday'
            WHEN 3 THEN 'Wednesday'
            WHEN 4 THEN 'Thursday'
            WHEN 5 THEN 'Friday'
            WHEN 6 THEN 'Saturday'
        END as day_name,
        ROUND(100.0 * SUM(on_time_events) / SUM(events), 2) as otp_percentage
    FROM warehouse.daily_performance
    GROUP BY day_of_week
)
SELECT
    day_name,
    otp_percentage,
    CASE
        WHEN otp_percentage = (SELECT MAX(otp_percentage) FROM daily_stats) THEN 'best'
        WHEN otp_percentage = (SELECT MIN(otp_percentage) FROM daily_stats) THEN 'worst'
    END as performance
FROM daily_stats
WHERE day_name IS NOT NULL
ORDER BY otp_percentage DESC
```

<Grid cols=2>
    <Alert status="success">
        <strong>✅ Best Day:</strong> {best_worst_days.find(d => d.performance === 'best')?.day_name ?? 'N/A'} with {best_worst_days.find(d => d.performance === 'best')?.otp_percentage ?? 0}% OTP
    </Alert>
    <Alert status="warning">
        <strong>⚠️ Worst Day:</strong> {best_worst_days.find(d => d.performance === 'worst')?.day_name ?? 'N/A'} with {best_worst_days.find(d => d.performance === 'worst')?.otp_percentage ?? 0}% OTP
    </Alert>
</Grid>

---

## Delay Accumulation During the Day

```sql delay_accumulation
SELECT
    scheduled_hour,
    delay_category,
    SUM(events) as events,
    ROUND(100.0 * SUM(events) / SUM(SUM(events)) OVER (PARTITION BY scheduled_hour), 2) as percentage
FROM warehouse.hourly_delay_categories
GROUP BY scheduled_hour, delay_category
ORDER BY scheduled_hour,
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
    data={delay_accumulation}
    x=scheduled_hour
    y=percentage
    series=delay_category
    title="Delay Category Distribution Throughout the Day"
    yFmt='#,##0.0'
    type="stacked100"
    colorPalette={['#f63b3bff', '#c59422ff', '#0014f3e1', '#44ef5bbe', '#38dc26ff']}
    chartAreaHeight=400
    labels=true
/>

**Pattern:** Delays tend to {
    delay_accumulation.filter(d => d.scheduled_hour >= 16 && d.delay_category === 'late').reduce((sum, d) => sum + d.percentage, 0) >
    delay_accumulation.filter(d => d.scheduled_hour < 12 && d.delay_category === 'late').reduce((sum, d) => sum + d.percentage, 0)
    ? 'accumulate during the day, with worse performance in afternoon/evening'
    : 'remain relatively stable throughout the day'
}

---

[← Back to Dashboard](/) | [IC vs HDM Analysis →](/ic_vs_hdm) | [Train Performance →](/train_performance)
