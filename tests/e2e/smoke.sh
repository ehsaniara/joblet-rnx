#!/usr/bin/env bash
# Smoke test: exercise rnx against a live joblet node.
# Uses ~/.rnx/rnx-config.yml by default, or RNX_CONFIG / --config via $RNX_ARGS.
set -euo pipefail

RNX="${RNX:-./bin/rnx}"
RNX_ARGS="${RNX_ARGS:-}"
run() { "$RNX" $RNX_ARGS "$@"; }

pass=0; fail=0
check() { if "$@"; then echo "  ✓ $*"; pass=$((pass+1)); else echo "  ✗ $*"; fail=$((fail+1)); fi; }

echo "▶ rnx smoke test against live joblet node"

check run job list >/dev/null

# run a job, capture its id, and assert its logs come back intact
JID="$(run job run sh -c 'for i in $(seq 1 20); do echo line-$i; done' \
	| grep -oE '[0-9a-f]{8}-[0-9a-f-]+' | head -1)"
echo "  job: $JID"
sleep 1
GOT="$(run job log "$JID" | grep -c '^line-' || true)"
if [ "$GOT" = "20" ]; then echo "  ✓ log stream: 20/20 lines"; pass=$((pass+1)); \
	else echo "  ✗ log stream: $GOT/20 lines"; fail=$((fail+1)); fi

check run job status "$JID" >/dev/null
check run runtime list >/dev/null
check run volume list >/dev/null
run job delete "$JID" >/dev/null 2>&1 || true

echo "────────────────────────────"
echo "  passed: $pass  failed: $fail"
[ "$fail" -eq 0 ] && echo "✅ SMOKE PASSED" || { echo "❌ SMOKE FAILED"; exit 1; }
