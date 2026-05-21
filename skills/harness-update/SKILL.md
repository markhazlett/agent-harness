---
name: harness-update
description: Use when the user says "/harness-update", "update the harness", "upgrade agent-harness", "pull the latest harness", or after seeing an UPGRADE_AVAILABLE notice. Pulls latest harness files into this project, preserves project-specific configuration and local-only skills, and walks the user through any conflicts.
user-invocable: true
tier: util
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Run `/harness-update` to pull it in." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Harness Update

Pulls the latest agent-harness from upstream (`main`) into this project. Preserves project-specific configuration (`.claude/hooks/config.sh`, `.claude/settings.json`), all local-only skills/agents/commands, and asks the user before overwriting anything they've edited.

## Host detection

This skill currently handles `HARNESS_HOST=conductor` and `HARNESS_HOST=claude-code` installs (the `.claude/` tree). For Pi installs:

1. Detect the host first by reading the project's config:
   ```bash
   HARNESS_HOST=$(grep -E '^HARNESS_HOST=' "$(git rev-parse --show-toplevel)"/{.pi,.claude}/hooks/config.sh 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"')
   ```

2. **If `HARNESS_HOST=pi`:** the script in `bin/harness-update` does not currently understand `.pi/` paths. Tell the user:
   > "Pi installs upgrade by re-running `setup.sh` from a fresh harness checkout. Your `hooks/config.sh` answers are preserved as defaults during the wizard, and the .pi/ tree is re-populated from the latest source. Want me to walk you through that instead?"
   Then exit. (Full Pi-aware `/harness-update` is tracked as v2.)

3. **If `HARNESS_HOST=conductor` or `claude-code`:** continue with the script-driven steps below.

## What this skill does NOT do

- It does not run `git push`, `git commit`, or any other VCS operation. The user reviews the diff and commits when they're ready.
- It does not modify project source code, `docs/`, `CLAUDE.md`, or anything outside the harness's managed paths (`.claude/skills`, `.claude/agents`, `.claude/commands`, `.claude/hooks`, `bin/`, `VERSION`, `setup.sh`).
- It does not touch local-only files (custom skills, agents, etc. that have no upstream counterpart).

## Steps

### 1. Build the plan

```bash
PLAN_FILE=$(mktemp -t harness-plan.XXXXXX.json)
bash "$(git rev-parse --show-toplevel)/bin/harness-update" --plan > "$PLAN_FILE"
```

The script clones (or fetches) the upstream harness into `~/.agent-harness/source` and emits a JSON plan with five buckets:

- `actions.install` — files upstream ships that don't exist locally.
- `actions.update_safe` — files where local matches what was last installed (no user edits) and upstream advanced. Safe to overwrite.
- `actions.skip` — files where local already matches upstream, or the user pinned a custom version and upstream hasn't moved past it.
- `actions.conflict` — files with edits both locally and upstream (or no provenance record). Each has a `reason` field. **Each conflict requires a user decision.**
- `local_only` — files inside managed dirs that have no upstream counterpart (custom skills, agents, etc.). Always preserved.
- `preserved` — files the script will never overwrite no matter what (`config.sh`).

### 2. Show the plan to the user

Summarize counts first, then drill into specifics:

```
agent-harness: <local_version> → <upstream_version>

  install:     <N> new files (skills, hooks, etc.)
  update:      <N> files updated (no local edits)
  unchanged:   <N> files already in sync
  conflict:    <N> files need a decision
  preserved:   config.sh (always kept)
  local-only:  <N> files (your custom additions, kept)
```

If the user wants to see lists, show `install` and `update_safe` paths plainly. Don't dump the full plan unless asked — it can be 80+ lines.

### 3. Resolve conflicts

For each entry in `actions.conflict`, present the path and reason, then offer:

- **`keep mine`** — leave the local version alone. The script records the upstream hash that was declined, so the file won't auto-update silently next time, and the local hash, so a later edit re-surfaces it as a conflict.
- **`take upstream`** — overwrite local with upstream.
- **`show diff`** — run `diff -u "$REPO_ROOT/<path>" "$SOURCE_DIR/<path>"` (the plan JSON has `source_dir`) and re-prompt.
- **`abort`** — write `"abort"` for any conflict to cancel the whole apply.

Build a resolution JSON:

```json
{
  "conflicts": {
    "skills/sync/SKILL.md": "keep-mine",
    ".claude/hooks/post-edit.sh": "take-upstream"
  }
}
```

If there are zero conflicts, skip straight to step 4 with an empty `{"conflicts": {}}` resolution.

### 4. Apply

```bash
RES_FILE=$(mktemp -t harness-resolution.XXXXXX.json)
# write resolution JSON to $RES_FILE
bash "$(git rev-parse --show-toplevel)/bin/harness-update" \
  --apply --from "$PLAN_FILE" --resolve "$RES_FILE"
```

The script emits one line per file action on stderr (`installed:`, `updated:`, `resolved:`, `kept:`) and a final summary. It also writes:

- `~/.agent-harness/installed-manifest.json` — provenance for the next run.
- `~/.agent-harness/just-upgraded-from` — consumed by `bin/harness-update-check` so the next skill invocation surfaces the JUST_UPGRADED notice.

### 5. Show the user what changed and stop

Print a compact summary, then **stop**. The user reviews `git status` / `git diff` and commits when they're ready. Do not auto-commit, do not push.

If `setup.sh` was updated, mention it — the user may want to re-run it to pick up new config knobs (it preserves their existing `config.sh` answers as defaults… actually, re-running re-prompts every value, so suggest editing `config.sh` directly for new fields rather than re-running unless they specifically want the wizard).

## Edge cases

- **Not a git repository** — the script aborts. Tell the user to run from inside their project root.
- **No `VERSION` file at repo root** — the script aborts ("doesn't look like a harness install"). Suggest running `setup.sh` from a fresh harness checkout if they're trying to install for the first time.
- **`jq` or `git` missing** — the script aborts on dependency check. Surface the error and suggest installing.
- **Upstream fetch fails** (offline, repo moved) — the script aborts. The plan is not partially applied.
- **First run on an existing install** — there's no manifest yet, so any local file that differs from upstream falls into `conflict` with reason `"no manifest record (first run or pre-existing local file)"`. Walk the user through each one. After the first apply, future runs are quiet because the manifest is populated.
- **User aborts mid-resolution** — write `"abort"` for any path; the script dies before any file is touched. Safe to retry.
- **The script itself was updated** — `bin/harness-update` and `bin/harness-update-check` are managed by the script. If upstream changed them and local is untouched, they get overwritten as part of `update_safe`. The next invocation uses the new version.
