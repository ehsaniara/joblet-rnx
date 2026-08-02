#!/bin/bash

# Unified test runner for joblet-rnx E2E tests.
# Mirrors joblet's tests/e2e/run_tests.sh, but with no build-and-deploy step:
# these tests expect a joblet service ALREADY RUNNING on the local machine.

# No set -e: test failures must not terminate the runner

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test_framework.sh"

TESTS_TO_RUN=()
VERBOSE=false

# ============================================
# Build
# ============================================

build_rnx() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Build${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    echo -e "${BLUE}Building rnx CLI...${NC}"
    if ! make -C "$RNX_ROOT" build >/dev/null 2>&1; then
        echo -e "${RED}Build failed!${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Build successful${NC}\n"
}

# Prove the binary under test is the working tree's build, not a stale or
# foreign rnx: its embedded commit must match HEAD and no source may be newer.
verify_fresh_build() {
    echo -e "${BLUE}Binary under test: $RNX_BINARY${NC}"
    echo -e "${BLUE}  $("$RNX_BINARY" --version 2>/dev/null || echo 'no version stamp')${NC}"

    local head_commit
    head_commit=$(git -C "$RNX_ROOT" rev-parse HEAD 2>/dev/null)
    if [[ -n "$head_commit" ]]; then
        local bin_commit
        bin_commit=$("$RNX_BINARY" --json --version 2>/dev/null | grep -m1 '"git_commit"' | grep -oE '[0-9a-f]{40}')
        if [[ -n "$bin_commit" && "$bin_commit" != "$head_commit" ]]; then
            echo -e "${RED}Binary was built from commit ${bin_commit:0:8}, but HEAD is ${head_commit:0:8}.${NC}"
            echo -e "${RED}Refusing to test a stale build - run 'make build'.${NC}"
            exit 1
        fi
    fi

    local newer
    newer=$(find "$RNX_ROOT" -name '*.go' -newer "$RNX_BINARY" 2>/dev/null | head -1)
    if [[ -n "$newer" ]]; then
        echo -e "${RED}Source changed after the binary was built (e.g. $newer).${NC}"
        echo -e "${RED}Refusing to test a stale build - run 'make build'.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Binary matches the working tree${NC}\n"
}

# ============================================
# Test Discovery and Execution
# ============================================

discover_tests() {
    if [[ -d "$SCRIPT_DIR/tests" ]]; then
        for test_file in "$SCRIPT_DIR/tests"/*.sh; do
            if [[ -f "$test_file" ]]; then
                TESTS_TO_RUN+=("$test_file")
            fi
        done
    fi

    IFS=$'\n' TESTS_TO_RUN=($(sort <<<"${TESTS_TO_RUN[*]}"))
    unset IFS
}

run_single_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Running: $test_name${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [[ -x "$test_file" ]]; then
        if "$test_file"; then
            echo -e "${GREEN}✓ $test_name completed successfully${NC}"
            return 0
        else
            local exit_code=$?
            echo -e "${RED}✗ $test_name failed (exit code: $exit_code)${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⊘ $test_name is not executable, skipping${NC}"
        return 0
    fi
}

run_all_tests() {
    local total_tests=${#TESTS_TO_RUN[@]}
    local passed_suites=0
    local failed_suites=0

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  joblet-rnx E2E Test Suite${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Found $total_tests test suites to run${NC}\n"

    for test_file in "${TESTS_TO_RUN[@]}"; do
        if run_single_test "$test_file"; then
            ((passed_suites++))
        else
            ((failed_suites++))
        fi
    done

    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Overall Test Summary${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    echo -e "Test Suites Run:    $total_tests"
    echo -e "Suites Passed:      ${GREEN}$passed_suites${NC}"
    echo -e "Suites Failed:      ${RED}$failed_suites${NC}"

    if [[ $failed_suites -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 ALL TEST SUITES PASSED!${NC}"
        echo -e "${GREEN}rnx is working correctly against the local joblet node.${NC}"
        return 0
    else
        echo -e "\n${RED}❌ SOME TEST SUITES FAILED${NC}"
        echo -e "${RED}Please review the failures above.${NC}"
        return 1
    fi
}

# ============================================
# Usage and Help
# ============================================

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [TEST_PATTERN]

Run joblet-rnx E2E tests against a joblet service already running on this
machine. Every rnx command surface is exercised against the live node.

Prerequisites:
  - joblet service running locally (systemctl status joblet)
  - client config at ~/.rnx/rnx-config.yml (or RNX_CONFIG set)

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -t, --test PATTERN  Run only tests matching pattern
    -x, --exclude PAT   Skip tests matching pattern (comma-separated, e.g. "06_")
    -l, --list          List available tests without running

EXAMPLES:
    $0                  # Build rnx + run all suites against local joblet
    $0 -t lifecycle     # Run only the job lifecycle suite
    $0 --list           # List all available tests

ENVIRONMENT VARIABLES:
    RNX_ROOT            Path to joblet-rnx root directory
    RNX_BINARY          Path to rnx binary (default: \$RNX_ROOT/bin/rnx)
    SKIP_BUILD=1        Skip rebuilding rnx before the run

EOF
}

list_tests() {
    echo -e "${CYAN}Available Test Suites:${NC}\n"

    for test_file in "${TESTS_TO_RUN[@]}"; do
        local test_name=$(basename "$test_file" .sh)
        local test_desc="No description"

        if [[ -f "$test_file" ]]; then
            local desc_line=$(grep "^# Test [0-9]*:" "$test_file" | head -1)
            if [[ -n "$desc_line" ]]; then
                test_desc=$(echo "$desc_line" | sed 's/^# Test [0-9]*: *//')
            fi
        fi

        printf "  ${BLUE}%-25s${NC} %s\n" "$test_name" "$test_desc"
    done
}

# ============================================
# Main Execution
# ============================================

main() {
    local test_pattern=""
    local exclude_patterns=""
    local list_only=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -t|--test)
                test_pattern="$2"
                shift 2
                ;;
            -x|--exclude)
                exclude_patterns="$2"
                shift 2
                ;;
            -l|--list)
                list_only=true
                shift
                ;;
            *)
                test_pattern="$1"
                shift
                ;;
        esac
    done

    discover_tests

    if [[ -n "$test_pattern" ]]; then
        local filtered=()
        for test in "${TESTS_TO_RUN[@]}"; do
            if [[ "$(basename "$test")" == *"$test_pattern"* ]]; then
                filtered+=("$test")
            fi
        done
        TESTS_TO_RUN=("${filtered[@]}")
    fi

    if [[ -n "$exclude_patterns" ]]; then
        local kept=()
        for test in "${TESTS_TO_RUN[@]}"; do
            local excluded=false
            IFS=',' read -ra patterns <<< "$exclude_patterns"
            for pat in "${patterns[@]}"; do
                if [[ "$(basename "$test")" == *"$pat"* ]]; then
                    excluded=true
                    echo -e "${YELLOW}⊘ Excluding: $(basename "$test" .sh) (matched '$pat')${NC}"
                    break
                fi
            done
            [[ "$excluded" == "false" ]] && kept+=("$test")
        done
        TESTS_TO_RUN=("${kept[@]}")
    fi

    if [[ "$list_only" == "true" ]]; then
        list_tests
        exit 0
    fi

    if [[ ${#TESTS_TO_RUN[@]} -eq 0 ]]; then
        echo -e "${RED}No tests found matching pattern: $test_pattern${NC}"
        exit 1
    fi

    if [[ "${SKIP_BUILD:-}" != "1" ]]; then
        build_rnx
    else
        echo -e "${YELLOW}⊘ Skipping build (SKIP_BUILD=1)${NC}\n"
    fi

    # Whether we just built or the build was skipped, prove we test THIS tree's rnx
    verify_fresh_build

    # These tests assume joblet is already running locally - verify before starting
    if ! check_prerequisites; then
        exit 1
    fi

    # Start from a clean slate: remove jobs/networks/volumes left by prior runs
    cleanup_previous_test_state

    run_all_tests
    exit $?
}

chmod +x "$SCRIPT_DIR/lib/test_framework.sh" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/tests"/*.sh 2>/dev/null || true

main "$@"
