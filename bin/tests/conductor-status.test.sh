#!/usr/bin/env bash
# Tests for bin/conductor-status.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BIN="$REPO_ROOT/bin/conductor-status"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

# ── Setup: fake workspaces root with 3 sibling workspaces ──
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
mkdir -p "$ROOT/repo/alpha/.context" "$ROOT/repo/bravo/.context" "$ROOT/repo/charlie/.context"

cat > "$ROOT/repo/alpha/.context/conductor-status.json" <<'EOF'
{"schema_version":1,"workspace":"alpha","repo":"repo","plan":"docs/plans/2026-w16/sprint-plans/P0.1.md","branch":"feat/a","phase":"implementing","done_criteria":[],"dev_server_port":3000,"pr_url":null,"last_error":null,"started_at":"2026-04-19T10:00:00Z","updated_at":"2026-04-19T10:05:00Z"}
EOF
cat > "$ROOT/repo/bravo/.context/conductor-status.json" <<'EOF'
{"schema_version":1,"workspace":"bravo","repo":"repo","plan":"docs/plans/2026-w16/sprint-plans/P0.2.md","branch":"feat/b","phase":"shipped","done_criteria":[],"dev_server_port":null,"pr_url":"https://github.com/x/y/pull/42","last_error":null,"started_at":"2026-04-19T09:00:00Z","updated_at":"2026-04-19T11:00:00Z"}
EOF

# ── Test: `get` reads a field from the current workspace's status ──
out=$(cd "$ROOT/repo/alpha" && "$BIN" get phase)
[[ "$out" == "implementing" ]] || fail "get phase" "got '$out'"
pass "get phase"

out=$(cd "$ROOT/repo/alpha" && "$BIN" get branch)
[[ "$out" == "feat/a" ]] || fail "get branch" "got '$out'"
pass "get branch"

# ── Test: `get` on missing file returns empty + exits 0 ──
out=$(cd "$ROOT/repo/charlie" && "$BIN" get phase)
[[ -z "$out" ]] || fail "get on missing file returns empty" "got '$out'"
pass "get on missing file returns empty"

# ── Test: `update` creates the status file with initial fields ──
(cd "$ROOT/repo/charlie" && "$BIN" update phase=planning workspace=charlie repo=repo)
[[ -f "$ROOT/repo/charlie/.context/conductor-status.json" ]] || fail "update creates file" "file not found"
phase=$(jq -r .phase "$ROOT/repo/charlie/.context/conductor-status.json")
[[ "$phase" == "planning" ]] || fail "update writes phase" "got '$phase'"
sv=$(jq -r .schema_version "$ROOT/repo/charlie/.context/conductor-status.json")
[[ "$sv" == "1" ]] || fail "update writes schema_version=1" "got '$sv'"
pass "update creates file with fields"

# ── Test: `update` preserves existing fields when updating one ──
(cd "$ROOT/repo/alpha" && "$BIN" update phase=verifying)
phase=$(jq -r .phase "$ROOT/repo/alpha/.context/conductor-status.json")
branch=$(jq -r .branch "$ROOT/repo/alpha/.context/conductor-status.json")
[[ "$phase" == "verifying" ]] || fail "update phase preserved others" "got phase=$phase"
[[ "$branch" == "feat/a" ]] || fail "update preserves branch" "got branch=$branch"
pass "update preserves other fields"

# ── Test: `update` sets updated_at to a fresh ISO-8601 timestamp ──
sleep 1
(cd "$ROOT/repo/alpha" && "$BIN" update phase=verifying)
updated=$(jq -r .updated_at "$ROOT/repo/alpha/.context/conductor-status.json")
[[ "$updated" =~ ^2[0-9]{3}-[0-9]{2}-[0-9]{2}T ]] || fail "update sets ISO-8601 updated_at" "got '$updated'"
pass "update sets updated_at"

# ── Test: `list` honors CONDUCTOR_WORKSPACES_ROOT + prints rollup ──
out=$(CONDUCTOR_WORKSPACES_ROOT="$ROOT" CONDUCTOR_REPO_NAME=repo "$BIN" list)
echo "$out" | grep -q "alpha" || fail "list includes alpha" "output: $out"
echo "$out" | grep -q "bravo" || fail "list includes bravo" "output: $out"
echo "$out" | grep -q "verifying" || fail "list shows phase" "output: $out"
echo "$out" | grep -q "shipped" || fail "list shows shipped" "output: $out"
pass "list prints rollup"

# ── Test: `list --exclude-self` prints self-identity line + excludes self from siblings ──
out=$(cd "$ROOT/repo/alpha" && CONDUCTOR_WORKSPACES_ROOT="$ROOT" CONDUCTOR_REPO_NAME=repo "$BIN" list --exclude-self)
echo "$out" | grep -q "You are: alpha" || fail "list --exclude-self self-identity" "output: $out"
echo "$out" | grep -E "^  - " | grep -q "alpha" && fail "list --exclude-self omits self from siblings" "alpha in siblings rows: $out"
echo "$out" | grep -q "bravo" || fail "list --exclude-self still shows bravo" "output: $out"
pass "list --exclude-self omits current workspace"

# ── Test: `list` tolerates a malformed status file and continues ──
mkdir -p "$ROOT/repo/delta/.context" "$ROOT/repo/echo/.context"
printf 'NOT_VALID_JSON' > "$ROOT/repo/delta/.context/conductor-status.json"
cat > "$ROOT/repo/echo/.context/conductor-status.json" <<'EOF'
{"schema_version":1,"workspace":"echo","repo":"repo","plan":"docs/plans/2026-w16/sprint-plans/P0.9.md","branch":"feat/e","phase":"implementing","done_criteria":[],"dev_server_port":null,"pr_url":null,"last_error":null,"started_at":"2026-04-19T10:00:00Z","updated_at":"2026-04-19T10:05:00Z"}
EOF
out=$(CONDUCTOR_WORKSPACES_ROOT="$ROOT" CONDUCTOR_REPO_NAME=repo "$BIN" list)
echo "$out" | grep -q "delta" || fail "list shows malformed sibling name" "output: $out"
echo "$out" | grep -q "\[malformed status file\]" || fail "list prints [malformed status file] marker" "output: $out"
echo "$out" | grep -q "echo" || fail "list still shows valid sibling after malformed" "output: $out"
pass "list tolerates malformed status file"

echo ""
echo "ALL PASSED"
