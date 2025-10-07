#!/bin/bash
set -euo pipefail

TICKET=${1:?Usage: $0 <ticket_number> <escalation_file> <zip_password>}
ESCALATION=${2:?Usage: $0 <ticket_number> <escalation_file> <zip_password>}
PASSWORD=${3:?Usage: $0 <ticket_number> <escalation_file> <zip_password>}

# Destination directory 
DEST_DIR="/Users/agribko/Google Drive/Shared drives/CMT Customers/Aioi/09 - Escalation/Escalation_List/Escalation_issues_by_2025_10_07/Zen-${TICKET}"
DOWNLD="/Users/agribko/Downloads"

# Go to Downloads
cd "$DOWNLD" || { echo "Downloads directory not found"; exit 1; }

# Create new filename with suffix
new="${ESCALATION%.xlsx}_CMT_ご返答.xlsx"

# Copy renamed file to downloads
cp  "$DEST_DIR/$new" "$DOWNLD"
zip_name="${new%.xlsx}.zip"
zip -P "$PASSWORD" "$zip_name" "$new"

echo "✅ Escalation file copied and zipped $zip_name"
