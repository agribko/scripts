#!/bin/bash
# required to use fleet_id for the api call, not fleet_reporting_id 

API_KEY=""
URL_ROOT="https:///api/v1/fleets"
LOGFILE="delete_log_$(date +%Y%m%d_%H%M%S).txt"

while read -r fleet; do
    # Capture HTTP status code only, discard body
    status=$(curl -s -o /dev/null -w "%{http_code}" \
      -X DELETE "${URL_ROOT}/${fleet}/" \
      -H "X-Cmt-Api-Key: ${API_KEY}" \
      -H "Content-Type: application/json")

    if [[ "$status" == "200" || "$status" == "204" ]]; then
        echo "[OK] fleet $fleet deleted (status $status)" | tee -a "$LOGFILE"
    else
        echo "[ERROR] Failed to delete fleet $fleet (status $status)" | tee -a "$LOGFILE"
        echo "$fleet" >> failed_fleets.txt
    fi
done < fleets_to_delete.txt
