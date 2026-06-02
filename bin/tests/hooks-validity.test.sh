#!/usr/bin/env bash
# Validates that every hook in the harness is parseable / typechecks:
#   - hooks/shell/*.sh        — bash -n syntax check
#   - hooks/pi/*/index.ts     — TypeScript typecheck (tsc --noEmit)
#   - hooks/pi/_lib/*.ts      — same
#
# This catches regressions where someone edits a hook but breaks its
# syntax or type contract.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$REPO_ROOT"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

# ─── Shell hook syntax ───────────────────────────────────────────────
SHELL_HOOK_COUNT=0
for f in hooks/shell/*.sh; do
  [ -f "$f" ] || continue
  SHELL_HOOK_COUNT=$((SHELL_HOOK_COUNT + 1))
  bash -n "$f" 2>"$REPO_ROOT/.bash-n-err.tmp" \
    || fail "shell: $f syntax" "$(cat "$REPO_ROOT/.bash-n-err.tmp")"
done
rm -f "$REPO_ROOT/.bash-n-err.tmp"
pass "shell: all $SHELL_HOOK_COUNT hooks parse with bash -n"

# Also check setup.sh + bin/harness-update if present.
bash -n setup.sh || fail "setup.sh syntax" "bash -n failed"
pass "shell: setup.sh syntax OK"

if [ -f bin/harness-update ]; then
  bash -n bin/harness-update || fail "bin/harness-update syntax" "bash -n failed"
  pass "shell: bin/harness-update syntax OK"
fi

# ─── Pi TypeScript typecheck ─────────────────────────────────────────
if [ -d hooks/pi/node_modules ]; then
  (cd hooks/pi && npx --no-install tsc --noEmit) >"$REPO_ROOT/.tsc-err.tmp" 2>&1 \
    || fail "pi: tsc --noEmit" "$(cat "$REPO_ROOT/.tsc-err.tmp" | tail -20)"
  rm -f "$REPO_ROOT/.tsc-err.tmp"
  pass "pi: hooks/pi/ typechecks with tsc --noEmit"
else
  echo "SKIP: pi/typecheck — hooks/pi/node_modules not installed (run 'cd hooks/pi && pnpm install')"
fi

# ─── Pi Vitest unit tests ────────────────────────────────────────────
if [ -d hooks/pi/node_modules ]; then
  (cd hooks/pi && npm test --silent) >"$REPO_ROOT/.vitest-err.tmp" 2>&1 \
    || fail "pi: npm test" "$(cat "$REPO_ROOT/.vitest-err.tmp" | tail -20)"
  TEST_COUNT=$(grep -oE "Tests +[0-9]+ passed" "$REPO_ROOT/.vitest-err.tmp" | head -1 | grep -oE "[0-9]+")
  rm -f "$REPO_ROOT/.vitest-err.tmp"
  pass "pi: ${TEST_COUNT:-?} unit tests pass"
else
  echo "SKIP: pi/vitest — hooks/pi/node_modules not installed"
fi

echo ""
echo "HOOKS VALIDITY PASSED"
