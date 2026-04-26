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

_TEST_DIR_LIST=$(mktemp)
cleanup_test_dirs() {
  if [ -f "$_TEST_DIR_LIST" ]; then
    while IFS= read -r d; do
      [ -d "$d" ] && rm -rf "$d"
    done < "$_TEST_DIR_LIST"
    rm -f "$_TEST_DIR_LIST"
  fi
}
trap cleanup_test_dirs EXIT

setup_temp_repo() {
  local repo
  repo=$(mktemp -d)
  echo "$repo" >> "$_TEST_DIR_LIST"
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

test_existing_claude_md_no_learnings_section() {
  local repo; repo=$(setup_temp_repo)
  cd "$repo"
  cat > CLAUDE.md <<'EOF'
# My Project

Some intro text.

## Conventions

- Indent with 2 spaces.
EOF
  cat > body.md <<'EOF'
**Rule:** Always run typecheck before commit.
EOF
  "$LEARN_BIN" write-project \
    --name "Run typecheck before commit" \
    --summary "catch type errors before push" \
    --body-file body.md > /dev/null
  # Existing content preserved
  assert_file_contains "CLAUDE.md" "# My Project" "preserves heading" || return
  assert_file_contains "CLAUDE.md" "## Conventions" "preserves existing section" || return
  assert_file_contains "CLAUDE.md" "Indent with 2 spaces" "preserves existing content" || return
  # New section appended
  assert_file_contains "CLAUDE.md" "## Learnings" "appends Learnings section" || return
  assert_file_contains "CLAUDE.md" "[Run typecheck before commit]" "appends index entry" || return
  # Section is at the bottom
  local conv_line learn_line
  conv_line=$(grep -n '^## Conventions$' CLAUDE.md | cut -d: -f1)
  learn_line=$(grep -n '^## Learnings$' CLAUDE.md | cut -d: -f1)
  if [ "$learn_line" -le "$conv_line" ]; then
    fail "Learnings appears at bottom" "## Learnings line=$learn_line should be > ## Conventions line=$conv_line"
    return
  fi
  pass "preserves existing CLAUDE.md and appends Learnings section"
}

test_existing_claude_md_no_learnings_section

test_update_existing_entry() {
  local repo; repo=$(setup_temp_repo)
  cd "$repo"
  cat > body1.md <<'EOF'
**Rule:** Always use pnpm.

**Why:** Initial reason.
EOF
  "$LEARN_BIN" write-project \
    --name "Use pnpm" --summary "never npm" \
    --body-file body1.md > /dev/null

  local original_created
  original_created=$(grep '^created:' docs/learnings/use-pnpm.md)

  cat > body2.md <<'EOF'
**Rule:** Always use pnpm.

**Why:** Updated reason — pnpm workspaces are required.
EOF
  "$LEARN_BIN" write-project \
    --name "Use pnpm" --summary "pnpm workspaces required" \
    --body-file body2.md > /dev/null

  # Same file (no -2 suffix)
  assert_file_exists "docs/learnings/use-pnpm.md" "file kept" || return
  if [ -f "docs/learnings/use-pnpm-2.md" ]; then
    fail "no suffixed file for same-name update" "docs/learnings/use-pnpm-2.md should not exist"
    return
  fi
  # Body replaced (not merged blindly)
  assert_file_contains "docs/learnings/use-pnpm.md" "Updated reason" "new body present" || return
  assert_file_not_contains "docs/learnings/use-pnpm.md" "Initial reason" "old body replaced" || return
  # 'created' preserved
  if ! grep -qF "$original_created" docs/learnings/use-pnpm.md; then
    fail "created date preserved" "expected '$original_created' to still be present"
    return
  fi
  # Index entry updated, not duplicated
  local count
  count=$(grep -cF "[Use pnpm]" CLAUDE.md)
  if [ "$count" != "1" ]; then
    fail "single index entry" "expected 1 occurrence, got $count"
    return
  fi
  assert_file_contains "CLAUDE.md" "pnpm workspaces required" "index summary updated" || return
  assert_file_not_contains "CLAUDE.md" "never npm" "old index summary replaced" || return
  pass "update existing entry preserves created, replaces body and index"
}

test_update_existing_entry

test_index_update_does_not_clobber_prose() {
  local repo; repo=$(setup_temp_repo)
  cd "$repo"
  cat > body1.md <<'EOF'
**Rule:** Always X.

**Why:** Initial.
EOF
  "$LEARN_BIN" write-project \
    --name "Always X" --summary "v1" \
    --body-file body1.md > /dev/null

  # Manually add prose under ## Learnings that mentions the path in parens.
  # This simulates a human-edited CLAUDE.md.
  cat >> CLAUDE.md <<'EOF'
  - See also notes referencing (docs/learnings/always-x.md) for related context.
EOF

  cat > body2.md <<'EOF'
**Rule:** Always X.

**Why:** Updated.
EOF
  "$LEARN_BIN" write-project \
    --name "Always X" --summary "v2" \
    --body-file body2.md > /dev/null

  # The prose line should still exist verbatim.
  assert_file_contains "CLAUDE.md" "See also notes referencing (docs/learnings/always-x.md) for related context." "prose preserved" || return
  # The actual index line is updated to v2.
  assert_file_contains "CLAUDE.md" "[Always X](docs/learnings/always-x.md) — v2" "index entry updated" || return
  # Old summary gone.
  assert_file_not_contains "CLAUDE.md" "— v1" "old index summary replaced" || return
  # Exactly one canonical index line for this learning.
  local count
  count=$(grep -cE '^- \[Always X\]' CLAUDE.md)
  if [ "$count" != "1" ]; then
    fail "single canonical index entry" "expected 1, got $count"
    return
  fi
  pass "index update does not clobber prose lines that mention the path"
}

test_index_update_does_not_clobber_prose

# ---- summary ----
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
