# Agent Harness — Working Notes

This is the source repo for the agent-harness itself. Changes here ship to other users via the update-check pattern in `bin/harness-update-check`.

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
