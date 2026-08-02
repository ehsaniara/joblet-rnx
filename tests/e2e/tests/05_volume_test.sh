#!/bin/bash

# Test 05: Volumes - create, list, remove, and cross-job persistence

source "$(dirname "$0")/../lib/test_framework.sh"

TEST_VOL="test-e2e-vol"

test_volume_create() {
    local output=$("$RNX_BINARY" volume create "$TEST_VOL" --size=100MB 2>&1)
    if [[ $? -ne 0 ]]; then
        echo -e "    ${RED}volume create failed: $output${NC}"
        return 1
    fi
    return 0
}

test_volume_in_list() {
    local list_output=$("$RNX_BINARY" volume list 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    assert_contains "$list_output" "$TEST_VOL"
}

test_volume_mounted_in_job() {
    # Volumes mount at /volumes/<name> inside the job
    local job_id=$(run_job --volume="$TEST_VOL" ls /volumes/)
    local logs=$(get_job_logs "$job_id")
    assert_contains "$logs" "$TEST_VOL"
}

test_volume_persistence_across_jobs() {
    # Job 1 writes, job 2 reads - data must survive between jobs
    local writer=$(run_job --volume="$TEST_VOL" sh -c "echo persisted_payload_$$ > /volumes/$TEST_VOL/data.txt")
    local status=$(wait_for_status "$writer" "COMPLETED")
    if [[ "$status" != "COMPLETED" ]]; then
        echo -e "    ${RED}Writer job did not complete (status: $status)${NC}"
        return 1
    fi

    local reader=$(run_job --volume="$TEST_VOL" cat "/volumes/$TEST_VOL/data.txt")
    local logs=$(get_job_logs "$reader")
    assert_contains "$logs" "persisted_payload_$$"
}

test_memory_volume() {
    local vol="test-e2e-memvol"
    "$RNX_BINARY" volume remove "$vol" >/dev/null 2>&1 || true
    if ! "$RNX_BINARY" volume create "$vol" --size=50MB --type=memory >/dev/null 2>&1; then
        echo -e "    ${RED}memory volume create failed${NC}"
        return 1
    fi
    local job_id=$(run_job --volume="$vol" sh -c "echo mem_ok > /volumes/$vol/t.txt && cat /volumes/$vol/t.txt")
    local logs=$(get_job_logs "$job_id")
    "$RNX_BINARY" volume remove "$vol" >/dev/null 2>&1 || true
    assert_contains "$logs" "mem_ok"
}

test_volume_remove() {
    if ! "$RNX_BINARY" volume remove "$TEST_VOL" >/dev/null 2>&1; then
        echo -e "    ${RED}volume remove failed${NC}"
        return 1
    fi
    local list_output=$("$RNX_BINARY" volume list 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    assert_not_contains "$list_output" "$TEST_VOL"
}

# ============================================
# Main
# ============================================

main() {
    test_suite_init "Test 05: Volumes"

    if ! check_prerequisites; then
        exit 1
    fi

    # Clean slate in case a previous run left the volume behind
    "$RNX_BINARY" volume remove "$TEST_VOL" >/dev/null 2>&1 || true

    test_section "Volume Management"
    run_test "volume create (filesystem)" test_volume_create
    run_test "volume appears in list" test_volume_in_list
    run_test "volume mounts at /volumes/<name>" test_volume_mounted_in_job
    run_test "data persists across jobs" test_volume_persistence_across_jobs
    run_test "memory volume works" test_memory_volume
    run_test "volume remove" test_volume_remove

    cleanup_test_artifacts
    test_suite_summary
}

main "$@"
