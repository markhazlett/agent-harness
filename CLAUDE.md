# Agent Harness — Working Notes

This is the source repo for the agent-harness itself. Changes here ship to other users via the update-check pattern in `bin/harness-update-check`.

**Design philosophy:** see `.claude/docs/harness-principles.md` (63 principles distilled from operating inside the harness). When authoring or editing a skill, hook, or tool, the relevant principle section is cited inline. New skills go through `/write-skill` (rigid authoring discipline) + `/skill-baseline` (RED-phase runner).

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

## Coding conventions (working on this harness)

Adapted from Karpathy's CLAUDE.md ([forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md)) and Mnimiy's 8-rule extension (`@Mnilax` on X, May 2026). Phrased for harness development specifically.

1. **Surgical changes.** When editing a skill, hook, or doc, every changed line should trace to the requested change. Don't refactor adjacent skills, reformat sibling files, or "improve" unrelated content. Match the existing style of the file you're editing even when you'd write it differently. If you notice unrelated dead code or stale references, flag them — don't silently delete.
2. **Simplicity first.** No new abstractions for single-use code. No "flexibility" knobs nobody asked for. If you wrote 200 lines and 50 would do, rewrite. The harness's own design philosophy (`.claude/docs/harness-principles.md` §§55-63) is the anti-pattern list — read it before adding new structure.
3. **Use the model only for judgment calls.** Anything mechanically enforceable belongs in a hook (`.claude/hooks/`), a validator (`bin/test-frontmatter`, `bin/harness-update-check`), or a shell script — not in a skill body. Skills are for the cases where the model needs to *decide*. Principle §24 (tools as forcing functions).
4. **Surface conflicts, don't average them.** When `CLAUDE.md` says X and a skill says Y, follow `CLAUDE.md` (§ Instruction precedence) — but *name* the conflict in your response. Don't try to half-satisfy both. The user is principal; the resolution is theirs to make.
5. **Match conventions, even if you disagree.** The harness has a frontmatter contract (`.claude/skills/CONVENTIONS.md`), a rigid-skill template, a `<update-check>` block pattern, and a VERSION bump rule. Follow them. If you think a convention is wrong, raise it as a separate discussion, not as a silent deviation in your edit.
6. **Fail loud.** Hooks, validators, and bin/ scripts should crash visibly on bad input — never swallow errors silently or return defaults that pretend nothing was wrong. `bin/test-frontmatter` failing 1/29 is more useful than passing 29/29 by skipping the broken one. The harness depends on these gates being honest.

These rules apply to working on the harness itself. The shipped starter for consumer repos lives at `.claude/docs/claude-md-template.md` — a longer 12-rule contract scoped to user projects, not harness development.
