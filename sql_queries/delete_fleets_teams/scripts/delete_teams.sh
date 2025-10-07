#!/bin/bash

API_KEY=""
URL_ROOT="https:///api/v1/teams"
LOGFILE="delete_log_$(date +%Y%m%d_%H%M%S).txt"

while read -r team; do
    # Capture HTTP status code only, discard body
    status=$(curl -s -o /dev/null -w "%{http_code}" \
      -X DELETE "${URL_ROOT}/${team}/" \
      -H "X-Cmt-Api-Key: ${API_KEY}" \
      -H "Content-Type: application/json")

    if [[ "$status" == "200" || "$status" == "204" ]]; then
        echo "[OK] Team $team deleted (status $status)" | tee -a "$LOGFILE"
    else
        echo "[ERROR] Failed to delete team $team (status $status)" | tee -a "$LOGFILE"
        echo "$team" >> failed_teams.txt
    fi
done < teams_to_delete.txt
