---
name: learn
description: Use when the user says "/learn", "/learn <description>", "remember this", "save this lesson", or "add this to learnings" — captures corrections and surprising approvals from the current session into durable memory.
user-invocable: true
tier: flexible
kind: implementation
---

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

If the recent context is thin (e.g., the session was compacted), `pre-compact.sh` snapshots in `.claude/transcripts/` only record what changed on disk (branch, commit, files), not the conversation. If you can't recover the corrections from your own context, say so and ask the user to describe the lessons directly (which puts you in targeted mode for each one).

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

**User (new or update):**

Use the existing memory system: write a new file under `~/.claude/projects/<project-id>/memory/<slug>.md` with the same `Rule / Why / How to apply` body shape, and append a one-line entry to that directory's `MEMORY.md`. The system prompt's "How to save memories" section already specifies the format — follow it.

**User (conflict resolution):**

If the user picked "candidate is current," overwrite the existing memory file at `~/.claude/projects/<project-id>/memory/<slug>.md` and update the matching line in `MEMORY.md` (use the `Edit` tool — the helper does not handle user-bucket writes). If the user picked "delete the stale candidate," remove the file and the `MEMORY.md` index line.

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
- **Compacted session** — `.claude/transcripts/` snapshots don't record conversation content (only on-disk state). If you can't recover corrections from your own context, ask the user to describe each lesson directly.
- **Slug collision (different rule, same slug)** — the helper applies a numeric suffix automatically. Mention it in the confirmation line.

## Out of scope (v1)

- Audit-pass mode (`/learn --audit`) for batch pruning stale learnings.
- Migrating an entry between buckets after it's written.
- Telemetry on which learnings get triggered.
