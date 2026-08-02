#!/bin/bash

# Test 07: --json flag - machine-readable output for key commands

source "$(dirname "$0")/../lib/test_framework.sh"

# Validate a string parses as JSON (jq if available, structural check otherwise)
validate_json() {
    local output="$1"
    if command -v jq >/dev/null 2>&1; then
        echo "$output" | jq empty >/dev/null 2>&1
        return $?
    fi
    if [[ "$output" =~ ^[[:space:]]*\{ && "$output" =~ \}[[:space:]]*$ ]]; then
        return 0
    elif [[ "$output" =~ ^[[:space:]]*\[ && "$output" =~ \][[:space:]]*$ ]]; then
        return 0
    fi
    return 1
}

json_has_fields() {
    local output="$1"
    shift
    for field in "$@"; do
        if ! echo "$output" | grep -q "\"$field\""; then
            echo -e "    ${RED}Missing JSON field: $field${NC}"
            return 1
        fi
    done
    return 0
}

JSON_JOB_ID=""

test_json_job_list() {
    local output=$(timeout 10 "$RNX_BINARY" --json job list 2>&1)
    validate_json "$output" || { echo -e "    ${RED}Not valid JSON: $output${NC}"; return 1; }
}

test_json_job_status() {
    local output=$(timeout 10 "$RNX_BINARY" --json job status "$JSON_JOB_ID" 2>&1)
    validate_json "$output" || { echo -e "    ${RED}Not valid JSON: $output${NC}"; return 1; }
    json_has_fields "$output" "status"
}

test_json_volume_list() {
    local output=$(timeout 10 "$RNX_BINARY" --json volume list 2>&1)
    validate_json "$output" || { echo -e "    ${RED}Not valid JSON: $output${NC}"; return 1; }
}

test_json_network_list() {
    local output=$(timeout 10 "$RNX_BINARY" --json network list 2>&1)
    validate_json "$output" || { echo -e "    ${RED}Not valid JSON: $output${NC}"; return 1; }
}

test_json_runtime_list() {
    local output=$(timeout 10 "$RNX_BINARY" --json runtime list 2>&1)
    validate_json "$output" || { echo -e "    ${RED}Not valid JSON: $output${NC}"; return 1; }
}

test_json_monitor_status() {
    local output=$(timeout 10 "$RNX_BINARY" --json monitor status 2>&1)
    validate_json "$output" || { echo -e "    ${RED}Not valid JSON: $output${NC}"; return 1; }
}

# ============================================
# Main
# ============================================

main() {
    test_suite_init "Test 07: JSON Output"

    if ! check_prerequisites; then
        exit 1
    fi

    # Seed one completed job so status has something to report
    JSON_JOB_ID=$(run_job echo "JSON_SEED_JOB")
    wait_for_status "$JSON_JOB_ID" "COMPLETED" >/dev/null

    test_section "Machine-Readable Output"
    run_test "--json job list" test_json_job_list
    run_test "--json job status" test_json_job_status
    run_test "--json volume list" test_json_volume_list
    run_test "--json network list" test_json_network_list
    run_test "--json runtime list" test_json_runtime_list
    run_test "--json monitor status" test_json_monitor_status

    cleanup_test_artifacts
    test_suite_summary
}

main "$@"
