#!/bin/bash
# Scenario 04: 文字制限内での登録を確認
# Tests that APIs accept values with correct character types/formats.
# name_secondary: 全角英数字カナ記号 (full-width alphanumeric + katakana + symbols)
# phone_number: 数字のみ、ハイフン無し (digits only, no hyphens)
# registration: 地名|分類番号|ひらがな|一連指定番号 (pipe-delimited structure)
# tag_mac_address: XX:XX:XX:XX:XX:XX (MAC format)
# drive_id: UUID format (with hyphens)

scenario_name="04_character_format"

run_scenario() {
    local step=0
    local failed=0

    # Character format test values
    # name_secondary: full-width katakana + full-width numbers + full-width symbols
    local name_secondary_format="テスト１２３（カブ）"
    # phone_number: digits only, no hyphens
    local phone_digits_only="09012345678"
    # registration: pipe-delimited structure
    local registration_format="品川|500|あ|1234"
    # tag_mac_address: MAC format
    local tag_mac_format="11:22:33:44:55:66"

    # Step 1: Register user with format-correct values
    if [ "$SKIP_REGISTRATION" != "true" ]; then
        step=$((step + 1))
        log_step $step "user_update - Register user (character format validation)"
        log_info "name_secondary format: full-width katakana + numbers + symbols"
        log_info "phone_number format: digits only, no hyphens"

        local user_register_payload=$(cat <<EOF
[
  {
    "short_user_id": ${SHORT_USER_ID_04},
    "name_primary": "田中花子",
    "name_secondary": "${name_secondary_format}",
    "mail": "format.test@example.com",
    "phone_number": "${phone_digits_only}",
    "fleet_id": ${FLEET_ID},
    "team_id": ${TEAM_ID}
  }
]
EOF
)
        call_api "POST" "/user_update/" "$user_register_payload"
        check_result $step "user_update (register, char format)" "short_user_id=${SHORT_USER_ID_04}" || failed=$((failed + 1))
    else
        log_info "Skipping user registration (SKIP_REGISTRATION=true)"
    fi

    # Step 2: Update user - change name_secondary with different full-width chars
    step=$((step + 1))
    log_step $step "user_update - Update user (different full-width format chars)"

    local name_secondary_updated="テスト＠＃＄％アイウ１２３"

    local user_update_payload=$(cat <<EOF
[
  {
    "short_user_id": ${SHORT_USER_ID_04},
    "name_secondary": "${name_secondary_updated}"
  }
]
EOF
)
    call_api "POST" "/user_update/" "$user_update_payload"
    check_result $step "user_update (update, char format)" "short_user_id=${SHORT_USER_ID_04}" || failed=$((failed + 1))

    # Step 3: Register vehicle with format-correct values
    if [ "$SKIP_REGISTRATION" != "true" ]; then
        step=$((step + 1))
        log_step $step "vehicle_update - Register vehicle (character format validation)"
        log_info "registration format: 地名|分類番号|ひらがな|一連指定番号"
        log_info "tag_mac_address format: XX:XX:XX:XX:XX:XX"

        local vehicle_register_payload=$(cat <<EOF
[
  {
    "short_vehicle_id": ${SHORT_VEHICLE_ID_04},
    "registration": "${registration_format}",
    "tag_mac_address": "${tag_mac_format}",
    "fleet_id": ${FLEET_ID}
  }
]
EOF
)
        call_api "POST" "/vehicle_update/" "$vehicle_register_payload"
        check_result $step "vehicle_update (register, char format)" "short_vehicle_id=${SHORT_VEHICLE_ID_04}" || failed=$((failed + 1))
    else
        log_info "Skipping vehicle registration (SKIP_REGISTRATION=true)"
    fi

    # Step 4: Update vehicle - change registration with valid format
    step=$((step + 1))
    log_step $step "vehicle_update - Update vehicle (different pipe-delimited value)"

    local registration_updated="大阪|300|い|5678"

    local vehicle_update_payload=$(cat <<EOF
[
  {
    "short_vehicle_id": ${SHORT_VEHICLE_ID_04},
    "registration": "${registration_updated}"
  }
]
EOF
)
    call_api "POST" "/vehicle_update/" "$vehicle_update_payload"
    check_result $step "vehicle_update (update, char format)" "short_vehicle_id=${SHORT_VEHICLE_ID_04}" || failed=$((failed + 1))

    # Step 5: Drive update - UUID format drive_id
    step=$((step + 1))
    log_step $step "drive_update - Link drive (UUID format drive_id)"
    log_info "drive_id format: standard UUID with hyphens (8-4-4-4-12)"

    local drive_link_payload=$(cat <<EOF
[
  {
    "drive_id": "${DRIVE_ID_04}",
    "short_user_id": ${SHORT_USER_ID_04}
  }
]
EOF
)
    call_api "POST" "/drive_update/" "$drive_link_payload"
    check_result $step "drive_update (link, UUID format)" "drive_id=${DRIVE_ID_04}, short_user_id=${SHORT_USER_ID_04}" || failed=$((failed + 1))

    return $failed
}
