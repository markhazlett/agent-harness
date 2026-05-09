#!/usr/bin/env bash
# bin/tests/test-plan-self-review.test.sh — regression test for `bin/test-plan-self-review`.
#
# Asserts the validator exits 0 on a clean plan and exits 1 on a plan
# containing any of the placeholder tokens it scans for.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
VALIDATOR="$REPO_ROOT/bin/test-plan-self-review"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; echo "  $2"; FAIL=$((FAIL+1)); }

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

assert_clean() {
  local label="$1" file="$2"
  local rc=0
  "$VALIDATOR" "$file" >/dev/null 2>&1 || rc=$?
  if [ "$rc" = "0" ]; then
    pass "$label"
  else
    fail "$label" "expected exit 0 on clean plan; got $rc"
  fi
}

assert_dirty() {
  local label="$1" file="$2"
  local rc=0
  "$VALIDATOR" "$file" >/dev/null 2>&1 || rc=$?
  if [ "$rc" = "1" ]; then
    pass "$label"
  else
    fail "$label" "expected exit 1 on placeholder match; got $rc"
  fi
}

# Clean plan
clean="$TMPDIR/clean.md"
cat >"$clean" <<'EOF'
# Some plan

This plan has no placeholders. Every step describes a concrete action.

## Implementation

1. Create file `src/foo.ts` with a function that returns `42`.
2. Add a test that asserts the return value.

## Done criteria

- [ ] `src/foo.ts` exists and exports the function.
- [ ] Tests pass.
EOF
assert_clean "clean plan exits 0" "$clean"

# Dirty plans — one per token
for token in "TBD" "XXX" "???" "implement later" "as needed" "appropriate"; do
  dirty="$TMPDIR/dirty.md"
  cat >"$dirty" <<EOF
# Some plan

## Implementation

1. Do the thing — $token.
EOF
  assert_dirty "placeholder '$token' triggers exit 1" "$dirty"
done

# Missing file — exit code != 0 and != 1 (usage error)
rc=0
"$VALIDATOR" "$TMPDIR/does-not-exist.md" >/dev/null 2>&1 || rc=$?
if [ "$rc" -ge 2 ]; then
  pass "missing file exits with usage error (>= 2)"
else
  fail "missing file exits with usage error (>= 2)" "got $rc"
fi

# No-args — exit code != 0 and != 1 (usage error)
rc=0
"$VALIDATOR" >/dev/null 2>&1 || rc=$?
if [ "$rc" -ge 2 ]; then
  pass "no-args exits with usage error (>= 2)"
else
  fail "no-args exits with usage error (>= 2)" "got $rc"
fi

echo
echo "PASSED: $PASS"
echo "FAILED: $FAIL"
[ "$FAIL" = "0" ]
