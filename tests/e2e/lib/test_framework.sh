#!/bin/bash

# Test framework for joblet-rnx E2E tests.
# Mirrors joblet's tests/e2e/lib/test_framework.sh, trimmed to the CLI's scope:
# tests run against a joblet service ALREADY RUNNING on this machine.

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Test counters
export TOTAL_TESTS=0
export PASSED_TESTS=0
export FAILED_TESTS=0
export SKIPPED_TESTS=0

# Paths
export RNX_ROOT="${RNX_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
export RNX_BINARY="${RNX_BINARY:-$RNX_ROOT/bin/rnx}"

export JOB_TIMEOUT=15

# ============================================
# Core Test Functions
# ============================================

test_suite_init() {
    local suite_name="$1"
    TOTAL_TESTS=0
    PASSED_TESTS=0
    FAILED_TESTS=0
    SKIPPED_TESTS=0

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $suite_name${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Started: $(date '+%Y-%m-%d %H:%M:%S')${NC}\n"
}

test_section() {
    local section_name="$1"
    echo -e "\n${YELLOW}▶ $section_name${NC}"
    echo -e "${BLUE}$(printf '─%.0s' {1..65})${NC}"
}

run_test() {
    local test_name="$1"
    local test_function="$2"

    ((TOTAL_TESTS++))
    echo -e "\n${BLUE}[$TOTAL_TESTS] Testing: $test_name${NC}"

    if $test_function; then
        ((PASSED_TESTS++))
        echo -e "${GREEN}  ✓ PASS${NC}: $test_name"
        return 0
    else
        ((FAILED_TESTS++))
        echo -e "${RED}  ✗ FAIL${NC}: $test_name"
        return 1
    fi
}

skip_test() {
    local test_name="$1"
    local reason="$2"

    ((TOTAL_TESTS++))
    ((SKIPPED_TESTS++))
    echo -e "\n${BLUE}[$TOTAL_TESTS] Testing: $test_name${NC}"
    echo -e "${YELLOW}  ⊘ SKIP${NC}: $reason"
}

# Assert functions
assert_equals() {
    local actual="$1"
    local expected="$2"

    if [[ "$actual" == "$expected" ]]; then
        return 0
    else
        echo -e "    ${RED}Expected: '$expected', Got: '$actual'${NC}"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"

    if echo "$haystack" | grep -q "$needle"; then
        return 0
    else
        echo -e "    ${RED}Output does not contain: '$needle'${NC}"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"

    if echo "$haystack" | grep -q "$needle"; then
        echo -e "    ${RED}Output should not contain: '$needle'${NC}"
        return 1
    else
        return 0
    fi
}

# ============================================
# Job Execution Helpers
# ============================================

# Run a job and get its ID
run_job() {
    local job_output
    job_output=$("$RNX_BINARY" job run "$@" 2>&1)
    echo "$job_output" | grep "^ID:" | awk '{print $2}'
}

# Check job status (color codes stripped)
check_job_status() {
    local job_id="$1"
    local status_output=$("$RNX_BINARY" job status "$job_id" 2>/dev/null)
    if [[ -z "$status_output" ]]; then
        echo "UNKNOWN"
        return
    fi
    echo "$status_output" | grep "Status:" | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $2}'
}

# Wait until a job reaches a terminal state, then print its logs
get_job_logs() {
    local job_id="$1"
    local max_attempts=15

    for i in $(seq 1 $max_attempts); do
        local status=$(check_job_status "$job_id")
        if [[ "$status" == "COMPLETED" || "$status" == "FAILED" || "$status" == "TIMEOUT" ]]; then
            break
        fi
        if [[ $i -le 5 ]]; then
            sleep 0.5
        elif [[ $i -le 10 ]]; then
            sleep 1
        else
            sleep 2
        fi
    done

    sleep 0.2
    "$RNX_BINARY" job log "$job_id" 2>/dev/null
}

# Wait until a job reaches an expected status; echoes the final status
wait_for_status() {
    local job_id="$1"
    local expected="$2"
    local max_attempts="${3:-20}"

    local status=""
    for i in $(seq 1 $max_attempts); do
        status=$(check_job_status "$job_id")
        if [[ "$status" == "$expected" ]]; then
            echo "$status"
            return 0
        fi
        sleep 0.5
    done
    echo "$status"
    return 1
}

runtime_exists() {
    local runtime="$1"
    "$RNX_BINARY" runtime list 2>/dev/null | grep -q "$runtime"
}

# ============================================
# Test Summary Functions
# ============================================

test_suite_summary() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Test Summary${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    echo -e "Total Tests:    $TOTAL_TESTS"
    echo -e "Passed:         ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed:         ${RED}$FAILED_TESTS${NC}"
    echo -e "Skipped:        ${YELLOW}$SKIPPED_TESTS${NC}"

    if [[ $TOTAL_TESTS -gt 0 ]]; then
        local pass_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        echo -e "Pass Rate:      ${GREEN}${pass_rate}%${NC}"
    fi

    echo -e "\n${BLUE}Completed: $(date '+%Y-%m-%d %H:%M:%S')${NC}"

    if [[ $FAILED_TESTS -eq 0 && $TOTAL_TESTS -gt 0 ]]; then
        echo -e "\n${GREEN}✅ ALL TESTS PASSED!${NC}"
        return 0
    elif [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "\n${RED}❌ SOME TESTS FAILED${NC}"
        return 1
    else
        echo -e "\n${YELLOW}⚠ NO TESTS EXECUTED${NC}"
        return 2
    fi
}

# ============================================
# Utility Functions
# ============================================

# The e2e suite requires a joblet service already running on this machine
check_prerequisites() {
    local prereqs_met=true

    if [[ ! -x "$RNX_BINARY" ]]; then
        echo -e "${RED}Error: rnx binary not found or not executable: $RNX_BINARY${NC}"
        echo -e "${YELLOW}Run 'make build' first.${NC}"
        prereqs_met=false
    elif ! "$RNX_BINARY" job list &>/dev/null; then
        echo -e "${RED}Error: cannot connect to the local joblet service${NC}"
        echo -e "${YELLOW}These tests expect joblet to already be running on this machine"
        echo -e "with a valid client config (~/.rnx/rnx-config.yml or RNX_CONFIG).${NC}"
        prereqs_met=false
    fi

    if [[ "$prereqs_met" == "false" ]]; then
        return 1
    fi

    return 0
}

cleanup_test_artifacts() {
    rm -f /tmp/test_*.txt /tmp/test_*.yaml /tmp/test_*.log 2>/dev/null
}

# Remove all state left behind by previous test runs so suites start clean:
# jobs (stopped/canceled then deleted), test-* networks, test-* volumes, temp files
cleanup_previous_test_state() {
    echo -e "${YELLOW}▶ Cleaning up state from previous test runs${NC}"

    local jobs
    jobs=$("$RNX_BINARY" job list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')

    # Cancel scheduled and stop running jobs so delete-all can remove everything
    echo "$jobs" | awk '$3 == "SCHEDULED" {print $1}' | while read -r id; do
        "$RNX_BINARY" job cancel "$id" >/dev/null 2>&1 || true
    done
    echo "$jobs" | awk '$3 == "RUNNING" || $3 == "INITIALIZING" {print $1}' | while read -r id; do
        "$RNX_BINARY" job stop "$id" >/dev/null 2>&1 || true
    done

    local job_count
    job_count=$(echo "$jobs" | grep -cE '^[0-9a-f]{8}-' || true)
    "$RNX_BINARY" job delete-all >/dev/null 2>&1 || true

    # Remove leftover test networks and volumes (test-* naming convention)
    "$RNX_BINARY" network list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $1}' | grep '^test-' | while read -r net; do
        "$RNX_BINARY" network remove "$net" >/dev/null 2>&1 || true
    done
    "$RNX_BINARY" volume list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $1}' | grep '^test-' | while read -r vol; do
        "$RNX_BINARY" volume remove "$vol" >/dev/null 2>&1 || true
    done

    rm -f /tmp/test_*.txt /tmp/test_*.yaml /tmp/test_*.log 2>/dev/null || true

    echo -e "  ${GREEN}✓ Previous test state cleaned (removed $job_count leftover jobs)${NC}\n"
}

# Export all functions
export -f test_suite_init test_section run_test skip_test
export -f assert_equals assert_contains assert_not_contains
export -f run_job get_job_logs check_job_status wait_for_status runtime_exists
export -f test_suite_summary check_prerequisites cleanup_test_artifacts cleanup_previous_test_state
