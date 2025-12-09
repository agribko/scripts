select short_user_id from app_users au
left join fleets_fleet ff on ff.id = au.fleet_id
where active = true
and ff.reporting_name in (
);
