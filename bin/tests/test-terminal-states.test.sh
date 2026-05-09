#!/usr/bin/env bash
# bin/tests/test-terminal-states.test.sh — regression test for
# `bin/test-terminal-states`.
#
# Asserts:
#   - exit 0 against the current repo state (all 4 required skills declare
#     Terminal State).
#   - exit 1 when a required skill's Terminal State section is removed.
#
# We test by temporarily editing a copy of the SKILL.md, then restoring it.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
VALIDATOR="$REPO_ROOT/bin/test-terminal-states"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; echo "  $2"; FAIL=$((FAIL+1)); }

# Test 1: clean repo passes.
cd "$REPO_ROOT"
rc=0
"$VALIDATOR" >/dev/null 2>&1 || rc=$?
if [ "$rc" = "0" ]; then
  pass "clean repo exits 0"
else
  fail "clean repo exits 0" "got $rc"
fi

# Test 2: removing Terminal State from a required skill triggers exit 1.
TARGET="$REPO_ROOT/.claude/skills/tdd/SKILL.md"
BACKUP=$(mktemp)
cp "$TARGET" "$BACKUP"
trap 'cp "$BACKUP" "$TARGET"; rm -f "$BACKUP"' EXIT

# Strip the Terminal State header and the paragraph beneath it (or any
# subsequent content up to the next `## ` header / EOF).
awk '
  /^## Terminal State[[:space:]]*$/ { skip=1; next }
  skip && /^## / { skip=0 }
  !skip { print }
' "$BACKUP" > "$TARGET"

if grep -qiE '^##[[:space:]]+Terminal[[:space:]]+State' "$TARGET"; then
  fail "negative test setup" "Terminal State still present after strip"
else
  rc=0
  "$VALIDATOR" >/dev/null 2>&1 || rc=$?
  if [ "$rc" = "1" ]; then
    pass "missing Terminal State exits 1"
  else
    fail "missing Terminal State exits 1" "got $rc"
  fi
fi

# Restore happens on EXIT trap.

echo
echo "PASSED: $PASS"
echo "FAILED: $FAIL"
[ "$FAIL" = "0" ]
