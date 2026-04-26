# Learning Loop — Design

**Status:** Draft
**Date:** 2026-04-26
**Owner:** Mark Hazlett

## Problem

The agent harness has no mechanism to compound the corrections the user gives Claude during a session. When the user tells Claude "do this differently" — and especially when Claude *failed to follow* that direction the first time — the lesson dies with the session. The next session starts from zero. The cost of every correction is paid again on the next project, in the next workspace, in the next week.

Claude Code's existing user-memory system is supposed to capture this via its `feedback` memory type, but it triggers from inside the model and is unreliable: in a recent multi-hour session the user had to repeat the same correction more than once and nothing was saved.

We want a deterministic, user-controlled way to capture corrections and re-inject them so future sessions inherit them automatically.

## Goals

- A user-triggered way to capture lessons from a session into durable storage.
- Two scopes: project-specific (lives with the repo, git-tracked, shared with teammates) and user-specific (private to the user, not git-tracked, written via Claude Code's existing memory system).
- Auto-loaded so future sessions inherit the lessons without the user remembering to surface them.
- Compounding rather than sprawling: invoking the loop a second time should *consolidate* with existing lessons, not duplicate them.
- Ships with the harness, no per-project setup.

## Non-goals (v1)

- Automatic in-session capture (silent hooks that detect corrections without user prompting). The existing memory system already attempts this; v1 is the explicit fallback that complements it.
- Cross-team learning sync, web UI, analytics, or telemetry.
- Automatic pruning of stale learnings.
- Migrating learnings between buckets after they're written.

## Architecture

One new skill, no new hooks, no new agents.

```
.claude/skills/learn/SKILL.md     ← mechanism (ships with harness)
CLAUDE.md  →  ## Learnings        ← one-liner index, always loaded by Claude Code
                - [Use pnpm not npm](docs/learnings/use-pnpm.md) — never falls back to npm
docs/learnings/<slug>.md          ← full detail (rule, why, how to apply, examples)
~/.claude/<project-id>/memory/    ← user-scoped learnings (existing system, unchanged)
```

The skill is the only new artifact. Two storage destinations are already in the system:

- **Project learnings**: indexed in `CLAUDE.md` (auto-loaded), detail in `docs/learnings/<slug>.md` (loaded on demand). Mirrors the user-memory system's `MEMORY.md` + individual files pattern, so project and user buckets feel structurally consistent.
- **User learnings**: the existing Claude memory system, used unchanged.

The harness ships `.claude/skills/learn/SKILL.md` so every install gets `/learn` automatically.

## Skill behavior

Two invocation modes.

### `/learn` — scan mode (no args)

1. Read recent conversation context (current session up to this point, plus `pre-compact.sh` transcript snapshots if recent context is thin).
2. Identify candidate learnings:
   - Explicit corrections ("don't do X", "stop doing Y")
   - Implicit corrections (the user reverted Claude's change)
   - Surprising approvals ("yeah, the bundled PR was right" — confirmations of non-obvious choices)
3. For each candidate, draft an entry and propose a bucket (project / user).
4. Present the list to the user with `[a]ccept / [e]dit / [m]ove bucket / [s]kip` per candidate.
5. Write only the survivors.

### `/learn <description>` — targeted mode

1. Skip the scan; the user's description is the source of truth.
2. Draft a single entry and propose a bucket.
3. Same `[a]ccept / [e]dit / [m]ove / [s]kip` flow.
4. Write if accepted.

### Dedup & merge (both modes)

Before drafting any new entry, the skill loads three sources:

1. `CLAUDE.md` `## Learnings` index (one-liners — fast scan)
2. `~/.claude/<project-id>/memory/MEMORY.md` index (one-liners — fast scan)
3. Any individual learning files whose one-liner looks related to a candidate (loaded on demand)

For each candidate the skill picks one of:

- **New** — no overlap; draft a fresh entry.
- **Update** — same rule, candidate adds nuance (exception, example, clarification). Propose editing the existing file. Frontmatter `updated` bumps; body merges.
- **Conflict** — candidate contradicts an existing learning. Show both, ask which is current, replace or delete the stale one. Never silently overwrite.

Every merge or replacement is shown to the user with a before/after diff.

## Bucket decision (project vs user)

The skill proposes a bucket per candidate; the user can override.

**Project bucket signals:**
- Names a tool, file, command, or convention specific to *this* repo (`pnpm`, `drizzle`, "our `auth/` module")
- References a teammate, incident, or PR in this codebase
- Constrains code style or testing for this repo specifically

**User bucket signals:**
- About how the user communicates with Claude ("terse responses", "no trailing summaries")
- About how the user works in general ("explain frontend in backend terms")
- Should not be git-tracked (private preference, not team policy)

**Ambiguous → ask.** Don't guess.

The user can override with the `[m]ove` action.

## Storage formats

### Project — full file (`docs/learnings/<slug>.md`)

```markdown
---
name: Use pnpm, not npm
created: 2026-04-26
updated: 2026-04-26
tags: [tooling, package-manager]
---

**Rule:** Always use `pnpm` for installs and scripts. Never fall back to `npm` or `yarn`.

**Why:** Workspace uses pnpm workspaces; `npm install` corrupts the lockfile and breaks CI for everyone.

**How to apply:** Any command that would be `npm <x>` becomes `pnpm <x>`. If a doc or README says `npm`, treat it as a bug.

**Examples / context:** (optional — PRs, incidents, snippets)
```

### Project — index entry (in `CLAUDE.md`)

```markdown
## Learnings
- [Use pnpm, not npm](docs/learnings/use-pnpm.md) — never fall back to npm/yarn; corrupts the lockfile
```

One line, one link, one hook. Section auto-created by `/learn` if missing; appended at the bottom of `CLAUDE.md` without reordering existing content.

### User

The existing memory system, unchanged. Body uses the same `Rule / Why / How to apply` shape that `~/.claude/`'s system prompt already specifies. One-line entry in `MEMORY.md` index.

## Edge cases

- **No `CLAUDE.md` exists** — create one with just the `## Learnings` section. Don't synthesize a project description.
- **No `## Learnings` section in existing `CLAUDE.md`** — append at bottom; don't reorder.
- **No `docs/` directory** — create `docs/learnings/`. If `docs/` is gitignored, surface that and ask before writing.
- **User runs `/learn` with no captureable corrections** — say so and exit; don't manufacture.
- **Compacted session** — fall back to `.claude/transcripts/` snapshots from `pre-compact.sh`.
- **Slug collision in `docs/learnings/`** — append a numeric suffix; never overwrite.

## Testing

Bash integration tests in `bin/tests/learn-skill.test.sh`, following the existing `bin/tests/setup-*.test.sh` pattern. Each test runs in a temp dir with a fake `~/.claude/`.

Cases:

- Fresh repo (no `CLAUDE.md`, no `docs/learnings/`) → both created with one entry, index linked correctly.
- Existing `CLAUDE.md` with no `## Learnings` section → section appended, existing content unchanged.
- Existing learning, candidate is an update → `updated` frontmatter bumps; body merged.
- Existing learning, candidate conflicts → conflict surfaced; no silent write.
- User-bucket entry → routes to `~/.claude/<project-id>/memory/`; `CLAUDE.md` and `docs/learnings/` untouched.
- `/learn` invoked with no candidates → exits cleanly with a message.
- Slug collision → numeric suffix applied; original file untouched.

## Out of scope (deferred)

- Silent capture hook that pre-queues candidates for `/learn` to drain (Approach 2 from brainstorming). Bolt on if recall becomes the bottleneck.
- Audit-pass mode (`/learn --audit`) for batch pruning stale learnings.
- Cross-bucket migration (moving an entry from project to user or vice versa after it's written).
- Telemetry / metrics on which learnings get triggered most often.
