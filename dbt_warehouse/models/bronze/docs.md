{% docs bronze_stations_desc %}

# Bronze: Railway station data

Raw station master data from Digitraffic API.  

Includes all railway stations in Finland.

{% enddocs %}


{% docs bronze_train_deps %}

# Bronze: Train departure data

Raw train departure data with nested timetable information.  
Each record represents one train's journey on a specific date, including all station stops in the timeTableRows nested array.  

Loaded incrementally based on departureDate to handle growing dataset efficiently.  

#### NOTE
timeTableRows is kept as nested STRUCT array - flattening deferred to silver layer.  

{% enddocs %}