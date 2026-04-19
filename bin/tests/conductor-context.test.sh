#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOOK="$REPO_ROOT/.claude/hooks/conductor-context.sh"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/repo/accra/.context" "$TMP/repo/bali/.context"

cat > "$TMP/repo/bali/.context/conductor-status.json" <<'EOF'
{"schema_version":1,"workspace":"bali","repo":"repo","plan":"docs/plans/2026-w16/sprint-plans/P0.2-feat-y.md","branch":"feat/y","phase":"verifying","done_criteria":[],"dev_server_port":null,"pr_url":null,"last_error":null,"started_at":"2026-04-19T10:00:00Z","updated_at":"2026-04-19T11:00:00Z"}
EOF

# ── Test: hook prints sibling rollup when inside a workspace dir ──
out=$(cd "$TMP/repo/accra" && CONDUCTOR_WORKSPACES_ROOT="$TMP" CONDUCTOR_REPO_NAME=repo bash "$HOOK")
echo "$out" | grep -q "Conductor workspace state" || fail "header present" "out: $out"
echo "$out" | grep -q "bali" || fail "shows sibling bali" "out: $out"
echo "$out" | grep -q "verifying" || fail "shows sibling phase" "out: $out"
echo "$out" | grep -q "accra" && fail "excludes self" "unexpected self: $out" || true
pass "prints sibling rollup"

# ── Test: hook silently no-ops when outside a Conductor workspace tree ──
out=$(cd "$TMP" && CONDUCTOR_WORKSPACES_ROOT="/nonexistent" bash "$HOOK" 2>&1 || true)
[[ -z "$out" ]] || fail "silent outside workspace" "unexpected output: $out"
pass "silent outside Conductor workspace tree"

echo ""
echo "ALL PASSED"
