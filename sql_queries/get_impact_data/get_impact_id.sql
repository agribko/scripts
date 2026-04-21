SELECT
tag_impact_alert.impact_id AS impact_id
FROM
tag_hardware_register left outer join (select short_vehicle_id, tag_mac_address from vehicle_tags where deleted_date is null) as thwr_v_t using (tag_mac_address)
left outer join vehicles_v2 thwr_v_v2 using (short_vehicle_id)
LEFT OUTER JOIN
tag_impact_alert
ON tag_hardware_register.tag_mac_address = tag_impact_alert.tag_mac_address

WHERE (tag_impact_alert.tag_mac_address in ('0c:c8:44:31:18:88', '0c:c8:44:05:6f:cb')) AND (timezone('+9', tag_impact_alert.ts) > CURRENT_DATE)
GROUP BY
1
ORDER BY
1 desc

