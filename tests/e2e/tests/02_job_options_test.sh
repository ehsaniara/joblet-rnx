#!/bin/bash

# Test 02: Job options - env vars, secret env, resource limits, upload, timeout

source "$(dirname "$0")/../lib/test_framework.sh"

test_env_variable() {
    local job_id=$(run_job --env=E2E_MARKER=env_value_123 sh -c 'echo "GOT:$E2E_MARKER"')
    local logs=$(get_job_logs "$job_id")
    assert_contains "$logs" "GOT:env_value_123"
}

test_env_short_flag() {
    local job_id=$(run_job -e E2E_SHORT=short_val sh -c 'echo "SHORT:$E2E_SHORT"')
    local logs=$(get_job_logs "$job_id")
    assert_contains "$logs" "SHORT:short_val"
}

test_multiple_env_variables() {
    local job_id=$(run_job --env=VAR_A=aaa --env=VAR_B=bbb sh -c 'echo "$VAR_A:$VAR_B"')
    local logs=$(get_job_logs "$job_id")
    assert_contains "$logs" "aaa:bbb"
}

test_secret_env_reaches_job() {
    # The secret VALUE must reach the job's environment
    local job_id=$(run_job --secret-env=E2E_SECRET=hidden_val_456 sh -c 'echo "SEC:$E2E_SECRET"')
    local logs=$(get_job_logs "$job_id")
    assert_contains "$logs" "SEC:hidden_val_456"
}

test_secret_env_hidden_in_status() {
    # The secret VALUE must not leak through job status output
    local job_id=$(run_job --secret-env=E2E_LEAK=leak_probe_789 sh -c 'true')
    wait_for_status "$job_id" "COMPLETED" >/dev/null
    local status_output=$("$RNX_BINARY" job status "$job_id" 2>&1)
    assert_not_contains "$status_output" "leak_probe_789"
}

test_resource_limit_flags() {
    local job_id=$(run_job --max-cpu=50 --max-memory=128 echo "LIMITS_OK")
    local logs=$(get_job_logs "$job_id")
    local status=$(check_job_status "$job_id")
    assert_contains "$logs" "LIMITS_OK" && assert_equals "$status" "COMPLETED"
}

test_memory_limit_reported_in_status() {
    local job_id=$(run_job --max-memory=128 sleep 1)
    wait_for_status "$job_id" "COMPLETED" >/dev/null
    local status_output=$("$RNX_BINARY" job status "$job_id" 2>&1)
    assert_contains "$status_output" "128"
}

test_file_upload() {
    echo "upload_payload_$$" > /tmp/test_upload_file.txt
    local job_id=$(run_job --upload=/tmp/test_upload_file.txt cat test_upload_file.txt)
    local logs=$(get_job_logs "$job_id")
    rm -f /tmp/test_upload_file.txt
    assert_contains "$logs" "upload_payload_$$"
}

test_directory_upload() {
    # Uploading a directory places its CONTENTS at the workspace root
    local dir=/tmp/test_upload_dir
    mkdir -p "$dir/sub"
    echo "dir_payload_$$" > "$dir/sub/inner.txt"
    local job_id=$(run_job --upload="$dir" cat sub/inner.txt)
    local logs=$(get_job_logs "$job_id")
    rm -rf "$dir"
    assert_contains "$logs" "dir_payload_$$"
}

test_job_timeout() {
    # TIMEOUT + exit 124 is the contract; logs aren't asserted (TERM->KILL grace window)
    local job_id=$(run_job --timeout=2s sleep 30)
    local status=""
    for i in $(seq 1 20); do
        status=$(check_job_status "$job_id")
        if [[ "$status" != "RUNNING" && "$status" != "INITIALIZING" && "$status" != "UNKNOWN" ]]; then
            break
        fi
        sleep 1
    done
    if [[ "$status" != "TIMEOUT" ]]; then
        echo -e "    ${RED}Expected TIMEOUT status, got: $status${NC}"
        return 1
    fi
    local status_output=$("$RNX_BINARY" job status "$job_id" 2>&1)
    assert_contains "$status_output" "124"
}

# ============================================
# Main
# ============================================

main() {
    test_suite_init "Test 02: Job Options"

    if ! check_prerequisites; then
        exit 1
    fi

    test_section "Environment Variables"
    run_test "--env reaches the job" test_env_variable
    run_test "-e short form works" test_env_short_flag
    run_test "multiple --env flags work" test_multiple_env_variables
    run_test "--secret-env reaches the job" test_secret_env_reaches_job
    run_test "--secret-env value hidden in status" test_secret_env_hidden_in_status

    test_section "Resource Limits"
    run_test "--max-cpu/--max-memory accepted" test_resource_limit_flags
    run_test "memory limit visible in status" test_memory_limit_reported_in_status

    test_section "Uploads and Timeout"
    run_test "--upload file lands in workspace" test_file_upload
    run_test "--upload directory lands in workspace" test_directory_upload
    run_test "--timeout terminates a long job" test_job_timeout

    cleanup_test_artifacts
    test_suite_summary
}

main "$@"
