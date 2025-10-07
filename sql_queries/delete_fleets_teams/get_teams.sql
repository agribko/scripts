select teams.id as team_id, teams.name,fleets.id as fleet_id, fleets.reporting_name as fleet_reporting_name,fleets.name
from teams_team teams join fleets_fleet fleets on teams.fleet_id = fleets.id
where teams.deleted = false
and fleets.deleted = false
and fleets.reporting_name in (
);
