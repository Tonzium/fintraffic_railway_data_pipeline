---
title: Detailed On-Time Performance 📉
---

# On-Time Performance Details

```sql all_metrics
SELECT
    metric_scope,
    total_trains,
    total_events,
    on_time_percentage,
    avg_delay_minutes,
    total_stations
FROM warehouse.on_time_performance
ORDER BY on_time_percentage DESC
```

## Overview

<BigValue
    data={all_metrics}
    value=on_time_percentage
    title="Overall OTP"
    fmt='#,##0.0"%"'
    where="metric_scope='Overall'"
/>

<BigValue
    data={all_metrics}
    value=avg_delay_minutes
    title="Avg Delay"
    fmt='#,##0.0" min"'
    where="metric_scope='Overall'"
/>

## Performance by Scope

<BarChart
    data={all_metrics}
    x=metric_scope
    y=on_time_percentage
    title="OTP % by Scope"
    yFmt='#,##0.0"%"'
    swapXY=true
    sort=on_time_percentage
/>

<DataTable data={all_metrics}>
    <Column id=metric_scope title="Scope"/>
    <Column id=total_trains title="Trains" fmt='#,###'/>
    <Column id=total_events title="Events" fmt='#,###'/>
    <Column id=on_time_percentage title="OTP %" fmt='#,##0.0"%"' contentType=colorscale scaleColor=green/>
    <Column id=avg_delay_minutes title="Avg Delay" fmt='#,##0.00'/>
    <Column id=total_stations title="Stations" fmt='#,###'/>
</DataTable>
