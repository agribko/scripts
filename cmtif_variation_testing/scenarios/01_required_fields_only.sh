#!/bin/bash
# Scenario 01: 必須項目のみで登録できることを確認
# Tests that all 3 APIs accept payloads with only required fields.

scenario_name="01_required_fields_only"

run_scenario() {
    local step=0
    local failed=0

    # Step 1: Register user (required fields only)
    if [ "$SKIP_REGISTRATION" != "true" ]; then
        step=$((step + 1))
        log_step $step "user_update - Register user (required fields only)"

        local user_register_payload=$(cat <<EOF
  {
    "short_user_id": ${SHORT_USER_ID_01},
    "name_primary": "テスト太郎",
    "name_secondary": "テストタロウ",
    "mail": "test.taro@example.com",
    "phone_number": "09012345678",
    "fleet_id": ${FLEET_ID},
    "team_id": ${TEAM_ID}
  }
EOF
)
        call_api "POST" "/user_update" "$user_register_payload"
        check_result $step "user_update (register)" "short_user_id=${SHORT_USER_ID_01}" || failed=$((failed + 1))
    else
        log_info "Skipping user registration (SKIP_REGISTRATION=true)"
    fi

    # Step 2: Update user (only mandatory field: short_user_id)
    step=$((step + 1))
    log_step $step "user_update - Update user (required fields only)"

    local user_update_payload=$(cat <<EOF
  {
    "short_user_id": ${SHORT_USER_ID_01},
    "name_primary": "テスト次郎",
    "name_secondary": "テストジロウ",
    "mail": "test.taro@example.com",
    "phone_number": "09012345678",
    "fleet_id": ${FLEET_ID},
    "team_id": ${TEAM_ID}
  }
EOF
)
    call_api "POST" "/user_update" "$user_update_payload"
    check_result $step "user_update (update)" "short_user_id=${SHORT_USER_ID_01}" || failed=$((failed + 1))

    # Step 3: Register vehicle (required fields only)
    if [ "$SKIP_REGISTRATION" != "true" ]; then
        step=$((step + 1))
        log_step $step "vehicle_update - Register vehicle (required fields only)"

        local vehicle_register_payload=$(cat <<EOF
  {
    "short_vehicle_id": ${SHORT_VEHICLE_ID_01},
    "registration": "品川|500|あ|9999",
    "fleet_id": ${FLEET_ID}
  }
EOF
)
        call_api "POST" "/vehicle_update" "$vehicle_register_payload"
        check_result $step "vehicle_update (register)" "short_vehicle_id=${SHORT_VEHICLE_ID_01}" || failed=$((failed + 1))
    else
        log_info "Skipping vehicle registration (SKIP_REGISTRATION=true)"
    fi

    # Step 4: Update vehicle (only mandatory field: short_vehicle_id)
    step=$((step + 1))
    log_step $step "vehicle_update - Update vehicle (required fields only)"

    local vehicle_update_payload=$(cat <<EOF
  {
    "short_vehicle_id": ${SHORT_VEHICLE_ID_01},
    "registration": "大阪|300|い|8888",
    "fleet_id": ${FLEET_ID}
  }
EOF
)
    call_api "POST" "/vehicle_update" "$vehicle_update_payload"
    check_result $step "vehicle_update (update)" "short_vehicle_id=${SHORT_VEHICLE_ID_01}" || failed=$((failed + 1))

    # Step 5: Drive update (link drive to user)
    step=$((step + 1))
    log_step $step "drive_update - Link drive to user (required fields only)"

    local drive_update_payload=$(cat <<EOF
  {
    "drive_id": "${DRIVE_ID_01}",
    "short_user_id": ${SHORT_USER_ID_01}
  }
EOF
)
    call_api "POST" "/drive_update" "$drive_update_payload"
    check_result $step "drive_update" "drive_id=${DRIVE_ID_01}, short_user_id=${SHORT_USER_ID_01}" || failed=$((failed + 1))

    return $failed
}
