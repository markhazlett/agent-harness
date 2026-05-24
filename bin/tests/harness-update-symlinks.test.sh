#!/usr/bin/env bash
# Regression test for the symlink-walker bug in bin/harness-update.
#
# Upstream tracks .claude/skills, .claude/agents, .claude/commands as git
# symlinks pointing at the canonical top-level skills/, agents/, prompts/
# trees. Earlier versions of is_managed() only globbed the .claude/* form,
# so git ls-files emitted three bare symlink entries that matched no glob
# and every upstream-managed skill/agent/command file was silently skipped.
# Local installs that already had those skills got bucketed as local_only,
# and every harness-update run was a no-op for the bulk of the tree.
#
# This test stages a minimal upstream with the same symlink layout, runs
# `bin/harness-update --plan` against a fresh target, and asserts that
# files under skills/, agents/, and prompts/ make it into actions.install.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
UPDATE="$REPO_ROOT/bin/harness-update"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

WORK=$(mktemp -d -t harness-symlinks.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

# ─── Stage upstream with the .claude/* → top-level symlink layout ──────────
UPSTREAM="$WORK/source"
mkdir -p "$UPSTREAM/.claude/hooks" \
         "$UPSTREAM/skills/foo" \
         "$UPSTREAM/agents" \
         "$UPSTREAM/prompts" \
         "$UPSTREAM/bin"
ln -s ../skills   "$UPSTREAM/.claude/skills"
ln -s ../agents   "$UPSTREAM/.claude/agents"
ln -s ../prompts  "$UPSTREAM/.claude/commands"

cat > "$UPSTREAM/skills/foo/SKILL.md" <<'SKILL'
---
name: foo
description: test skill
---
body
SKILL
echo "agent body"  > "$UPSTREAM/agents/bar.md"
echo "prompt body" > "$UPSTREAM/prompts/baz.md"
echo "0.99.0"      > "$UPSTREAM/VERSION"
cat > "$UPSTREAM/.claude/hooks/example.sh" <<'HOOK'
#!/usr/bin/env bash
:
HOOK

(cd "$UPSTREAM" \
  && git init -q \
  && git add . \
  && git -c user.email=t@t -c user.name=t commit -q -m init)

# ─── Stage a target install (fresh — no skill/agent/prompt files yet) ──────
TARGET="$WORK/target"
mkdir -p "$TARGET"
(cd "$TARGET" \
  && git init -q \
  && echo "0.0.0" > VERSION \
  && git add VERSION \
  && git -c user.email=t@t -c user.name=t commit -q -m init)

# ─── Run --plan with the seam: HARNESS_SOURCE_DIR points at our staged tree
PLAN=$(cd "$TARGET" \
  && HARNESS_STATE_DIR="$WORK/state" \
     HARNESS_SOURCE_DIR="$UPSTREAM" \
     "$UPDATE" --plan)

# ─── Assertions ────────────────────────────────────────────────────────────
assert_install() {
  local path="$1"
  echo "$PLAN" | jq -e --arg p "$path" \
    '.actions.install | map(.path) | index($p) != null' >/dev/null \
    || fail "$path missing from actions.install" \
            "$(echo "$PLAN" | jq -c '.actions.install | map(.path)')"
  pass "$path in actions.install"
}

assert_install "skills/foo/SKILL.md"
assert_install "agents/bar.md"
assert_install "prompts/baz.md"
assert_install ".claude/hooks/example.sh"

# Symlink entries themselves should not be installed as files.
for p in ".claude/skills" ".claude/agents" ".claude/commands"; do
  if echo "$PLAN" | jq -e --arg p "$p" \
       '.actions.install | map(.path) | index($p) != null' >/dev/null; then
    fail "$p (bare symlink) leaked into actions.install" \
         "expected the symlink to be filtered, not installed as a file"
  fi
done
pass "bare .claude/{skills,agents,commands} symlink entries are filtered"
