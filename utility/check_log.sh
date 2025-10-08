#!/bin/bash
set -u

# ===== Colors =====
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
BLUE=$'\e[34m'
CYAN=$'\e[36m'
BOLD=$'\e[1m'
RESET=$'\e[0m'
# ===== Helpers =====
# Strip ANSI escape sequences
strip_ansi() { sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g'; }

# Center a single line
center_text() {
  local text="$1"
  local width pad visible
  width=$(tput cols 2>/dev/null || echo 80)
  visible=$(printf '%s' "$text" | strip_ansi)
  pad=$(( (width - ${#visible}) / 2 ))
  (( pad < 0 )) && pad=0
  printf '%*s%s\n' "$pad" '' "$text"
}

# Center multi-line blocks (e.g., your `uniq -c` output)
center_block() {
  while IFS= read -r line; do
    center_text "$line"
  done
}

LOG_FILE=${1:?Usage: $0 LOG_FILE}

START_TS=$(head -n2 -- "$LOG_FILE" | tail -1 | awk -F, '{print $4}')
END_TS=$(tail -n1 -- "$LOG_FILE" | awk -F, '{print $4}')

BATTERY_STATUS=$(
  rg -q 'ignBatteryOpt=false' -- "$LOG_FILE" \
    && echo "BATTERY OPTIMISATION ON" \
    || echo "BATTERY OPTIMISATION OFF"
)

#LOW_MEMORY_COUNT=$(rg -c 'LOW MEMORY' -- $LOG_FILE || true)
LOW_MEMORY_COUNT=$(rg 'last_process_exit_reason' $LOG_FILE | awk -F'=' '{ split($3,a,","); print a[1]}' | sort | uniq -c)
TRIM_MEMORY_COUNT=$(rg -c 'TRIM' -- $LOG_FILE || echo 0)
BTLE_TIMEOUT_COUNT=$(rg -c 'BTLE Connection timed out' -- $LOG_FILE || echo 0)
TAG_ERROR_COUNT=$(rg -c 'SERVER_ERROR_TAG_ALREADY_LINKED|SCANNING_ERROR_NO_TAGS_FOUND' -- $LOG_FILE || echo 0) 
GPS_FAILURE_COUNT=$(rg -c -i 'GPS FAILURE' -- $LOG_FILE || echo 0)

printf "\n"
center_text "${BOLD}${CYAN}=== LOG SUMMARY REPORT ===${RESET}"
printf "\n"

center_text "Log begins at: ${YELLOW}${START_TS}${RESET}"
center_text "Log ends at:   ${YELLOW}${END_TS}${RESET}"
printf "\n"

center_text "Battery status: ${BATTERY_STATUS}"
center_text "TRIM MEMORY: ${RED}${TRIM_MEMORY_COUNT}${RESET}"
center_text "BTLE TIMEOUT: ${RED}${BTLE_TIMEOUT_COUNT}${RESET}"
center_text "GPS FAILURE: ${RED}${GPS_FAILURE_COUNT}${RESET}"
center_text "TAG ERROR: ${RED}${TAG_ERROR_COUNT}${RESET}"
printf "\n"

center_text "${BOLD}LOW MEMORY AND WARNINGS${RESET}"
echo "$LOW_MEMORY_COUNT" | center_block

printf "\n"
center_text "${BLUE}=================================${RESET}"
