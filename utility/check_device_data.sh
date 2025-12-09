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

LOG_TIME=$(jq -r '((.ts / 1000) + 9*3600| round | todateiso8601)' $LOG_FILE)
BATTERY_STATUS=$(
  rg -q '"ign_battery_opt": false' -- "$LOG_FILE" \
    && echo "BATTERY OPTIMISATION ON" \
    || echo "BATTERY OPTIMISATION OFF"
)

POWER_SAVE=$(
  rg -q '"power_save": true' -- "$LOG_FILE" \
    && echo "POWER SAVE ON" \
    || echo "POWER SAVE OFF"
)
BG_RESTRICTED=$(
  rg -q '"bg_restricted": true' -- "$LOG_FILE" \
    && echo "BACKGROUND RESTRICTED ON" \
    || echo "BACKGROUND RESTRICTED OFF"
)
APP_STANDBY_BUCKET=$(
  rg -q '"app_standby_bucket": "active"' -- "$LOG_FILE" \
    && echo "ADAPTIVE BATTERY OFF" \
    || echo "ADAPTIVE BATTERY SETTINGS NEED TO BE CHECKED"
)

ACTIVITY_PERMISSION=$(
  rg -q '"activity_recognition_permission": true' -- "$LOG_FILE" \
    && echo "ACTIVITY RECONITION PERMISSION IS GRANTED" \
    || echo "ACTIVITY RECONITION PERMISSION IS MISSING"
)
printf "\n"
center_text "${BOLD}${CYAN}=== DEVICE DATA LOG SUMMARY REPORT ===${RESET}"
printf "\n"

center_text "Log is as of: ${YELLOW}${LOG_TIME}${RESET}"
printf "\n"

center_text "Battery status: ${BATTERY_STATUS}"
center_text "${POWER_SAVE}"
center_text "${BG_RESTRICTED}"
center_text "${APP_STANDBY_BUCKET}"
center_text "${ACTIVITY_PERMISSION}"
printf "\n"

printf "\n"
center_text "${BLUE}=================================${RESET}"
