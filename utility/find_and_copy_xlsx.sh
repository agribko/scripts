#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="/Users/agribko/Google Drive/Shared drives/CMT Customers/Aioi/09 - Escalation/Escalation_List"
DEST_DIR="/Users/agribko/tag_data_analysis_2023"

mkdir -p "$DEST_DIR"

# Directories to search (relative to SOURCE_DIR)
DIRS=(
"Escalation_issues_by_2023_01_10"
"Escalation_Issues_by_2023_02_07"
"Escalation_issues_by_2023_03_07"
"Escalation_issues_by_2023_04_11"
"Escalation_issues_by_2023_05_09"
"Escalation_issues_by_2023_06_13"
"Escalation_issues_by_2023_07_11"
"Escalation_issues_by_2023_08_08"
"Escalation_issues_by_2023_09_12"
"Escalation_issues_by_2023_10_10"
"Escalation_issues_by_2023_11_07"
"Escalation_issues_by_2023_12_12"
)

for dir in "${DIRS[@]}"; do
  full_dir="${SOURCE_DIR}/${dir}"
  echo "Scanning: $full_dir"

  # Correct fd invocation:
  #   fd <pattern> <directory>
  # Pattern must NOT contain slashes.
  fd . -t f -e xlsx "$full_dir" -x cp -v {} "$DEST_DIR"
done
