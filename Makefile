# rnx - the Joblet CLI. Depends only on the published joblet-proto contract.
.PHONY: all build test vet install e2e smoke pre-pr clean version help

VERSION   := $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
# Full hash: the version display needs >=8 chars, and e2e verifies it against HEAD
GIT_COMMIT := $(shell git rev-parse HEAD 2>/dev/null || echo unknown)
BUILD_DATE := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
VPKG      := github.com/ehsaniara/joblet-rnx/pkg/version

LDFLAGS := -X $(VPKG).Version=$(VERSION) \
	-X $(VPKG).GitCommit=$(GIT_COMMIT) \
	-X $(VPKG).BuildDate=$(BUILD_DATE) \
	-X $(VPKG).Component=rnx

all: build

build: ## Build the rnx binary into bin/rnx
	@echo "Building rnx $(VERSION)..."
	@go build -ldflags="$(LDFLAGS)" -o bin/rnx ./cmd/rnx
	@echo "✅ bin/rnx"

test: ## Run unit tests
	@go test ./...

vet: ## Run go vet
	@go vet ./...

install: build ## Install rnx to /usr/local/bin (sudo)
	@sudo install -m 0755 bin/rnx /usr/local/bin/rnx
	@echo "✅ installed /usr/local/bin/rnx"

e2e: build ## Full e2e suite against a joblet already running on this machine
	@SKIP_BUILD=1 ./tests/e2e/run_tests.sh

smoke: build ## Quick smoke test against a live joblet node (uses ~/.rnx or RNX_CONFIG)
	@./tests/e2e/smoke.sh

pre-pr: ## Full pre-PR check: vet + tests + cross-builds + e2e (needs local joblet running)
	@./scripts/pre-pr-check.sh

clean: ## Remove build artifacts
	@rm -rf bin

version: ## Print the version that would be stamped
	@echo "$(VERSION) ($(GIT_COMMIT))"

help: ## List targets
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
