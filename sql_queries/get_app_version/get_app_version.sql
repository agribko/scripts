select last_app_version, 
count (*) as count,
    CONCAT(
        CASE 
    WHEN json_extract_path_text(device::json, 'version_codename') = 'iOS' THEN 'iOS'
    ELSE 'Android'
    END,
    '-',
    COALESCE(json_extract_path_text(device::json, 'version_release'), 'unknown')
) AS platform_version
from app_user_device_settings 
where (last_app_version ~ '^[0-2]\.' or last_app_version !~ '^[0-9]+\.') and
(last_authorized_date notnull and (last_deauthorized_date is null or last_authorized_date >= last_deauthorized_date)) = 't' 
-- and last_authorized_date >= CURRENT_DATE - INTERVAL '3 days' 
and last_authorized_date >= '2025-01-01'
GROUP BY 
last_app_version,
platform_version
ORDER BY 
count DESC;
