# Agent Harness — Working Notes

This is the source repo for the agent-harness itself. Changes here ship to other users via the update-check pattern in `bin/harness-update-check`.

## Instruction precedence

When instructions conflict, this is the order:

1. **User explicit instructions** (this `CLAUDE.md`, `AGENTS.md`, direct user requests in the conversation) — highest.
2. **Harness skills** (`/tdd`, `/pre-deploy`, `/ship`, etc.) — override default Claude Code behavior where they conflict.
3. **Default Claude Code behavior** — lowest.

If `CLAUDE.md` says "don't use TDD on this branch" and `/tdd` says "always TDD," follow `CLAUDE.md`. The user is principal; skills are advisors.

This applies to rigid skills too. A rigid skill's Iron Law is the harness's recommendation, not a runtime block. The user can:

- **Override globally in this `CLAUDE.md`** (e.g., "skip `/pre-deploy` on docs-only PRs", "no TDD for prototype scripts in `experiments/`").
- **Override per-turn in their message** ("ignore /tdd for this one — quick spike").
- **Suppress a skill from auto-firing** by adding it to a skip list in `CLAUDE.md`.

Skills that auto-fire other skills (e.g., `/build` invoking `/tdd`) check `CLAUDE.md` first. Hooks under `.claude/hooks/` are the only enforcement layer that bypasses this hierarchy — they exist to catch destructive shell commands and protect files, not to gate workflow choices.

## Bump `VERSION` when shipping user-visible harness changes

The `VERSION` file at the repo root is the source of truth that `bin/harness-update-check` compares against. When a user has an older local copy, every skill invocation surfaces an `UPGRADE_AVAILABLE` notice — but only if `VERSION` on `main` is greater than theirs.

**Bump `VERSION` in the same PR as any change that affects users**, including:

- New skills under `.claude/skills/` (user-invocable or otherwise)
- Changes to existing skill behavior, prompts, or workflow
- New or changed hooks under `.claude/hooks/`
- Changes to `setup.sh` or anything that affects install
- New commands under `.claude/commands/`

Skip the bump for: docs-only edits that don't change skill content, internal refactors with no behavior change, fixes to this CLAUDE.md.

**Versioning convention** (semver-ish):
- **Minor** (`0.X.0`) for new features — new skill, new hook category, new integration. Past examples: `0.2.0` added the update-check pattern, `0.3.0` added Conductor integration, `0.4.0` added `/office-hours`, `0.5.0` added `/learn`.
- **Patch** (`0.X.Y`) for fixes and small tweaks to existing behavior.

Do the bump as part of the feature commit (or a `chore: bump version to X.Y.Z` commit in the same PR). Don't ship the feature and the bump in separate PRs — that defeats the point of update-check.

## Learnings

Captured by `/learn`; each entry lives at `docs/learnings/<slug>.md` with a `Rule / Why / How to apply` body.

Avoid saving entries that fall in the anti-list — code patterns, file paths, git history, fix recipes, CLAUDE.md duplicates, ephemeral state, activity summaries. When a candidate looks like one of those, ask what was *surprising* and save the surprising framing instead. Memories that name a specific function, file, or flag should be re-verified (`Grep` / `test -e`) before being recommended — they describe a moment in time, not a current guarantee.
