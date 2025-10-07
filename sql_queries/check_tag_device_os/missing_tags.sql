-- SELECT d.tag_mac_address, aus.device_os 
SELECT d.short_user_id, d.tag_mac_address
FROM datasets d 
JOIN app_user_device_settings aus ON d.short_user_id = aus.short_user_id 
WHERE d.tag_mac_address IN (

) 
GROUP BY d.short_user_id, d.tag_mac_address;
-- GROUP BY d.tag_mac_address, aus.device_os;
