#!/bin/bash

# Test 01: Job lifecycle - run, list, status, log, stop, cancel, delete, delete-all

source "$(dirname "$0")/../lib/test_framework.sh"

test_job_run_returns_id() {
    local job_id=$(run_job echo "LIFECYCLE_RUN_TEST")
    if [[ "$job_id" =~ ^[0-9a-f]{8}- ]]; then
        echo "$job_id" > /tmp/test_lifecycle_job_id.txt
        return 0
    else
        echo -e "    ${RED}No job UUID returned (got: '$job_id')${NC}"
        return 1
    fi
}

test_job_completes() {
    local job_id=$(cat /tmp/test_lifecycle_job_id.txt)
    local status=$(wait_for_status "$job_id" "COMPLETED")
    assert_equals "$status" "COMPLETED"
}

test_job_log_content() {
    local job_id=$(cat /tmp/test_lifecycle_job_id.txt)
    local logs=$(get_job_logs "$job_id")
    assert_contains "$logs" "LIFECYCLE_RUN_TEST"
}

test_job_log_multiline_intact() {
    local job_id=$(run_job sh -c 'for i in $(seq 1 20); do echo line-$i; done')
    local logs=$(get_job_logs "$job_id")
    local got=$(echo "$logs" | grep -c '^line-' || true)
    assert_equals "$got" "20"
}

test_job_status_fields() {
    local job_id=$(cat /tmp/test_lifecycle_job_id.txt)
    local status_output=$("$RNX_BINARY" job status "$job_id" 2>&1)
    assert_contains "$status_output" "Status:" && \
        assert_contains "$status_output" "$job_id"
}

test_job_list_contains_job() {
    local job_id=$(cat /tmp/test_lifecycle_job_id.txt)
    local list_output=$("$RNX_BINARY" job list 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    assert_contains "$list_output" "$job_id"
}

test_failed_job_status() {
    local job_id=$(run_job sh -c 'exit 3')
    local status=$(wait_for_status "$job_id" "FAILED")
    assert_equals "$status" "FAILED"
}

test_job_stop() {
    local job_id=$(run_job sleep 60)
    wait_for_status "$job_id" "RUNNING" >/dev/null
    if ! "$RNX_BINARY" job stop "$job_id" >/dev/null 2>&1; then
        echo -e "    ${RED}job stop command failed${NC}"
        return 1
    fi
    sleep 2
    local status=$(check_job_status "$job_id")
    if [[ "$status" == "STOPPED" || "$status" == "FAILED" || "$status" == "CANCELED" ]]; then
        return 0
    else
        echo -e "    ${RED}Job not stopped (status: $status)${NC}"
        return 1
    fi
}

test_job_delete() {
    local job_id=$(run_job echo "DELETE_ME")
    wait_for_status "$job_id" "COMPLETED" >/dev/null
    if ! "$RNX_BINARY" job delete "$job_id" >/dev/null 2>&1; then
        echo -e "    ${RED}job delete command failed${NC}"
        return 1
    fi
    local list_output=$("$RNX_BINARY" job list 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    assert_not_contains "$list_output" "$job_id"
}

test_job_delete_all() {
    # Seed a few completed jobs, then wipe everything
    local j1=$(run_job echo "BULK_1")
    local j2=$(run_job echo "BULK_2")
    wait_for_status "$j1" "COMPLETED" >/dev/null
    wait_for_status "$j2" "COMPLETED" >/dev/null

    if ! "$RNX_BINARY" job delete-all >/dev/null 2>&1; then
        echo -e "    ${RED}job delete-all command failed${NC}"
        return 1
    fi
    local remaining=$("$RNX_BINARY" job list 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -cE '^[0-9a-f]{8}-' || true)
    assert_equals "$remaining" "0"
}

# ============================================
# Main
# ============================================

main() {
    test_suite_init "Test 01: Job Lifecycle"

    if ! check_prerequisites; then
        exit 1
    fi

    test_section "Run and Observe"
    run_test "job run returns a job UUID" test_job_run_returns_id
    run_test "job reaches COMPLETED" test_job_completes
    run_test "job log returns output" test_job_log_content
    run_test "job log preserves all lines" test_job_log_multiline_intact
    run_test "job status shows status and ID" test_job_status_fields
    run_test "job list contains the job" test_job_list_contains_job
    run_test "failing command reports FAILED" test_failed_job_status

    test_section "Stop and Delete"
    run_test "job stop terminates a running job" test_job_stop
    run_test "job delete removes a job" test_job_delete
    run_test "job delete-all removes all jobs" test_job_delete_all

    cleanup_test_artifacts
    test_suite_summary
}

main "$@"
