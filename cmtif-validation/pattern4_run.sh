#!/bin/bash
# Pattern 4 DB validation runner
# Runs all SQL queries, saves CSV output, validates deletion state

DB="dw-staging_aurora-ro"
RESULTS_DIR="results/pattern4"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG="$RESULTS_DIR/run_${TIMESTAMP}.log"
mkdir -p "$RESULTS_DIR"

log() { echo "$(date +%Y-%m-%dT%H:%M:%SZ) | $*" | tee -a "$LOG"; }

PASS=0
FAIL=0

validate_case() {
  local case_id="$1"
  local sql_file="sql/${case_id}.sql"
  local csv_file="$RESULTS_DIR/${case_id}.csv"

  psql -d "$DB" -f "$sql_file" --csv > "$csv_file" 2>&1

  # No rows = hard deleted = PASS
  if [ "$(wc -l < "$csv_file")" -le 1 ]; then
    log "$case_id | PASS (no row found — hard deleted)"
    ((PASS++))
    return
  fi

  # Check based on case prefix
  case "$case_id" in
    C*)  # app_users: active should be 'f'
      if grep -q ",f$" "$csv_file"; then
        log "$case_id | PASS (active=f)"
      else
        log "$case_id | FAIL (active is not f)"
        ((FAIL++))
        return
      fi
      ;;
    D*)  # vehicles_v2: deleted_date should not be empty
      if grep -v "^short_vehicle_id" "$csv_file" | grep -qv ",$"; then
        log "$case_id | PASS (deleted_date is set)"
      else
        log "$case_id | FAIL (deleted_date is empty)"
        ((FAIL++))
        return
      fi
      ;;
    E*|F*)  # teams_team / fleets_fleet: deleted should be 't'
      if grep -q ",t$" "$csv_file"; then
        log "$case_id | PASS (deleted=t)"
      else
        log "$case_id | FAIL (deleted is not t)"
        ((FAIL++))
        return
      fi
      ;;
  esac

  ((PASS++))
}

log "=== Pattern 4 DB Validation ==="
log "Database: $DB"
log ""

for sql in sql/C*.sql sql/D*.sql sql/E*.sql sql/F*.sql; do
  case_id=$(basename "$sql" .sql)
  validate_case "$case_id"
done

log ""
log "=== SUMMARY ==="
log "PASS: $PASS | FAIL: $FAIL | TOTAL: $((PASS + FAIL))"
