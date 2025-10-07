SELECT tag_mac_address, short_vehicle_id FROM vehicle_tags  WHERE tag_mac_address in () AND deleted_date is null;
