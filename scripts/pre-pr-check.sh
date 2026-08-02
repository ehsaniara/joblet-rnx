#!/bin/bash

# Pre-PR verification pipeline for joblet-rnx
#
# Run this before opening a PR (mirrors joblet's scripts/pre-pr-check.sh,
# scoped to the CLI). It validates the working tree end to end:
#
#   1. go vet
#   2. Run unit tests (make test)
#   3. Build the rnx binary (make build)
#   4. Cross-compile every release target (same matrix as CI)
#   5. Verify a joblet service is running on this machine
#   6. Run the full e2e suite against the live local joblet
#
# Unlike joblet's pre-pr, there is no deploy/purge/package step - the server
# lifecycle belongs to the joblet repo. These checks expect joblet to ALREADY
# be running locally with a valid client config (~/.rnx/rnx-config.yml).

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

step() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

fail() {
    echo -e "\n${RED}❌ PRE-PR CHECK FAILED: $1${NC}"
    exit 1
}

step "1/6 go vet"
make -C "$ROOT" vet || fail "go vet"

step "2/6 Unit tests"
make -C "$ROOT" test || fail "unit tests"

step "3/6 Build rnx"
make -C "$ROOT" build || fail "build"

step "4/6 Cross-compile release targets"
# Same matrix as .github/workflows/ci.yml - catches ship-breakers before GitHub
for target in linux/amd64 linux/arm64 darwin/amd64 darwin/arm64 windows/amd64; do
    goos="${target%/*}"
    goarch="${target#*/}"
    echo -e "${BLUE}  building $goos/$goarch...${NC}"
    (cd "$ROOT" && GOOS="$goos" GOARCH="$goarch" CGO_ENABLED=0 \
        go build -o /dev/null ./cmd/rnx) || fail "cross-compile $target"
done
echo -e "${GREEN}✓ All release targets compile${NC}"

step "5/6 Verify local joblet service"
if ! "$ROOT/bin/rnx" job list >/dev/null 2>&1; then
    fail "cannot reach the local joblet service - e2e expects joblet already \
running on this machine with a valid client config (~/.rnx/rnx-config.yml)"
fi
echo -e "${GREEN}✓ Local joblet node reachable${NC}"

step "6/6 Run e2e suite"
SKIP_BUILD=1 "$ROOT/tests/e2e/run_tests.sh" || fail "e2e suite"

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✅ PRE-PR CHECK PASSED${NC}"
echo -e "${GREEN}  vet + tests + cross-builds + e2e verified against the local joblet node${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
