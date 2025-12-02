-- Deduplication: keep latest version if duplicates exist

{% if is_incremental() %}
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY trainNumber, departureDate
    ORDER BY version DESC, _loaded_at DESC
) = 1
{% endif %}