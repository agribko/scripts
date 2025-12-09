SELECT device_id,last_app_version,
CONCAT(
    COALESCE(json_extract_path_text(device::json, 'manufacturer'), 'unknown'),
    '-',
    CASE 
    WHEN json_extract_path_text(device::json, 'version_codename') = 'iOS' THEN 'iOS'
    ELSE 'OS'
    END,
    ' ',
    COALESCE(json_extract_path_text(device::json, 'version_release'), 'unknown')
) AS platform_version,
extra_info
FROM app_user_device_settings 
WHERE short_user_id=(:short_id) 
AND last_request_date >= current_date - interval '1 day';
-- and last_received_date >= current_date;
