---
title: Time-Based Performance Analysis ⏰
---

# Performance Patterns Over Time

## Hourly Performance Pattern

```sql hourly_pattern
SELECT
    scheduled_hour,
    COUNT(*) as events,
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    ROUND(AVG(delay_minutes), 2) as avg_delay,
    ROUND(STDDEV(delay_minutes), 2) as delay_stddev
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
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
SELECT
    time_of_day_category,
    COUNT(*) as events,
    COUNT(DISTINCT trainNumber || departureDate) as trains,
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    ROUND(AVG(delay_minutes), 2) as avg_delay
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
GROUP BY time_of_day_category
ORDER BY
    CASE time_of_day_category
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
    COUNT(*) as events,
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    ROUND(AVG(delay_minutes), 2) as avg_delay
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
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
    COUNT(*) as events,
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    ROUND(AVG(delay_minutes), 2) as avg_delay
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
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
SELECT
    CASE WHEN is_weekend THEN 'Weekend' ELSE 'Weekday' END as period,
    COUNT(*) as events,
    COUNT(DISTINCT trainNumber || departureDate) as trains,
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    ROUND(AVG(delay_minutes), 2) as avg_delay
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
GROUP BY is_weekend
ORDER BY is_weekend
```

```sql weekend_pivot
SELECT
    ROUND(SUM(CASE WHEN is_weekend = false AND is_on_time THEN 1.0 ELSE 0.0 END) / COUNT(CASE WHEN is_weekend = false THEN 1 END) * 100, 2) as weekday_otp,
    ROUND(SUM(CASE WHEN is_weekend = true AND is_on_time THEN 1.0 ELSE 0.0 END) / COUNT(CASE WHEN is_weekend = true THEN 1 END) * 100, 2) as weekend_otp
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL AND commercial_stop = true
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
    COUNT(*) as events,
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    ROUND(AVG(delay_minutes), 2) as avg_delay
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
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
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
    AND trainType IN ('IC', 'HDM', 'S', 'P', 'HL', 'T', 'SAA', 'VET')
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
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    COUNT(*) as events
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
GROUP BY scheduled_hour
ORDER BY otp_percentage DESC
LIMIT 1
```

```sql worst_hour
SELECT
    scheduled_hour,
    ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage,
    COUNT(*) as events
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
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
        ROUND(AVG(CASE WHEN is_on_time THEN 100.0 ELSE 0 END), 2) as otp_percentage
    FROM warehouse.timetable_events
    WHERE actual_time IS NOT NULL
        AND commercial_stop = true
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
    COUNT(*) as events,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY scheduled_hour), 2) as percentage
FROM warehouse.timetable_events
WHERE actual_time IS NOT NULL
    AND commercial_stop = true
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
