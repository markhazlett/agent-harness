#!/usr/bin/env bash
# Tests that setup.sh generates a valid conductor.json
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SETUP="$REPO_ROOT/setup.sh"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

# ── Setup: create a temp repo mirroring what setup.sh expects ──
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cp "$SETUP" "$TEST_DIR/"
mkdir -p "$TEST_DIR/.claude/hooks"
echo "placeholder" > "$TEST_DIR/.claude/hooks/harness.config.sh"
touch "$TEST_DIR/.env.example"
cd "$TEST_DIR" && git init -q && git add . && git commit -q -m init

# Drive the wizard with canned answers:
#   App name: TestApp
#   Package manager: pnpm
#   Source dirs: src
#   test/typecheck/lint/format/build/dev cmds: all Enter (defaults)
#   dev port: 3000 (Enter)
#   lockfile: Enter
#   DB schema/generate/push/migrations: all Enter (blank)
#   required env: Enter (blank)
#   Generate conductor.json: Y
printf 'TestApp\npnpm\nsrc\n\n\n\n\n\n\n3000\n\n\n\n\n\n\nY\n' | bash "$TEST_DIR/setup.sh"

# ── Test: conductor.json was created ──
[[ -f "$TEST_DIR/conductor.json" ]] || fail "conductor.json created" "file not found"
pass "conductor.json created"

# ── Test: conductor.json is valid JSON ──
jq . "$TEST_DIR/conductor.json" >/dev/null 2>&1 || fail "conductor.json is valid JSON" "jq parse failed"
pass "conductor.json is valid JSON"

# ── Test: scripts.setup includes pnpm install ──
setup_val=$(jq -r '.scripts.setup' "$TEST_DIR/conductor.json")
echo "$setup_val" | grep -q "pnpm install" || fail "setup includes pnpm install" "got: $setup_val"
pass "setup script includes pnpm install"

# ── Test: scripts.setup includes .env copy (since .env.example exists) ──
echo "$setup_val" | grep -q "cp .env.example .env" || fail "setup includes .env copy" "got: $setup_val"
pass "setup script includes .env copy"

# ── Test: scripts.run is the dev command ──
run_val=$(jq -r '.scripts.run' "$TEST_DIR/conductor.json")
echo "$run_val" | grep -q "pnpm run dev" || fail "run is dev cmd" "got: $run_val"
pass "run script is pnpm run dev"

# ── Test: scripts.archive is present and non-empty ──
archive_val=$(jq -r '.scripts.archive' "$TEST_DIR/conductor.json")
[[ -n "$archive_val" ]] || fail "archive script is non-empty" "got empty"
pass "archive script is non-empty"

# ── Test: archive uses portable lsof/kill pattern (not xargs -r) ──
echo "$archive_val" | grep -q "lsof -ti:3000" || fail "archive contains lsof -ti:3000" "got: $archive_val"
pass "archive contains lsof -ti:3000"
echo "$archive_val" | grep -qv "xargs -r" || fail "archive does not contain xargs -r" "got: $archive_val"
pass "archive does not contain xargs -r"

echo ""
echo "ALL PASSED"
