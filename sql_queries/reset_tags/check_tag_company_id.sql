SELECT tag_mac_address, company 
FROM tag_hardware_register 
WHERE tag_mac_address IN (:list);
