#!/bin/bash

# Test 04: Networks - create, list, remove, and job attachment

source "$(dirname "$0")/../lib/test_framework.sh"

TEST_NET="test-e2e-net"
TEST_CIDR="10.99.0.0/24"

test_network_create() {
    local output=$("$RNX_BINARY" network create "$TEST_NET" --cidr="$TEST_CIDR" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo -e "    ${RED}network create failed: $output${NC}"
        return 1
    fi
    return 0
}

test_network_in_list() {
    local list_output=$("$RNX_BINARY" network list 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    assert_contains "$list_output" "$TEST_NET"
}

test_job_on_custom_network() {
    local job_id=$(run_job --network="$TEST_NET" sh -c 'ip addr show 2>/dev/null || ifconfig 2>/dev/null || echo NO_IP_TOOL; echo NET_JOB_DONE')
    local logs=$(get_job_logs "$job_id")
    local status=$(check_job_status "$job_id")
    assert_contains "$logs" "NET_JOB_DONE" && assert_equals "$status" "COMPLETED"
}

test_job_with_no_network() {
    local job_id=$(run_job --network=none echo "ISOLATED_JOB_DONE")
    local logs=$(get_job_logs "$job_id")
    assert_contains "$logs" "ISOLATED_JOB_DONE"
}

test_network_remove() {
    if ! "$RNX_BINARY" network remove "$TEST_NET" >/dev/null 2>&1; then
        echo -e "    ${RED}network remove failed${NC}"
        return 1
    fi
    local list_output=$("$RNX_BINARY" network list 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    assert_not_contains "$list_output" "$TEST_NET"
}

# ============================================
# Main
# ============================================

main() {
    test_suite_init "Test 04: Networks"

    if ! check_prerequisites; then
        exit 1
    fi

    # Clean slate in case a previous run left the network behind
    "$RNX_BINARY" network remove "$TEST_NET" >/dev/null 2>&1 || true

    test_section "Network Management"
    run_test "network create" test_network_create
    run_test "network appears in list" test_network_in_list
    run_test "job runs on custom network" test_job_on_custom_network
    run_test "job runs with --network=none" test_job_with_no_network
    run_test "network remove" test_network_remove

    cleanup_test_artifacts
    test_suite_summary
}

main "$@"
