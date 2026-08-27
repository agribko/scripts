#!/bin/bash
# CMTIF Variation Testing - Main Runner
# Usage:
#   ./run_tests.sh          # run all scenarios
#   ./run_tests.sh 1        # run scenario 01 only
#   ./run_tests.sh 2        # run scenario 02 only
#   ./run_tests.sh 1 2      # run scenarios 01 and 02

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIOS_DIR="${SCRIPT_DIR}/scenarios"
RESULTS_DIR="${SCRIPT_DIR}/results"

# Load environment
if [ ! -f "${SCRIPT_DIR}/.env" ]; then
    echo "ERROR: .env file not found. Copy .env.template to .env and fill in values."
    exit 1
fi
source "${SCRIPT_DIR}/.env"

# Validate required env vars
for var in BASE_URL API_KEY FLEET_ID TEAM_ID; do
    if [ -z "${!var:-}" ]; then
        echo "ERROR: ${var} is not set in .env"
        exit 1
    fi
done

# Setup results
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${RESULTS_DIR}/report_${TIMESTAMP}.txt"

# Globals for API calls
HTTP_CODE=""
RESPONSE_BODY=""

# --- Helper functions ---

log_header() {
    local msg="$1"
    echo "============================================================" | tee -a "$REPORT_FILE"
    echo " $msg" | tee -a "$REPORT_FILE"
    echo "============================================================" | tee -a "$REPORT_FILE"
}

log_step() {
    local step_num=$1
    local description="$2"
    echo "" | tee -a "$REPORT_FILE"
    echo "--- Step ${step_num}: ${description} ---" | tee -a "$REPORT_FILE"
}

log_info() {
    echo "[INFO] $1" | tee -a "$REPORT_FILE"
}

log_pass() {
    echo "[PASS] $1" | tee -a "$REPORT_FILE"
}

log_fail() {
    echo "[FAIL] $1" | tee -a "$REPORT_FILE"
}

call_api() {
    local method="$1"
    local endpoint="$2"
    local payload="$3"
    local url="${BASE_URL}${endpoint}"

    local compact_payload
    compact_payload=$(echo "$payload" | jq -c '.')

    log_info "Request: ${method} ${url}"
    log_info "Payload: ${compact_payload}"

    local tmp_file
    tmp_file=$(mktemp)

    HTTP_CODE=$(curl -s -o "$tmp_file" -w "%{http_code}" \
        -X "$method" \
        -H "x-api-key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "$compact_payload" \
        "$url")

    RESPONSE_BODY=$(cat "$tmp_file")
    rm -f "$tmp_file"

    log_info "HTTP Status: ${HTTP_CODE}"
    log_info "Response: ${RESPONSE_BODY}"
}

check_result() {
    local step_num=$1
    local test_name="$2"
    local identifiers="$3"

    if [ "$HTTP_CODE" = "200" ] && echo "$RESPONSE_BODY" | grep -q '"status":\s*0\|"status": 0'; then
        log_pass "${test_name} | ${identifiers}"
        return 0
    else
        log_fail "${test_name} | ${identifiers} | HTTP=${HTTP_CODE}"
        if [ -n "$RESPONSE_BODY" ]; then
            log_fail "Response body: ${RESPONSE_BODY}"
        fi
        return 1
    fi
}

# --- Determine which scenarios to run ---

scenario_files=()

if [ $# -eq 0 ]; then
    # No arguments: run all scenarios
    for f in "${SCENARIOS_DIR}"/*.sh; do
        [ -f "$f" ] && scenario_files+=("$f")
    done
else
    # Run only specified scenarios
    for num in "$@"; do
        padded=$(printf "%02d" "$num")
        matched=false
        for f in "${SCENARIOS_DIR}/${padded}_"*.sh; do
            if [ -f "$f" ]; then
                scenario_files+=("$f")
                matched=true
            fi
        done
        if [ "$matched" = false ]; then
            echo "ERROR: No scenario file found for number ${num} (looked for ${SCENARIOS_DIR}/${padded}_*.sh)"
            exit 1
        fi
    done
fi

if [ ${#scenario_files[@]} -eq 0 ]; then
    echo "ERROR: No scenario files found in ${SCENARIOS_DIR}/"
    exit 1
fi

# --- Main ---

log_header "CMTIF Variation Testing - $(date '+%Y-%m-%d %H:%M:%S')"
echo "" | tee -a "$REPORT_FILE"
log_info "Base URL: ${BASE_URL}"
log_info "Fleet ID: ${FLEET_ID}"
log_info "Team ID: ${TEAM_ID}"
log_info "Skip Registration: ${SKIP_REGISTRATION:-false}"
log_info "Scenarios to run: ${#scenario_files[@]}"

total_scenarios=0
total_passed=0
total_failed=0

for scenario_file in "${scenario_files[@]}"; do
    total_scenarios=$((total_scenarios + 1))
    source "$scenario_file"

    echo "" | tee -a "$REPORT_FILE"
    log_header "Scenario: ${scenario_name}"

    if run_scenario; then
        log_info "Scenario ${scenario_name}: ALL STEPS PASSED"
        total_passed=$((total_passed + 1))
    else
        failed_count=$?
        log_info "Scenario ${scenario_name}: ${failed_count} STEP(S) FAILED"
        total_failed=$((total_failed + 1))
    fi
done

# Summary
echo "" | tee -a "$REPORT_FILE"
log_header "SUMMARY"
log_info "Scenarios run: ${total_scenarios}"
log_info "Scenarios passed (all steps): ${total_passed}"
log_info "Scenarios with failures: ${total_failed}"
echo "" | tee -a "$REPORT_FILE"
log_info "Full report saved to: ${REPORT_FILE}"
