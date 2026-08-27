#!/bin/bash
# Scenario 02: 最小桁数での登録を確認
# Tests that all APIs accept values at their minimum digit/character lengths.
# short_user_id: 9 digits (100000000)
# short_vehicle_id: 9 digits (100000000)
# drive_id: 36 chars (standard UUID)
# short_user_id in drive_update: 1 digit (0) per vendor note

scenario_name="02_minimum_digit_length"

run_scenario() {
    local step=0
    local failed=0

    # Step 1: Register user with minimum-length short_user_id (9 digits)
    if [ "$SKIP_REGISTRATION" != "true" ]; then
        step=$((step + 1))
        log_step $step "user_update - Register user (min 9-digit short_user_id)"

        local user_register_payload=$(cat <<EOF
  {
    "short_user_id": ${SHORT_USER_ID_02},
    "name_primary": "最小太郎",
    "name_secondary": "サイショウタロウ",
    "mail": "min.test@example.com",
    "phone_number": "09000000001",
    "fleet_id": ${FLEET_ID},
    "team_id": ${TEAM_ID}
  }
EOF
)
        call_api "POST" "/user_update" "$user_register_payload"
        check_result $step "user_update (register, min digits)" "short_user_id=${SHORT_USER_ID_02}" || failed=$((failed + 1))
    else
        log_info "Skipping user registration (SKIP_REGISTRATION=true)"
    fi

    # Step 2: Update user with minimum-length short_user_id
    step=$((step + 1))
    log_step $step "user_update - Update user (min 9-digit short_user_id)"

    local user_update_payload=$(cat <<EOF
  {
    "short_user_id": ${SHORT_USER_ID_02},
    "name_primary": "最小次郎",
    "name_secondary": "サイショウジロウ",
    "mail": "min.test@example.com",
    "phone_number": "09000000001",
    "fleet_id": ${FLEET_ID},
    "team_id": ${TEAM_ID}
  }
EOF
)
    call_api "POST" "/user_update" "$user_update_payload"
    check_result $step "user_update (update, min digits)" "short_user_id=${SHORT_USER_ID_02}" || failed=$((failed + 1))

    # Step 3: Register vehicle with minimum-length short_vehicle_id (9 digits)
    if [ "$SKIP_REGISTRATION" != "true" ]; then
        step=$((step + 1))
        log_step $step "vehicle_update - Register vehicle (min 9-digit short_vehicle_id)"

        local vehicle_register_payload=$(cat <<EOF
  {
    "short_vehicle_id": ${SHORT_VEHICLE_ID_02},
    "registration": "東京|100|う|0001",
    "fleet_id": ${FLEET_ID}
  }
EOF
)
        call_api "POST" "/vehicle_update" "$vehicle_register_payload"
        check_result $step "vehicle_update (register, min digits)" "short_vehicle_id=${SHORT_VEHICLE_ID_02}" || failed=$((failed + 1))
    else
        log_info "Skipping vehicle registration (SKIP_REGISTRATION=true)"
    fi

    # Step 4: Update vehicle with minimum-length short_vehicle_id
    step=$((step + 1))
    log_step $step "vehicle_update - Update vehicle (min 9-digit short_vehicle_id)"

    local vehicle_update_payload=$(cat <<EOF
  {
    "short_vehicle_id": ${SHORT_VEHICLE_ID_02},
    "registration": "東京|100|う|0002",
    "fleet_id": ${FLEET_ID}
  }
EOF
)
    call_api "POST" "/vehicle_update" "$vehicle_update_payload"
    check_result $step "vehicle_update (update, min digits)" "short_vehicle_id=${SHORT_VEHICLE_ID_02}" || failed=$((failed + 1))

    # Step 5: Drive update - link drive to user (36-char drive_id, 9-digit short_user_id)
    step=$((step + 1))
    log_step $step "drive_update - Link drive to user (min-length drive_id=36 chars, short_user_id=9 digits)"

    local drive_link_payload=$(cat <<EOF
  {
    "drive_id": "${DRIVE_ID_02}",
    "short_user_id": ${SHORT_USER_ID_02}
  }
EOF
)
    call_api "POST" "/drive_update" "$drive_link_payload"
    check_result $step "drive_update (link, min digits)" "drive_id=${DRIVE_ID_02}, short_user_id=${SHORT_USER_ID_02}" || failed=$((failed + 1))

    # Step 6: Drive update - unlink drive (short_user_id=0, min 1 digit per vendor note)
    step=$((step + 1))
    log_step $step "drive_update - Unlink drive (short_user_id=0, min 1 digit)"

    local drive_unlink_payload=$(cat <<EOF
  {
    "drive_id": "${DRIVE_ID_02}",
    "short_user_id": 0
  }
EOF
)
    call_api "POST" "/drive_update" "$drive_unlink_payload"
    check_result $step "drive_update (unlink, min 1 digit)" "drive_id=${DRIVE_ID_02}, short_user_id=0" || failed=$((failed + 1))

    return $failed
}
