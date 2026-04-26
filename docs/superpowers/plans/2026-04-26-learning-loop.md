# Learning Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `/learn` skill that captures session corrections into project-scoped (CLAUDE.md + `docs/learnings/`) and user-scoped (Claude Code memory) buckets, with a tested bash helper for the deterministic write path.

**Architecture:** Two new artifacts. `bin/learn` is a bash helper handling deterministic writes — slug derivation, file creation, `## Learnings` index update, update-vs-collision logic. `.claude/skills/learn/SKILL.md` instructs Claude on the reasoning side — scanning context, identifying candidates, deciding bucket, detecting conflicts, calling the helper. User-scoped learnings flow through the existing memory system unchanged.

**Tech Stack:** Bash + awk for markdown manipulation. Tests follow the existing `bin/tests/setup-*.test.sh` pattern (mktemp dir, `pass`/`fail` helpers, no test framework dependency).

**Spec:** `docs/superpowers/specs/2026-04-26-learning-loop-design.md`

---

## File structure

**Create:**
- `bin/learn` — bash CLI (chmod +x). One subcommand for v1: `write-project`. Handles slug derivation, frontmatter writes, CLAUDE.md `## Learnings` section creation/update, and existing-entry update vs collision suffix.
- `bin/tests/learn.test.sh` — bash integration tests for `bin/learn write-project`.
- `.claude/skills/learn/SKILL.md` — skill markdown for `/learn` invocation. Covers scan vs targeted modes, dedup/merge reasoning, bucket decision, conflict handling, and edge cases.

**Modify:**
- `README.md` — add `/learn` to the skills table under "Workflow" and add a brief description in the "What you get" section.

---

## Task 1: bin/learn write-project — fresh-repo case (TDD)

**Files:**
- Create: `bin/learn`
- Create: `bin/tests/learn.test.sh`

- [ ] **Step 1: Write the failing test**

Create `bin/tests/learn.test.sh`:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash bin/tests/learn.test.sh`
Expected: FAIL — `bin/learn` doesn't exist yet, so the script exits with "No such file or directory".

- [ ] **Step 3: Create the minimal bin/learn**

Create `bin/learn`:

```bash
#!/usr/bin/env bash
# bin/learn — helper for the /learn skill.
# Subcommand: write-project — atomically write a project-scoped learning
# into docs/learnings/<slug>.md and update CLAUDE.md ## Learnings index.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bin/learn write-project --name <NAME> --summary <SUMMARY> --body-file <FILE>

Writes a project-scoped learning into:
  - docs/learnings/<slug>.md  (full body with frontmatter)
  - CLAUDE.md ## Learnings    (one-liner index entry)

Creates docs/learnings/, CLAUDE.md, and the ## Learnings section as
needed. Prints the path of the written body file to stdout.
EOF
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '-' | sed -E 's/-+/-/g; s/^-//; s/-$//'
}

cmd="${1:-}"; shift || true
case "$cmd" in
  write-project) ;;
  ""|-h|--help|help) usage; exit 0 ;;
  *) echo "Unknown command: $cmd" >&2; usage >&2; exit 2 ;;
esac

NAME="" SUMMARY="" BODY_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    --body-file) BODY_FILE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$NAME" ] && [ -n "$SUMMARY" ] && [ -n "$BODY_FILE" ] || {
  echo "Missing required args" >&2; usage >&2; exit 2
}
[ -f "$BODY_FILE" ] || { echo "Body file not found: $BODY_FILE" >&2; exit 2; }

SLUG=$(slugify "$NAME")
[ -n "$SLUG" ] || { echo "Could not derive slug from --name" >&2; exit 2; }

mkdir -p docs/learnings
TARGET="docs/learnings/${SLUG}.md"
TODAY=$(date -u +"%Y-%m-%d")

# Write body file (fresh-repo path: always create new)
{
  printf -- '---\n'
  printf 'name: %s\n' "$NAME"
  printf 'created: %s\n' "$TODAY"
  printf 'updated: %s\n' "$TODAY"
  printf 'tags: []\n'
  printf -- '---\n\n'
  cat "$BODY_FILE"
} > "$TARGET"

# Ensure CLAUDE.md and ## Learnings section
if [ ! -f CLAUDE.md ]; then
  printf '## Learnings\n\n' > CLAUDE.md
elif ! grep -q '^## Learnings$' CLAUDE.md; then
  # Append section. Leading newline guards against files that don't end in one.
  printf '\n## Learnings\n\n' >> CLAUDE.md
fi

# Append the index entry under ## Learnings
ENTRY="- [$NAME]($TARGET) — $SUMMARY"
awk -v entry="$ENTRY" '
  BEGIN { in_section = 0; inserted = 0 }
  /^## Learnings$/ { print; in_section = 1; next }
  in_section && /^## / { if (!inserted) { print entry; inserted = 1 } in_section = 0; print; next }
  { print }
  END { if (in_section && !inserted) print entry }
' CLAUDE.md > CLAUDE.md.tmp && mv CLAUDE.md.tmp CLAUDE.md

echo "$TARGET"
```

- [ ] **Step 4: Make executable, run the test**

```bash
chmod +x bin/learn
bash bin/tests/learn.test.sh
```

Expected output:
```
PASS: fresh repo creates files and index

Results: 1 passed, 0 failed
```

- [ ] **Step 5: Commit**

```bash
git add bin/learn bin/tests/learn.test.sh
git commit -m "feat(learn): bin/learn write-project for fresh repo"
```

---

## Task 2: bin/learn — preserve existing CLAUDE.md content

**Files:**
- Modify: `bin/tests/learn.test.sh`
- (Verify behavior already correct in `bin/learn`, fix if not.)

- [ ] **Step 1: Add the test**

Append to `bin/tests/learn.test.sh` *before* the `# ---- summary ----` block:

```bash
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
```

- [ ] **Step 2: Run the test**

Run: `bash bin/tests/learn.test.sh`
Expected: PASS — the Task 1 implementation already handles this case via the `! grep -q '^## Learnings$'` branch.

- [ ] **Step 3: If the test fails**

The most likely cause is the awk script not finding the appended section due to spacing. Verify by running `cat CLAUDE.md` after the call — `## Learnings` should appear at the bottom with a blank line above and below. If the section is there but the entry isn't, the awk insert logic is the issue; check that `in_section` correctly survives blank lines between the heading and EOF (it does, because blank lines don't match `/^## /`).

- [ ] **Step 4: Commit**

```bash
git add bin/tests/learn.test.sh bin/learn
git commit -m "test(learn): existing CLAUDE.md without Learnings section"
```

---

## Task 3: bin/learn — update existing entry (same slug + same name)

**Files:**
- Modify: `bin/tests/learn.test.sh`
- Modify: `bin/learn`

- [ ] **Step 1: Add the test**

Append to `bin/tests/learn.test.sh` before the summary block:

```bash
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
```

- [ ] **Step 2: Run, verify failure**

Run: `bash bin/tests/learn.test.sh`
Expected: FAIL on the `created` preservation or index dedup checks.

- [ ] **Step 3: Update bin/learn**

Replace the body-write block in `bin/learn` (the section starting with `mkdir -p docs/learnings`) with:

```bash
mkdir -p docs/learnings
TARGET="docs/learnings/${SLUG}.md"
TODAY=$(date -u +"%Y-%m-%d")

# Detect existing file: same slug + same name → update; same slug + different name → collision (Task 4)
EXISTING_NAME=""
EXISTING_CREATED=""
if [ -f "$TARGET" ]; then
  EXISTING_NAME=$(awk '
    /^---$/ { in_fm = !in_fm; next }
    in_fm && /^name:/ { sub(/^name:[ ]*/, ""); print; exit }
  ' "$TARGET")
  EXISTING_CREATED=$(awk '
    /^---$/ { in_fm = !in_fm; next }
    in_fm && /^created:/ { sub(/^created:[ ]*/, ""); print; exit }
  ' "$TARGET")
fi

CREATED="$TODAY"
if [ "$EXISTING_NAME" = "$NAME" ] && [ -n "$EXISTING_CREATED" ]; then
  CREATED="$EXISTING_CREATED"
fi

{
  printf -- '---\n'
  printf 'name: %s\n' "$NAME"
  printf 'created: %s\n' "$CREATED"
  printf 'updated: %s\n' "$TODAY"
  printf 'tags: []\n'
  printf -- '---\n\n'
  cat "$BODY_FILE"
} > "$TARGET"
```

And replace the index-update awk block with one that **replaces** an existing line for this `TARGET` rather than always appending:

```bash
ENTRY="- [$NAME]($TARGET) — $SUMMARY"
awk -v entry="$ENTRY" -v target="($TARGET)" '
  BEGIN { in_section = 0; inserted = 0 }
  /^## Learnings$/ { print; in_section = 1; next }
  in_section && /^## / {
    if (!inserted) { print entry; inserted = 1 }
    in_section = 0; print; next
  }
  in_section && index($0, target) > 0 { print entry; inserted = 1; next }
  { print }
  END { if (in_section && !inserted) print entry }
' CLAUDE.md > CLAUDE.md.tmp && mv CLAUDE.md.tmp CLAUDE.md
```

- [ ] **Step 4: Run, verify pass**

Run: `bash bin/tests/learn.test.sh`
Expected: All 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add bin/learn bin/tests/learn.test.sh
git commit -m "feat(learn): update existing entry instead of duplicating"
```

---

## Task 4: bin/learn — slug collision (different name → numeric suffix)

**Files:**
- Modify: `bin/tests/learn.test.sh`
- Modify: `bin/learn`

- [ ] **Step 1: Add the test**

Append before the summary block:

```bash
test_slug_collision_different_name() {
  local repo; repo=$(setup_temp_repo)
  cd "$repo"
  cat > body1.md <<'EOF'
**Rule:** First learning.
EOF
  "$LEARN_BIN" write-project \
    --name "Foo bar" --summary "first" \
    --body-file body1.md > /dev/null

  cat > body2.md <<'EOF'
**Rule:** Second learning.
EOF
  # "Foo-bar" slugifies to "foo-bar" same as "Foo bar", but the names differ
  local out
  out=$("$LEARN_BIN" write-project \
    --name "Foo-bar" --summary "second" \
    --body-file body2.md)

  if [ "$out" != "docs/learnings/foo-bar-2.md" ]; then
    fail "collision returns suffixed path" "got: $out"
    return
  fi
  assert_file_exists "docs/learnings/foo-bar.md" "original kept" || return
  assert_file_exists "docs/learnings/foo-bar-2.md" "suffixed file created" || return
  assert_file_contains "docs/learnings/foo-bar.md" "First learning" "original body untouched" || return
  assert_file_not_contains "docs/learnings/foo-bar.md" "Second learning" "original not overwritten" || return
  assert_file_contains "docs/learnings/foo-bar-2.md" "Second learning" "new body in suffixed file" || return
  # Both entries in index
  local count
  count=$(grep -cE '^- \[Foo' CLAUDE.md)
  if [ "$count" != "2" ]; then
    fail "two index entries" "expected 2 entries, got $count"
    return
  fi
  pass "slug collision with different name applies numeric suffix"
}

test_slug_collision_different_name
```

- [ ] **Step 2: Run, verify failure**

Run: `bash bin/tests/learn.test.sh`
Expected: FAIL — current code overwrites the existing file because the names differ but no collision logic exists yet.

- [ ] **Step 3: Update bin/learn**

After the `EXISTING_NAME=` / `EXISTING_CREATED=` block (introduced in Task 3), insert the collision-resolution loop. Replace the `CREATED="$TODAY"` block with:

```bash
CREATED="$TODAY"
if [ "$EXISTING_NAME" = "$NAME" ] && [ -n "$EXISTING_CREATED" ]; then
  # Same slug + same name → in-place update; preserve created.
  CREATED="$EXISTING_CREATED"
elif [ -n "$EXISTING_NAME" ]; then
  # Slug collision (different name): pick first available -N suffix.
  N=2
  while [ -f "docs/learnings/${SLUG}-${N}.md" ]; do
    EXISTING_N_NAME=$(awk '
      /^---$/ { in_fm = !in_fm; next }
      in_fm && /^name:/ { sub(/^name:[ ]*/, ""); print; exit }
    ' "docs/learnings/${SLUG}-${N}.md")
    if [ "$EXISTING_N_NAME" = "$NAME" ]; then
      EXISTING_N_CREATED=$(awk '
        /^---$/ { in_fm = !in_fm; next }
        in_fm && /^created:/ { sub(/^created:[ ]*/, ""); print; exit }
      ' "docs/learnings/${SLUG}-${N}.md")
      CREATED="${EXISTING_N_CREATED:-$TODAY}"
      break
    fi
    N=$((N + 1))
  done
  SLUG="${SLUG}-${N}"
  TARGET="docs/learnings/${SLUG}.md"
fi
```

- [ ] **Step 4: Run, verify pass**

Run: `bash bin/tests/learn.test.sh`
Expected: All 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add bin/learn bin/tests/learn.test.sh
git commit -m "feat(learn): handle slug collision with numeric suffix"
```

---

## Task 5: Write the /learn skill

**Files:**
- Create: `.claude/skills/learn/SKILL.md`

- [ ] **Step 1: Inspect an existing skill for style reference**

Read one existing skill end-to-end so the new file matches the harness's voice:

```bash
cat .claude/skills/ship/SKILL.md
cat .claude/skills/plan-sprint/SKILL.md
```

Note the conventions: `<update-check>` block at the top, `## Prerequisites`, numbered `## Steps`, exact bash commands shown inline.

- [ ] **Step 2: Create `.claude/skills/learn/SKILL.md`**

```markdown
<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Learn

Capture corrections and surprising approvals from the current session into durable storage so future sessions inherit them. Use when the user says "/learn", "/learn <description>", "remember this", "save this lesson", or "add this to learnings".

## Modes

- **Scan mode** — `/learn` with no arguments: read the recent session and propose candidate learnings.
- **Targeted mode** — `/learn <description>`: take the description as the source of truth and propose a single entry.

## Buckets

Each learning is either **project-scoped** (lives in this repo, git-tracked, applies to anyone working here) or **user-scoped** (private to the user, written via Claude Code's memory system, not git-tracked).

**Project signals:** names a repo-specific tool/file/convention; references a teammate or PR; constrains style or testing for *this* repo.

**User signals:** about how the user communicates with Claude; about how the user works in general; should not be git-tracked.

**Ambiguous → ask the user.** Never guess on bucket.

## Steps

### 1. Load the existing learnings index

Before drafting anything, read what already exists so you can dedupe and merge.

- Project: read `CLAUDE.md` and look for the `## Learnings` section. Note each entry's title, file path, and one-liner summary.
- User: read `~/.claude/projects/$(echo "$PWD" | sed 's|/|-|g')/memory/MEMORY.md` if it exists. Note each entry's title and one-liner.

These are short index files; loading them is cheap. Don't load the full body files unless a candidate looks like it matches an existing entry.

### 2. Identify candidate learnings

**Scan mode:** look across the recent session for:
- Explicit corrections — "don't do X", "stop doing Y", "no, not that way"
- Implicit corrections — the user reverted something you did, or rewrote a chunk you produced
- Surprising approvals — non-obvious choices the user accepted without pushback ("yeah, the bundled PR was right")

If the recent context is thin (e.g., the session was compacted), check `.claude/transcripts/` for snapshots written by `pre-compact.sh` and use those.

**Targeted mode:** the user's description *is* the candidate; skip the scan.

If you find no candidates in scan mode, say so and stop. Do not manufacture learnings.

### 3. Draft each candidate

For each candidate, draft an entry with:

- **Name** — short noun phrase (becomes the slug and the title).
- **Summary** — one-liner for the index (under 100 chars; the punch).
- **Body** — three short blocks: `**Rule:**`, `**Why:**`, `**How to apply:**`. Optionally a `**Examples / context:**` block at the end.

For each candidate, propose a bucket (project or user) using the signals above.

### 4. Detect dedup, merge, and conflict

For each candidate, compare against existing learnings in *both* indexes:

- **New** — no existing entry covers this. Propose a fresh write.
- **Update** — an existing entry covers the same rule, and this candidate adds nuance (an exception, an example, a new clarification). Propose editing the existing file.
- **Conflict** — the candidate contradicts an existing entry ("always X" vs "never X"). Surface both side-by-side and ask the user which is current. Replace or delete the stale one based on their answer. Never silently overwrite.

Show the user the existing entry's path next to each proposal so they can spot the match.

### 5. Present the list and get approval

Show every candidate as a numbered list:

```
[1] PROJECT → docs/learnings/use-pnpm.md  (NEW)
    Name: Use pnpm, not npm
    Summary: never fall back to npm; lockfile drift breaks CI
    Body: ...
    [a]ccept  [e]dit  [m]ove to user  [s]kip

[2] USER → ~/.claude/.../memory/  (UPDATE of existing 'terse-responses.md')
    Name: Prefer terse responses
    Summary: no trailing summaries; user reads the diff
    Body diff: ...
    [a]ccept  [e]dit  [m]ove to project  [s]kip
```

Wait for the user's response. Apply their choices.

### 6. Write the survivors

For each accepted entry:

**Project (new or update):**

```bash
# Write the body to a temp file, then call the helper
cat > /tmp/learn-body.md <<'EOF'
**Rule:** ...

**Why:** ...

**How to apply:** ...
EOF

bash "$(git rev-parse --show-toplevel)/bin/learn" write-project \
  --name "Use pnpm, not npm" \
  --summary "never fall back to npm; lockfile drift breaks CI" \
  --body-file /tmp/learn-body.md
```

The helper handles slug derivation, file creation, CLAUDE.md `## Learnings` section creation, existing-entry update vs collision suffix, and index manipulation. Do not write `docs/learnings/` files or edit the `## Learnings` section directly — always use the helper.

**Project (conflict resolution):**

If the user picked "candidate is current," call `write-project` as above (the helper will replace the existing body). If the user picked "existing is current and stale candidate should be deleted," remove the stale file and the index line manually with `Edit`.

**User:**

Use the existing memory system: write a new file under `~/.claude/projects/<project-id>/memory/<slug>.md` with the same `Rule / Why / How to apply` body shape, and append a one-line entry to that directory's `MEMORY.md`. The system prompt's "How to save memories" section already specifies the format — follow it.

### 7. Confirm and exit

Print a one-line summary of what was written and where, e.g.:

```
Wrote: docs/learnings/use-pnpm.md  (new)
Wrote: ~/.claude/.../memory/terse-responses.md  (updated)
Skipped: 1 candidate
```

Do not run tests, do not commit. The user owns commit timing.

## Edge cases

- **No `CLAUDE.md`** — the helper creates one with just the `## Learnings` section. Don't synthesize a project description.
- **`docs/` is gitignored** — surface that and ask the user before writing. The harness ships with no `docs/` ignore by default; this is unusual.
- **No candidates found** — say so and exit cleanly.
- **Compacted session** — fall back to `.claude/transcripts/` snapshots.
- **Slug collision (different rule, same slug)** — the helper applies a numeric suffix automatically. Mention it in the confirmation line.

## Out of scope (v1)

- Audit-pass mode (`/learn --audit`) for batch pruning stale learnings.
- Migrating an entry between buckets after it's written.
- Telemetry on which learnings get triggered.
```

- [ ] **Step 3: Verify the skill renders**

Run: `cat .claude/skills/learn/SKILL.md | head -80`
Expected: well-formed markdown matching the layout above.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/learn/SKILL.md
git commit -m "feat(learn): add /learn skill"
```

---

## Task 6: Add `/learn` to the README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read the existing skills table to know the exact location**

Run: `grep -n "Workflow" README.md` — find the line right before the workflow skills table.

- [ ] **Step 2: Add the new row to the Workflow table**

In `README.md`, find the Workflow section under `<details><summary><strong>All skills</strong>`. The current table has rows ending with `/sync`. Add `/learn` as a new row directly before `/sync`:

```markdown
| `/learn` | After a session | Capture corrections from the session into project + user learnings |
| `/sync` | Reset | Switch to main and pull |
```

- [ ] **Step 3: Add a one-liner in the "What you get" section**

Find the "Auto-formatting, auto-typecheck, auto-everything." paragraph in the "What you get" block. Add this paragraph immediately before it:

```markdown
**A learning loop that compounds.** `/learn` captures corrections and surprising approvals from the session into `CLAUDE.md` (project) or your memory (user). Run it after a tough session — next time, the agent already knows.
```

- [ ] **Step 4: Verify**

Run: `grep -n "/learn" README.md`
Expected: at least two matches (one in the table row, one in the "What you get" paragraph).

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs(readme): document /learn skill"
```

---

## Task 7: End-to-end manual verification

**Files:** none modified — this is a manual smoke test.

- [ ] **Step 1: Set up a temp test repo**

```bash
TMPREPO=$(mktemp -d)
cd "$TMPREPO"
git init -q
echo "# Demo" > CLAUDE.md
git add CLAUDE.md && git commit -q -m init
HARNESS_REPO=$(cd /Users/markhazlett/conductor/workspaces/agent-harness/medan && pwd)
ln -s "$HARNESS_REPO/bin" bin
```

- [ ] **Step 2: Write a body file and invoke the helper directly**

```bash
cat > /tmp/demo-body.md <<'EOF'
**Rule:** Always use pnpm.

**Why:** Workspace uses pnpm; npm corrupts the lockfile.

**How to apply:** Substitute pnpm for any npm command.
EOF

bash bin/learn write-project \
  --name "Use pnpm, not npm" \
  --summary "never fall back to npm; lockfile drift" \
  --body-file /tmp/demo-body.md
```

Expected output: `docs/learnings/use-pnpm-not-npm.md`

- [ ] **Step 3: Inspect results**

```bash
cat CLAUDE.md
cat docs/learnings/use-pnpm-not-npm.md
```

Verify:
- `CLAUDE.md` retains `# Demo` heading and now has `## Learnings` section at the bottom with the index entry linking to `docs/learnings/use-pnpm-not-npm.md`.
- `docs/learnings/use-pnpm-not-npm.md` has frontmatter (`name`, `created`, `updated`, `tags: []`) and the body.

- [ ] **Step 4: Re-invoke with same name (update path)**

```bash
cat > /tmp/demo-body.md <<'EOF'
**Rule:** Always use pnpm.

**Why:** Updated — workspaces required.
EOF

bash bin/learn write-project \
  --name "Use pnpm, not npm" \
  --summary "pnpm workspaces required" \
  --body-file /tmp/demo-body.md

cat docs/learnings/use-pnpm-not-npm.md
grep -c "Use pnpm" CLAUDE.md
```

Verify: file body updated, `created` unchanged, `updated` is today, `CLAUDE.md` has exactly one entry for "Use pnpm".

- [ ] **Step 5: Clean up**

```bash
cd /
rm -rf "$TMPREPO"
```

- [ ] **Step 6: Verify the harness's own tests still pass**

Back in the harness repo, run all bin tests:

```bash
cd /Users/markhazlett/conductor/workspaces/agent-harness/medan
for f in bin/tests/*.test.sh; do bash "$f"; done
```

Expected: every test file reports 0 failed.

- [ ] **Step 7: Commit any final fixes if needed (else skip)**

If the smoke test surfaced a bug, fix it, add a regression test, and commit. Otherwise, this task ends with no commit.
