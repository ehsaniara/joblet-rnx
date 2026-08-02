#!/bin/bash

# Test 08: Monitoring and info commands - monitor, metrics, telematics, nodes, version, help

source "$(dirname "$0")/../lib/test_framework.sh"

MON_JOB_ID=""

test_monitor_status() {
    local output=$(timeout 10 "$RNX_BINARY" monitor status 2>&1)
    if [[ $? -ne 0 || -z "$output" ]]; then
        echo -e "    ${RED}monitor status failed: $output${NC}"
        return 1
    fi
    return 0
}

test_monitor_top() {
    local output=$(timeout 10 "$RNX_BINARY" monitor top --json 2>&1)
    if [[ -z "$output" ]]; then
        echo -e "    ${RED}monitor top produced no output${NC}"
        return 1
    fi
    return 0
}

test_job_metrics_completed() {
    # completed job: metrics shows history and exits (seed job slept past the ~5s sample interval)
    if ! timeout 30 "$RNX_BINARY" job metrics "$MON_JOB_ID" >/dev/null 2>&1; then
        echo -e "    ${RED}job metrics failed or did not exit for a completed job${NC}"
        return 1
    fi
    return 0
}

test_job_telematics_completed() {
    # must exit cleanly for a completed job whether or not eBPF captured events
    local output=$(timeout 30 "$RNX_BINARY" job telematics "$MON_JOB_ID" 2>&1)
    local code=$?
    if [[ $code -eq 124 ]]; then
        echo -e "    ${RED}job telematics did not exit for a completed job${NC}"
        return 1
    fi
    return 0
}

test_short_uuid_status() {
    # Short-form UUIDs (first 8 chars) must resolve
    local short_id="${MON_JOB_ID:0:8}"
    local status_output=$("$RNX_BINARY" job status "$short_id" 2>&1)
    assert_contains "$status_output" "$MON_JOB_ID"
}

test_nodes() {
    local output=$("$RNX_BINARY" nodes 2>&1)
    if [[ $? -ne 0 ]]; then
        echo -e "    ${RED}nodes failed: $output${NC}"
        return 1
    fi
    assert_contains "$output" "default"
}

test_version() {
    local output=$("$RNX_BINARY" --version 2>&1)
    if [[ $? -ne 0 ]]; then
        echo -e "    ${RED}--version failed${NC}"
        return 1
    fi
    assert_contains "$output" "rnx"
}

test_config_help() {
    local output=$("$RNX_BINARY" config-help 2>&1)
    assert_contains "$output" "rnx-config"
}

test_root_help() {
    local output=$("$RNX_BINARY" --help 2>&1)
    assert_contains "$output" "job" && \
        assert_contains "$output" "volume" && \
        assert_contains "$output" "network" && \
        assert_contains "$output" "runtime"
}

# ============================================
# Main
# ============================================

main() {
    test_suite_init "Test 08: Monitoring and Info"

    if ! check_prerequisites; then
        exit 1
    fi

    # Seed a job that runs long enough for a metrics sample (~5s interval)
    MON_JOB_ID=$(run_job sh -c 'sleep 7; echo MONITOR_SEED_DONE')
    wait_for_status "$MON_JOB_ID" "COMPLETED" 40 >/dev/null

    test_section "Node Monitoring"
    run_test "monitor status" test_monitor_status
    run_test "monitor top --json" test_monitor_top

    test_section "Job Telemetry"
    run_test "job metrics exits for completed job" test_job_metrics_completed
    run_test "job telematics exits for completed job" test_job_telematics_completed
    run_test "short-form UUID resolves" test_short_uuid_status

    test_section "Info Commands"
    run_test "nodes lists configured nodes" test_nodes
    run_test "version prints version" test_version
    run_test "config-help shows config docs" test_config_help
    run_test "--help lists all command groups" test_root_help

    cleanup_test_artifacts
    test_suite_summary
}

main "$@"
