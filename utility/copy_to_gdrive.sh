#!/bin/bash
set -euo pipefail

TICKET=${1:?Usage: $0 <ticket_number> <escalation_file>}
ESCALATION=${2:?Usage: $0 <ticket_number> <escalation_file>}

# Destination directory (with date)
DEST_DIR="/Users/agribko/Google Drive/Shared drives/CMT Customers/Aioi/09 - Escalation/Escalation_List/Escalation_issues_by_2025_10_07/Zen-${TICKET}"

# Create directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Go to Downloads
cd /Users/agribko/Downloads || { echo "Downloads directory not found"; exit 1; }

# Create new filename with suffix
new="${ESCALATION%.xlsx}_CMT_ご返答.xlsx"

# Copy and rename file locally
cp "$ESCALATION" "$new"

# Copy renamed file to destination directory
cp "$ESCALATION" "$new" "$DEST_DIR/"

echo "✅ Escalation files copied to: $DEST_DIR"


