select added_by_short_user_id, short_vehicle_id, tag_mac_address, added_date  from vehicle_tags where tag_mac_address  in (:list) AND deleted_date is null;
