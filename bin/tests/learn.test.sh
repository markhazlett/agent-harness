#!/usr/bin/env bash
# Tests for bin/learn — the project-learning write helper.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
LEARN_BIN="$REPO_ROOT/bin/learn"

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; echo "  $2"; FAIL=$((FAIL+1)); }

assert_file_exists() {
  [ -f "$1" ] || { fail "$2" "expected file to exist: $1"; return 1; }
}

assert_file_contains() {
  grep -qF -- "$2" "$1" || { fail "$3" "file $1 missing content: $2"; return 1; }
}

assert_file_not_contains() {
  if grep -qF -- "$2" "$1"; then
    fail "$3" "file $1 unexpectedly contains: $2"
    return 1
  fi
}

setup_temp_repo() {
  local repo
  repo=$(mktemp -d)
  (cd "$repo" && git init -q)
  echo "$repo"
}

# ---- tests ----

test_fresh_repo_creates_files() {
  local repo; repo=$(setup_temp_repo)
  cd "$repo"
  cat > body.md <<'EOF'
**Rule:** Always use pnpm.

**Why:** Workspace uses pnpm; npm corrupts the lockfile.

**How to apply:** Substitute pnpm for any npm command.
EOF
  "$LEARN_BIN" write-project \
    --name "Use pnpm" \
    --summary "never fall back to npm" \
    --body-file body.md > /dev/null
  assert_file_exists "docs/learnings/use-pnpm.md" "fresh-repo creates body file" || return
  assert_file_exists "CLAUDE.md" "fresh-repo creates CLAUDE.md" || return
  assert_file_contains "CLAUDE.md" "## Learnings" "## Learnings section present" || return
  assert_file_contains "CLAUDE.md" "[Use pnpm](docs/learnings/use-pnpm.md)" "index entry written" || return
  assert_file_contains "CLAUDE.md" "never fall back to npm" "summary in index" || return
  assert_file_contains "docs/learnings/use-pnpm.md" "name: Use pnpm" "frontmatter name" || return
  assert_file_contains "docs/learnings/use-pnpm.md" "Always use pnpm" "body content" || return
  pass "fresh repo creates files and index"
}

test_fresh_repo_creates_files

# ---- summary ----
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
