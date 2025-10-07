SELECT d.short_user_id as id, d.tag_mac_address, a.email as email FROM datasets d JOIN app_users a ON d.short_user_id = a.short_user_id WHERE tag_mac_address in (
);
