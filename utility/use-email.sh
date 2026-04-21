#!/usr/bin/env zsh
set -euo pipefail

source /Users/agribko/fzfstash.zsh
# Resolve this script's directory so sibling scripts/SQL paths are stable
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

csv=${1:?Usage: use-email <csv_file>}

base=$(basename $csv)
export CMD_STASH_TRAY="${base%.csv}"
# Extract email and copy it to clipboard in one pass (get_email handles pbcopy via tee)

EMAIL="$("$SCRIPT_DIR/get_email_from_csv.sh" "$csv" |
    tee >(command -v pbcopy >/dev/null 2>&1 && pbcopy || cat >/dev/null))"
# Short user id from email
SHORT_ID="$("$SCRIPT_DIR/get_user_short_id.sh" "$EMAIL")"

# Workspace
WORKDIR="$(mktemp -d 2>/dev/null || mktemp -d -t logs)"
RAW_CSV="$WORKDIR/device_raw.csv"           # CSV from psql
RAW_LOG="$WORKDIR/log_raw.csv"              # CSV from psql
JSON_LOG="$WORKDIR/${SHORT_ID}_log.json"    # Parsed JSON
LINK="$HOME/Downloads/${SHORT_ID}_log.json" # Stable symlink for humans

ln -sf "$JSON_LOG" "$LINK"

# Run SQL without cd; make output deterministic and fail on errors
SQL_DIR="$SCRIPT_DIR/../sql_queries/get_device_logs"
PGDATABASE="aioi-prod_aurora-ro"
REDSHIFTDATABASE="aioi-prod_redshift"

psql --no-psqlrc --csv \
    -v "ON_ERROR_STOP=1" \
    -v "short_id=$SHORT_ID" \
    -f "$SQL_DIR/get_user_device_id.sql" \
    "$PGDATABASE" >"$RAW_CSV"

DEVICE_ID=$(awk -F',' 'NR > 1 {printf "\x27%s%%\x27", substr($1,1,8)}' "$RAW_CSV")

psql --no-psqlrc --csv \
    -v "ON_ERROR_STOP=1" \
    -v "device=$DEVICE_ID" \
    -f "$SQL_DIR/get_device_log.sql" \
    "$REDSHIFTDATABASE" >"$RAW_LOG"

# Extract the last row's extra_info as JSON:
# - keep header so xsv can select by name
# - drop header
# - take last row
# - fix CSV-escaped quotes
# - pretty/validate via jq
xsv select extra_info "$RAW_CSV" |
    tail -n +2 |
    tail -n 1 |
    sed 's/""/"/g; s/^"//; s/"$//' |
    jq -r '.' >"$JSON_LOG"

# Stash handy actions (quote safely)
STASH="${STASH:-$HOME/bin/stash}"
if command -v "$STASH" >/dev/null 2>&1; then
    "$STASH" "checkdevice '$LINK'"
    "$STASH" "getplatform '$RAW_CSV'"
    "$STASH" "getappversion '$RAW_CSV'"
    "$STASH" "checklog '$RAW_LOG'"

    "$STASH" "getlink '$SHORT_ID'"
    "$STASH" "rm $LINK"
fi
