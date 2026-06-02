#!/usr/bin/env bash
# bin/tests/test-grade-fixtures.test.sh — regression test for
# `bin/test-grade-fixtures` (the calibration-fixture guard for /grade-codebase).
#
# Asserts:
#   - exit 0 against the current repo state (all 3 fixtures are valid negatives)
#   - exit 1 when a fixture is neutered (here: removing `continue-on-error: true`
#     and `|| true` from the disabled-gate CI config makes the gate "enforced"
#     again, so the fixture stops exhibiting its failure mode).
#
# We test by temporarily editing the fixture, then restoring it.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
VALIDATOR="$REPO_ROOT/bin/test-grade-fixtures"

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

# Test 2: neutering disabled-gate fixture triggers exit 1.
TARGET="$REPO_ROOT/skills/grade-codebase/fixtures/disabled-gate/.github/workflows/ci.yml"
BACKUP=$(mktemp)
cp "$TARGET" "$BACKUP"
trap 'cp "$BACKUP" "$TARGET"; rm -f "$BACKUP"' EXIT

# Strip the two exit-code-swallowing patterns the fixture relies on.
sed -e 's/continue-on-error: true//' \
    -e 's/ || true//' \
    "$BACKUP" > "$TARGET"

if grep -qE '^[[:space:]]*continue-on-error:[[:space:]]*true|^[[:space:]]*-[[:space:]]+run:.*\|\|[[:space:]]*true' "$TARGET"; then
  fail "negative test setup" "swallowing patterns still present after strip"
else
  rc=0
  "$VALIDATOR" >/dev/null 2>&1 || rc=$?
  if [ "$rc" = "1" ]; then
    pass "neutered fixture exits 1"
  else
    fail "neutered fixture exits 1" "got $rc"
  fi
fi

# Restore happens on EXIT trap.

echo
echo "PASSED: $PASS"
echo "FAILED: $FAIL"
[ "$FAIL" = "0" ]
