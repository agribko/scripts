#!/bin/bash
# Scenario 03: 最大桁数での登録を確認
# Tests that all APIs accept values at their maximum digit/character lengths.
# short_user_id: 9 digits, name_primary: 50 chars, name_secondary: 50 chars,
# mail: 255 chars, phone_number: 15 chars, policy_number: 10 chars,
# short_vehicle_id: 9 digits, registration: 32 chars, vin: 30 chars,
# tag_mac_address: 17 chars, drive_id: 36 chars

scenario_name="03_maximum_digit_length"

run_scenario() {
    local step=0
    local failed=0

    # Max-length test values
    local name_primary_50="あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをんアイウエ"
    local name_secondary_50="アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンイロハニ"
    local mail_255="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa@example-domain.com"
    local phone_15="090123456789012"
    local policy_10="ABCD123456"
    local registration_32="品川ああああああああ|12345|あ|1234567890123"
    local vin_30="123456789012345678901234567890"
    local tag_mac="AA:BB:CC:DD:EE:FF"

    # Step 1: Register user with all fields at max length
    if [ "$SKIP_REGISTRATION" != "true" ]; then
        step=$((step + 1))
        log_step $step "user_update - Register user (max-length fields)"
        log_info "name_primary length: ${#name_primary_50}"
        log_info "name_secondary length: ${#name_secondary_50}"
        log_info "mail length: ${#mail_255}"
        log_info "phone_number length: ${#phone_15}"
        log_info "policy_number length: ${#policy_10}"

        local user_register_payload=$(cat <<EOF
  {
    "short_user_id": ${SHORT_USER_ID_03},
    "name_primary": "${name_primary_50}",
    "name_secondary": "${name_secondary_50}",
    "mail": "${mail_255}",
    "phone_number": "${phone_15}",
    "policy_number": "${policy_10}",
    "fleet_id": ${FLEET_ID},
    "team_id": ${TEAM_ID}
  }
EOF
)
        call_api "POST" "/user_update" "$user_register_payload"
        check_result $step "user_update (register, max length)" "short_user_id=${SHORT_USER_ID_03}" || failed=$((failed + 1))
    else
        log_info "Skipping user registration (SKIP_REGISTRATION=true)"
    fi

    # Step 2: Update user with max-length name_primary
    step=$((step + 1))
    log_step $step "user_update - Update user (max-length name_primary)"

    local name_primary_50_updated="カキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンアイウエオイロハニ"

    local user_update_payload=$(cat <<EOF
  {
    "short_user_id": ${SHORT_USER_ID_03},
    "name_primary": "${name_primary_50_updated}",
    "name_secondary": "${name_secondary_50}",
    "mail": "${mail_255}",
    "phone_number": "${phone_15}",
    "fleet_id": ${FLEET_ID},
    "team_id": ${TEAM_ID}
  }
EOF
)
    call_api "POST" "/user_update" "$user_update_payload"
    check_result $step "user_update (update, max length)" "short_user_id=${SHORT_USER_ID_03}" || failed=$((failed + 1))

    # Step 3: Register vehicle with max-length fields
    if [ "$SKIP_REGISTRATION" != "true" ]; then
        step=$((step + 1))
        log_step $step "vehicle_update - Register vehicle (max-length fields)"
        log_info "registration length: ${#registration_32}"
        log_info "vin length: ${#vin_30}"
        log_info "tag_mac_address length: ${#tag_mac}"

        local vehicle_register_payload=$(cat <<EOF
  {
    "short_vehicle_id": ${SHORT_VEHICLE_ID_03},
    "registration": "${registration_32}",
    "vin": "${vin_30}",
    "tag_mac_address": "${tag_mac}",
    "fleet_id": ${FLEET_ID}
  }
EOF
)
        call_api "POST" "/vehicle_update" "$vehicle_register_payload"
        check_result $step "vehicle_update (register, max length)" "short_vehicle_id=${SHORT_VEHICLE_ID_03}" || failed=$((failed + 1))
    else
        log_info "Skipping vehicle registration (SKIP_REGISTRATION=true)"
    fi

    # Step 4: Update vehicle with max-length registration
    step=$((step + 1))
    log_step $step "vehicle_update - Update vehicle (max-length registration)"

    local registration_32_updated="大阪ああああああああ|12345|い|1234567890123"

    local vehicle_update_payload=$(cat <<EOF
  {
    "short_vehicle_id": ${SHORT_VEHICLE_ID_03},
    "registration": "${registration_32_updated}",
    "fleet_id": ${FLEET_ID}
  }
EOF
)
    call_api "POST" "/vehicle_update" "$vehicle_update_payload"
    check_result $step "vehicle_update (update, max length)" "short_vehicle_id=${SHORT_VEHICLE_ID_03}" || failed=$((failed + 1))

    # Step 5: Drive update - link with max-length drive_id and 9-digit short_user_id
    step=$((step + 1))
    log_step $step "drive_update - Link drive (max-length drive_id=36 chars, short_user_id=9 digits)"

    local drive_link_payload=$(cat <<EOF
  {
    "drive_id": "${DRIVE_ID_03}",
    "short_user_id": ${SHORT_USER_ID_03}
  }
EOF
)
    call_api "POST" "/drive_update" "$drive_link_payload"
    check_result $step "drive_update (link, max length)" "drive_id=${DRIVE_ID_03}, short_user_id=${SHORT_USER_ID_03}" || failed=$((failed + 1))

    return $failed
}
