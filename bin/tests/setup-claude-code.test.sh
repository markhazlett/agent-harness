#!/usr/bin/env bash
# Tests setup.sh in Claude Code mode: HARNESS_HOST=claude-code is written
# to the generated config.sh, no conductor.json is created, and
# the wizard exits 0.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SETUP="$REPO_ROOT/setup.sh"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cp "$SETUP" "$TEST_DIR/"
mkdir -p "$TEST_DIR/.claude/hooks"
echo "placeholder" > "$TEST_DIR/.claude/hooks/config.sh"
cd "$TEST_DIR" && git init -q && git add . && git commit -q -m init

# Drive the wizard:
#   1. Host: 2 (Claude Code only)
#   2. App name: TestApp
#   3. Package manager: pnpm
#   4. Source dirs: src
#   5-10. test/typecheck/lint/format/build/dev cmds: Enter (defaults)
#   11. dev port: 3000 (Enter)
#   12. lockfile: Enter
#   13-16. DB schema/generate/push/migrations: all Enter (blank)
#   17. required env: Enter (blank)
#   18. LangGraph opt-in: Enter (defaults to N — disabled)
#
# Note: the "Generate conductor.json?" prompt must NOT appear in Claude Code
# mode, so no answer for it is provided.
printf '2\nTestApp\npnpm\nsrc\n\n\n\n\n\n\n3000\n\n\n\n\n\n\n\n' | bash "$TEST_DIR/setup.sh"

# Test: config.sh contains HARNESS_HOST="claude-code"
grep -q '^HARNESS_HOST="claude-code"$' "$TEST_DIR/.claude/hooks/config.sh" \
  || fail "HARNESS_HOST=claude-code in config" "config: $(cat "$TEST_DIR/.claude/hooks/config.sh")"
pass "HARNESS_HOST=claude-code in config.sh"

# Test: no conductor.json was created
[[ ! -f "$TEST_DIR/conductor.json" ]] \
  || fail "no conductor.json in claude-code mode" "file exists: $(cat "$TEST_DIR/conductor.json")"
pass "no conductor.json in claude-code mode"

# Test: config.sh is still a valid bash file
bash -n "$TEST_DIR/.claude/hooks/config.sh" \
  || fail "generated config is valid bash" "bash -n failed"
pass "generated config is valid bash"

echo ""
echo "ALL PASSED"
