#!/usr/bin/env bash
# Tests that bin/conductor-status and bin/conductor-dispatch self-gate on
# HARNESS_HOST. When host is "claude-code", both helpers must exit 0 with
# no side effects (no .context/ file writes, no stdout). When host is
# "conductor" or unset, they behave normally.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
STATUS_BIN="$REPO_ROOT/bin/conductor-status"
DISPATCH_BIN="$REPO_ROOT/bin/conductor-dispatch"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ── Fixture: a fake "workspace" with its own .claude/hooks/harness.config.sh ──
# so the helper sources host=claude-code from the expected location.
mkdir -p "$TMP/ws/.claude/hooks" "$TMP/ws/.context"
cat > "$TMP/ws/.claude/hooks/harness.config.sh" <<'EOF'
HARNESS_HOST="claude-code"
EOF

# ── Test: conductor-status update is a silent no-op in Claude Code mode ──
out=$(cd "$TMP/ws" && HARNESS_HOST=claude-code "$STATUS_BIN" update phase=planning 2>&1)
[[ -z "$out" ]] || fail "status update silent in claude-code mode" "got output: $out"
[[ ! -f "$TMP/ws/.context/conductor-status.json" ]] \
  || fail "status update does not write file in claude-code mode" "file exists"
pass "status update is silent no-op in claude-code mode"

# ── Test: conductor-status get is a silent no-op in Claude Code mode ──
out=$(cd "$TMP/ws" && HARNESS_HOST=claude-code "$STATUS_BIN" get phase 2>&1)
[[ -z "$out" ]] || fail "status get silent in claude-code mode" "got output: $out"
pass "status get is silent no-op in claude-code mode"

# ── Test: conductor-status list is a silent no-op in Claude Code mode ──
out=$(cd "$TMP/ws" && HARNESS_HOST=claude-code "$STATUS_BIN" list 2>&1)
[[ -z "$out" ]] || fail "status list silent in claude-code mode" "got output: $out"
pass "status list is silent no-op in claude-code mode"

# ── Test: conductor-status exit code is 0 in Claude Code mode ──
(cd "$TMP/ws" && HARNESS_HOST=claude-code "$STATUS_BIN" update phase=planning) \
  || fail "status update exits 0 in claude-code mode" "non-zero exit"
pass "status update exits 0 in claude-code mode"

# ── Test: HARNESS_HOST=conductor runs status normally ──
mkdir -p "$TMP/ws2/.claude/hooks" "$TMP/ws2/.context"
cat > "$TMP/ws2/.claude/hooks/harness.config.sh" <<'EOF'
HARNESS_HOST="conductor"
EOF
(cd "$TMP/ws2" && HARNESS_HOST=conductor "$STATUS_BIN" update phase=planning workspace=ws2 repo=testrepo)
[[ -f "$TMP/ws2/.context/conductor-status.json" ]] \
  || fail "status runs normally with host=conductor" "no file written"
pass "status runs normally with host=conductor"

# ── Test: unset HARNESS_HOST defaults to conductor behavior (backward compat) ──
mkdir -p "$TMP/ws3/.claude/hooks" "$TMP/ws3/.context"
# harness.config.sh without HARNESS_HOST at all
echo "HARNESS_PKG_MGR=pnpm" > "$TMP/ws3/.claude/hooks/harness.config.sh"
(cd "$TMP/ws3" && unset HARNESS_HOST && "$STATUS_BIN" update phase=planning workspace=ws3 repo=testrepo)
[[ -f "$TMP/ws3/.context/conductor-status.json" ]] \
  || fail "unset HARNESS_HOST defaults to conductor (backward compat)" "no file written"
pass "unset HARNESS_HOST defaults to conductor (backward compat)"

echo ""
echo "ALL PASSED"
