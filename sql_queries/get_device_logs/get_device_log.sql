--WITH p (app, device) AS (SELECT 474, (':device_id')::text)
--select date_trunc('second', received_time) as received_time,
--  date_trunc('second', log_time) as log_time,
--  log_number as ln,
--  level,
--  package,
--  obj_name,
--  thread_id,
--  time_in_bkgd,
--  message
--from spectrum.sdk_device_logs, p
--WHERE app_id = p.app
--  AND device_id_prefix = SUBSTRING(':device_id',1,2)
--   AND device_id = p.device
--  AND received_date >= current_date - interval '1 days'
--order by received_time, log_number, file_line_index, log_time;
--
WITH p AS (
  SELECT 474::int AS app,
         :device::text AS device
)
SELECT
  date_trunc('second', received_time) AS received_time,
  date_trunc('second', log_time)      AS log_time,
 -- log_number                          AS ln,
  level,
  package,
  obj_name,
  thread_id,
  --time_in_bkgd,
  message
FROM spectrum.sdk_device_logs_temp
CROSS JOIN p
WHERE app_id = p.app
  AND device_id_prefix = SUBSTRING(:device, 1, 2)  
  AND device_id LIKE :device                      
  AND received_date >= current_date - interval '2 days'
ORDER BY received_time, log_number, file_line_index, log_time;
