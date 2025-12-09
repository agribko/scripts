SELECT *
FROM spectrum.sdk_device_logs
WHERE app_id = 474
AND received_date >= current_date - interval '1 days'
AND device_id_prefix = '26'
AND device_id LIKE '26A5ADE0%'
;
