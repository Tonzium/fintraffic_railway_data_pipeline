---
title: Station Map 🗺️
sidebar_position: 3
---

# Station Performance Across Finland

```sql station_performance
SELECT
    station_code,
    station_name,
    latitude,
    longitude,
    region,
    total_events,
    total_trains,
    on_time_percentage,
    avg_delay_minutes
FROM warehouse.station_performance
ORDER BY total_events DESC
```

<BubbleMap
    data={station_performance}
    lat=latitude
    long=longitude
    size=total_events
    value=avg_delay_minutes
    valueFmt='#,##0.0" min"'
    pointName=station_name
    title="Station Performance Across Finland"
    subtitle="Bubble size = traffic volume, color = average delay"
    startingLat={64.5}
    startingLong={26.5}
    startingZoom={5}
    height={600}
/>

---

## Most Delayed Stations

```sql worst_stations
SELECT
    station_name,
    station_code,
    region,
    total_events,
    total_trains,
    on_time_percentage,
    avg_delay_minutes
FROM warehouse.station_performance
ORDER BY avg_delay_minutes DESC
LIMIT 10
```

<DataTable data={worst_stations}>
    <Column id=station_name title="Station"/>
    <Column id=station_code title="Code"/>
    <Column id=region title="Region"/>
    <Column id=total_events title="Stops" fmt='#,###'/>
    <Column id=on_time_percentage title="OTP %" fmt='#,##0.0"%"' contentType=colorscale scaleColor=green/>
    <Column id=avg_delay_minutes title="Avg Delay (min)" fmt='#,##0.00' contentType=colorscale scaleColor=red/>
</DataTable>

## Busiest Stations

```sql busiest_stations
SELECT
    station_name,
    station_code,
    region,
    total_events,
    total_trains,
    on_time_percentage,
    avg_delay_minutes
FROM warehouse.station_performance
ORDER BY total_events DESC
LIMIT 10
```

<DataTable data={busiest_stations}>
    <Column id=station_name title="Station"/>
    <Column id=station_code title="Code"/>
    <Column id=region title="Region"/>
    <Column id=total_events title="Stops" fmt='#,###'/>
    <Column id=on_time_percentage title="OTP %" fmt='#,##0.0"%"' contentType=colorscale scaleColor=green/>
    <Column id=avg_delay_minutes title="Avg Delay (min)" fmt='#,##0.00'/>
</DataTable>

---

[← Back to Dashboard](/)
