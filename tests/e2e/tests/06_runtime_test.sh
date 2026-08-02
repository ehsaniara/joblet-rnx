#!/bin/bash

# Test 06: Runtimes - list, info, and running a job with an installed runtime
#
# Runtime build/test/remove need runtime specs and long builds; those belong to
# joblet's own e2e. Here we verify the CLI's runtime surface against whatever
# the local node already has installed.

source "$(dirname "$0")/../lib/test_framework.sh"

FIRST_RUNTIME=""

test_runtime_list() {
    if ! "$RNX_BINARY" runtime list >/dev/null 2>&1; then
        echo -e "    ${RED}runtime list failed${NC}"
        return 1
    fi
    return 0
}

test_runtime_info() {
    local info=$("$RNX_BINARY" runtime info "$FIRST_RUNTIME" 2>&1)
    if [[ $? -ne 0 || -z "$info" ]]; then
        echo -e "    ${RED}runtime info failed for '$FIRST_RUNTIME'${NC}"
        return 1
    fi
    assert_contains "$info" "$FIRST_RUNTIME"
}

test_job_with_runtime() {
    local job_id=$(run_job --runtime="$FIRST_RUNTIME" echo "RUNTIME_JOB_OK")
    local logs=$(get_job_logs "$job_id")
    assert_contains "$logs" "RUNTIME_JOB_OK"
}

test_runtime_info_unknown_fails() {
    if "$RNX_BINARY" runtime info "no-such-runtime-xyz" >/dev/null 2>&1; then
        echo -e "    ${RED}runtime info succeeded for a nonexistent runtime${NC}"
        return 1
    fi
    return 0
}

# ============================================
# Main
# ============================================

main() {
    test_suite_init "Test 06: Runtimes"

    if ! check_prerequisites; then
        exit 1
    fi

    test_section "Runtime Surface"
    run_test "runtime list" test_runtime_list
    run_test "runtime info rejects unknown runtime" test_runtime_info_unknown_fails

    # Pick the first installed runtime, if any, for the info/run tests
    FIRST_RUNTIME=$("$RNX_BINARY" runtime list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | \
        awk 'NR>1 && $1 ~ /^[a-z]/ {print $1; exit}')

    if [[ -n "$FIRST_RUNTIME" ]]; then
        echo -e "\n${BLUE}Using installed runtime: $FIRST_RUNTIME${NC}"
        run_test "runtime info shows details" test_runtime_info
        run_test "job runs with --runtime" test_job_with_runtime
    else
        skip_test "runtime info shows details" "no runtimes installed on this node"
        skip_test "job runs with --runtime" "no runtimes installed on this node"
    fi

    cleanup_test_artifacts
    test_suite_summary
}

main "$@"
