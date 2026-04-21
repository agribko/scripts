SELECT
coalesce(mapmatch_history.trip_start at time zone 'UTC' at time zone datasets.utc_offset_with_dst, mapmatch_history.trip_start) AS expr1,
coalesce(mapmatch_history.trip_end at time zone 'UTC' at time zone datasets.utc_offset_with_dst, mapmatch_history.trip_end) AS expr2,
mapmatch_history.distance_mapmatched_km AS expr3,
datasets.tag_mac_address AS TagID,
datasets.driveid AS expr5
FROM
app_users
LEFT OUTER JOIN
datasets
ON datasets.short_user_id = app_users.short_user_id

LEFT OUTER JOIN
mapmatch_history
ON datasets.mmh_id = mapmatch_history.id

WHERE (app_users.short_user_id in ('540236025', '105864177') AND (not datasets.mmh_hide) AND (mapmatch_history.id notnull)
GROUP BY
1,2,3,4,5
ORDER BY
1 desc
LIMIT 20

