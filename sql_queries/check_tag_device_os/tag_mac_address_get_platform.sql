WITH last_trips (tag_mac_address, short_user_id, mmh_trip_start) AS (
    SELECT tag_mac_address,
        short_user_id,
        last_recorded_drive_start
    FROM user_tag_drives_summary
    WHERE tag_mac_address IN (
        )
)
SELECT driveid,
    tag_mac_address,
    short_user_id,
    device_config_id,
    dch.device_config
FROM datasets
JOIN last_trips USING (tag_mac_address, short_user_id, mmh_trip_start)
JOIN device_config_history dch USING (device_config_id);;
