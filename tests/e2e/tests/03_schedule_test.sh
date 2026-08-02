#!/bin/bash

# Test 03: Job scheduling - schedule, list, cancel

source "$(dirname "$0")/../lib/test_framework.sh"

test_schedule_relative_time() {
    local job_id=$(run_job --schedule="1hour" echo "FUTURE_JOB")
    if [[ ! "$job_id" =~ ^[0-9a-f]{8}- ]]; then
        echo -e "    ${RED}No job UUID returned${NC}"
        return 1
    fi
    echo "$job_id" > /tmp/test_sched_job_id.txt
    local status=$(check_job_status "$job_id")
    assert_equals "$status" "SCHEDULED"
}

test_scheduled_job_in_list() {
    local job_id=$(cat /tmp/test_sched_job_id.txt)
    local list_output=$("$RNX_BINARY" job list 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    assert_contains "$list_output" "$job_id" && \
        assert_contains "$list_output" "SCHEDULED"
}

test_cancel_scheduled_job() {
    local job_id=$(cat /tmp/test_sched_job_id.txt)
    if ! "$RNX_BINARY" job cancel "$job_id" >/dev/null 2>&1; then
        echo -e "    ${RED}job cancel command failed${NC}"
        return 1
    fi
    sleep 1
    local status=$(check_job_status "$job_id")
    if [[ "$status" == "SCHEDULED" || "$status" == "RUNNING" ]]; then
        echo -e "    ${RED}Job still $status after cancel${NC}"
        return 1
    fi
    return 0
}

test_scheduled_job_executes() {
    # Schedule a few seconds out and verify it actually runs to completion
    local job_id=$(run_job --schedule="5s" echo "SCHEDULED_JOB_EXECUTED")
    local initial=$(check_job_status "$job_id")
    if [[ "$initial" != "SCHEDULED" ]]; then
        echo -e "    ${RED}Job not in SCHEDULED state (got: $initial)${NC}"
        return 1
    fi

    local status=$(wait_for_status "$job_id" "COMPLETED" 40)
    if [[ "$status" != "COMPLETED" ]]; then
        echo -e "    ${RED}Scheduled job did not complete (status: $status)${NC}"
        return 1
    fi
    local logs=$("$RNX_BINARY" job log "$job_id" 2>/dev/null)
    assert_contains "$logs" "SCHEDULED_JOB_EXECUTED"
}

test_schedule_absolute_time() {
    # RFC3339 absolute schedule one hour out
    local when=$(date -d '+1 hour' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -v+1H +%Y-%m-%dT%H:%M:%S)
    local job_id=$(run_job --schedule="$when" echo "ABSOLUTE_SCHEDULE")
    if [[ ! "$job_id" =~ ^[0-9a-f]{8}- ]]; then
        echo -e "    ${RED}No job UUID returned for absolute schedule${NC}"
        return 1
    fi
    local status=$(check_job_status "$job_id")
    "$RNX_BINARY" job cancel "$job_id" >/dev/null 2>&1 || true
    assert_equals "$status" "SCHEDULED"
}

# ============================================
# Main
# ============================================

main() {
    test_suite_init "Test 03: Job Scheduling"

    if ! check_prerequisites; then
        exit 1
    fi

    test_section "Scheduling"
    run_test "relative schedule creates SCHEDULED job" test_schedule_relative_time
    run_test "scheduled job appears in list" test_scheduled_job_in_list
    run_test "cancel removes scheduled job" test_cancel_scheduled_job
    run_test "absolute RFC3339 schedule works" test_schedule_absolute_time
    run_test "scheduled job executes at its time" test_scheduled_job_executes

    cleanup_test_artifacts
    test_suite_summary
}

main "$@"
