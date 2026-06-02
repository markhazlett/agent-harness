#!/usr/bin/env bash
# Regression test for the old-layout auto-migration in bin/harness-update.
#
# Downstream installs created before the symlink-layout flip have
# .claude/skills, .claude/agents, .claude/commands as real directories.
# Upstream now ships top-level skills/, agents/, prompts/ with .claude/*
# as symlinks. Without migration, /harness-update on an old-layout repo
# silently strands every upstream skill at top-level (invisible to Claude
# Code, which reads from .claude/).
#
# This test stages an old-layout target + new-layout upstream and exercises:
#   1. `--plan` reports needs_layout_migration with the three real-dir
#      entries and the canonical-path mapping (commands → prompts).
#   2. `--migrate-layout` performs the moves, replaces the originals with
#      symlinks, and rewrites the installed-manifest paths.
#   3. A second `--plan` is clean (no migration entries) and re-runs the
#      upstream walk against the migrated layout without spurious
#      install/conflict noise.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
UPDATE="$REPO_ROOT/bin/harness-update"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; [ -n "${2:-}" ] && echo "  $2"; exit 1; }

WORK=$(mktemp -d -t harness-migrate.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

# ─── Stage upstream in the new layout (top-level + .claude/* symlinks) ─────
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

# ─── Stage an OLD-layout target ────────────────────────────────────────────
# .claude/{skills,agents,commands} are real directories with content.
# A manifest exists with old-style paths to verify path rewrites.
TARGET="$WORK/target"
mkdir -p "$TARGET/.claude/skills/oldskill" \
         "$TARGET/.claude/agents" \
         "$TARGET/.claude/commands"
cat > "$TARGET/.claude/skills/oldskill/SKILL.md" <<'SKILL'
---
name: oldskill
description: pre-existing local skill
---
SKILL
echo "old agent"   > "$TARGET/.claude/agents/oldagent.md"
echo "old prompt"  > "$TARGET/.claude/commands/oldcmd.md"

(cd "$TARGET" \
  && git init -q \
  && echo "0.18.0" > VERSION \
  && git add . \
  && git -c user.email=t@t -c user.name=t commit -q -m init)

STATE="$WORK/state"
mkdir -p "$STATE"
cat > "$STATE/installed-manifest.json" <<'MANIFEST'
{
  "version_when_installed": "0.18.0",
  "installed_at": "2026-01-01T00:00:00Z",
  "files": {
    ".claude/skills/oldskill/SKILL.md": {
      "upstream_hash": "deadbeef",
      "local_hash": "deadbeef"
    },
    ".claude/agents/oldagent.md": {
      "upstream_hash": "cafef00d",
      "local_hash": "cafef00d"
    },
    ".claude/commands/oldcmd.md": {
      "upstream_hash": "feedface",
      "local_hash": "feedface"
    },
    "VERSION": {
      "upstream_hash": "1111",
      "local_hash": "1111"
    }
  }
}
MANIFEST

# ─── 1. --plan reports needs_layout_migration ──────────────────────────────
PLAN=$(cd "$TARGET" \
  && HARNESS_STATE_DIR="$STATE" \
     HARNESS_SOURCE_DIR="$UPSTREAM" \
     "$UPDATE" --plan)

assert_migration_entry() {
  local from="$1" to="$2"
  echo "$PLAN" | jq -e \
    --arg f "$from" --arg t "$to" \
    '.needs_layout_migration | map(select(.from == $f and .to == $t)) | length == 1' \
    >/dev/null \
    || fail "needs_layout_migration missing { from: $from, to: $to }" \
            "$(echo "$PLAN" | jq -c '.needs_layout_migration // null')"
  pass "needs_layout_migration includes $from → $to"
}

assert_migration_entry ".claude/skills"   "skills"
assert_migration_entry ".claude/agents"   "agents"
assert_migration_entry ".claude/commands" "prompts"

# ─── 2. --migrate-layout performs the migration ────────────────────────────
(cd "$TARGET" \
  && HARNESS_STATE_DIR="$STATE" \
     HARNESS_SOURCE_DIR="$UPSTREAM" \
     "$UPDATE" --migrate-layout >/dev/null)

# Top-level dirs exist with content
[ -f "$TARGET/skills/oldskill/SKILL.md" ] \
  || fail "skills/oldskill/SKILL.md missing after migration" \
          "$(ls -la "$TARGET/skills" 2>&1 || true)"
[ -f "$TARGET/agents/oldagent.md" ] \
  || fail "agents/oldagent.md missing after migration"
[ -f "$TARGET/prompts/oldcmd.md" ] \
  || fail "prompts/oldcmd.md missing after migration (commands → prompts rename)"
pass "content moved into top-level skills/agents/prompts"

# .claude/* are now symlinks pointing at the canonical top-level dirs
for pair in "skills:../skills" "agents:../agents" "commands:../prompts"; do
  src="${pair%%:*}"; want="${pair##*:}"
  link="$TARGET/.claude/$src"
  [ -L "$link" ] \
    || fail ".claude/$src is not a symlink after migration" \
            "$(ls -la "$link" 2>&1 || true)"
  got=$(readlink "$link")
  [ "$got" = "$want" ] \
    || fail ".claude/$src points at '$got' (expected '$want')"
done
pass ".claude/{skills,agents,commands} replaced with symlinks"

# Manifest paths rewritten
for new in "skills/oldskill/SKILL.md" "agents/oldagent.md" "prompts/oldcmd.md"; do
  jq -e --arg p "$new" '.files[$p]' "$STATE/installed-manifest.json" >/dev/null \
    || fail "manifest missing rewritten path $new" \
            "$(jq -c '.files | keys' "$STATE/installed-manifest.json")"
done
for old in ".claude/skills/oldskill/SKILL.md" ".claude/agents/oldagent.md" ".claude/commands/oldcmd.md"; do
  if jq -e --arg p "$old" '.files[$p]' "$STATE/installed-manifest.json" >/dev/null 2>&1; then
    fail "manifest still has old-style path $old" \
         "$(jq -c '.files | keys' "$STATE/installed-manifest.json")"
  fi
done
# Unrelated entries (VERSION) untouched.
jq -e '.files["VERSION"]' "$STATE/installed-manifest.json" >/dev/null \
  || fail "manifest lost unrelated VERSION entry during rewrite"
pass "manifest paths rewritten (and unrelated entries preserved)"

# ─── 3. --plan after migration is clean ────────────────────────────────────
PLAN2=$(cd "$TARGET" \
  && HARNESS_STATE_DIR="$STATE" \
     HARNESS_SOURCE_DIR="$UPSTREAM" \
     "$UPDATE" --plan)

migration_count=$(echo "$PLAN2" | jq -r '(.needs_layout_migration // []) | length')
[ "$migration_count" = "0" ] \
  || fail "needs_layout_migration non-empty after migration" \
          "$(echo "$PLAN2" | jq -c '.needs_layout_migration')"
pass "post-migration --plan reports no further layout migration needed"

# ─── 4. --apply on an un-migrated old-layout repo refuses ──────────────────
# Belt-and-suspenders for users who bypass the skill and invoke the CLI
# directly. Stage a fresh old-layout target so the guard has something to
# detect, capture the plan, then attempt --apply without --migrate-layout.
TARGET2="$WORK/target2"
mkdir -p "$TARGET2/.claude/skills/oldskill"
cat > "$TARGET2/.claude/skills/oldskill/SKILL.md" <<'SKILL'
---
name: oldskill
description: pre-existing local skill
---
SKILL
(cd "$TARGET2" \
  && git init -q \
  && echo "0.18.0" > VERSION \
  && git add . \
  && git -c user.email=t@t -c user.name=t commit -q -m init)

STATE2="$WORK/state2"
mkdir -p "$STATE2"
PLAN3_FILE="$WORK/plan3.json"
(cd "$TARGET2" \
  && HARNESS_STATE_DIR="$STATE2" \
     HARNESS_SOURCE_DIR="$UPSTREAM" \
     "$UPDATE" --plan > "$PLAN3_FILE")
echo '{"conflicts":{}}' > "$WORK/resolve.json"

set +e
APPLY_OUT=$(cd "$TARGET2" \
  && HARNESS_STATE_DIR="$STATE2" \
     HARNESS_SOURCE_DIR="$UPSTREAM" \
     "$UPDATE" --apply --from "$PLAN3_FILE" --resolve "$WORK/resolve.json" 2>&1)
APPLY_RC=$?
set -e

[ "$APPLY_RC" -ne 0 ] \
  || fail "--apply succeeded on an un-migrated old-layout repo" \
          "expected non-zero exit; got rc=$APPLY_RC, output: $APPLY_OUT"
echo "$APPLY_OUT" | grep -qi "migrate-layout" \
  || fail "--apply died but the error did not mention migrate-layout" \
          "output: $APPLY_OUT"
# Nothing should have been written under top-level skills/.
[ ! -e "$TARGET2/skills" ] \
  || fail "--apply wrote to top-level skills/ despite refusing" \
          "$(ls -la "$TARGET2/skills" 2>&1 || true)"
pass "--apply refuses on un-migrated old-layout repo and writes nothing"

echo ""
echo "ALL PASS"
