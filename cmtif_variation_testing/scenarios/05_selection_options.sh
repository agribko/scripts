#!/bin/bash
# Scenario 05: 選択項目のパターンを確認
# Tests that all valid selection options are accepted for vehicle_update.
# eco_class: compact_car, small_car, medium_car, large_car, small_suv, medium_suv,
#            large_suv, full_size_suv, small_truck, medium_truck, large_truck
# fuel_type: ice, diesel, hybrid

scenario_name="05_selection_options"

run_scenario() {
    local step=0
    local failed=0

    local eco_classes=("compact_car" "small_car" "medium_car" "large_car" "small_suv" "medium_suv" "large_suv" "full_size_suv" "small_truck" "medium_truck" "large_truck")
    local fuel_types=("ice" "diesel" "hybrid")

    # Step 1: Register vehicle
    if [ "$SKIP_REGISTRATION" != "true" ]; then
        step=$((step + 1))
        log_step $step "vehicle_update - Register vehicle for selection testing"

        local vehicle_register_payload=$(cat <<EOF
  {
    "short_vehicle_id": ${SHORT_VEHICLE_ID_05},
    "registration": "品川|500|あ|1234",
    "fleet_id": ${FLEET_ID}
  }
EOF
)
        call_api "POST" "/vehicle_update" "$vehicle_register_payload"
        check_result $step "vehicle_update (register)" "short_vehicle_id=${SHORT_VEHICLE_ID_05}" || failed=$((failed + 1))
    else
        log_info "Skipping vehicle registration (SKIP_REGISTRATION=true)"
    fi

    # Steps: Test each eco_class value
    for eco_class in "${eco_classes[@]}"; do
        step=$((step + 1))
        log_step $step "vehicle_update - eco_class=${eco_class}"

        local payload=$(cat <<EOF
  {
    "short_vehicle_id": ${SHORT_VEHICLE_ID_05},
    "eco_class": "${eco_class}"
  }
EOF
)
        call_api "POST" "/vehicle_update" "$payload"
        check_result $step "vehicle_update (eco_class)" "eco_class=${eco_class}" || failed=$((failed + 1))
    done

    # Steps: Test each fuel_type value
    for fuel_type in "${fuel_types[@]}"; do
        step=$((step + 1))
        log_step $step "vehicle_update - fuel_type=${fuel_type}"

        local payload=$(cat <<EOF
  {
    "short_vehicle_id": ${SHORT_VEHICLE_ID_05},
    "fuel_type": "${fuel_type}"
  }
EOF
)
        call_api "POST" "/vehicle_update" "$payload"
        check_result $step "vehicle_update (fuel_type)" "fuel_type=${fuel_type}" || failed=$((failed + 1))
    done

    return $failed
}
