# Skill Conventions

Contract for every `.claude/skills/<name>/SKILL.md` in this harness. Validated by `bin/test-frontmatter` and surfaced in `/harness-health`.

## Frontmatter contract

Every `SKILL.md` MUST start with a YAML frontmatter block. Required fields:

```yaml
---
name: <skill-name>                 # MUST equal the folder name
description: Use when <trigger>    # trigger, not workflow summary
user-invocable: true | false       # whether the user can type /<name>
tier: rigid | flexible | util      # rigidity classification
kind: process | implementation | verification   # required when tier != util
---
```

Notes:

- `name` MUST be identical to the parent folder name. The harness loads skills by folder; a mismatch breaks slash-command invocation.
- `description` MUST start with `Use when` and describe the trigger (what the user is saying, doing, or asking when this skill should fire). It is NOT a workflow summary or feature list.
- `user-invocable: true` when the skill responds to `/<name>`. `false` when it's an internal/auto-fire skill.
- `kind` is omitted only when `tier: util`. For `rigid` and `flexible`, it is required.

## `tier` — rigidity classification

How strictly the skill's body must be followed.

- **rigid** — gate-worthy verification. The skill exists because under pressure the model rationalizes around the right behavior. Rigid skills have an Iron Law (one-line declaration), a Rationalization Table (excuses → reality), Red Flags, and a Self-Review checklist. Bypass requires explicit user override. Examples: `tdd`, `pre-deploy`, `ship`, `e2e-verify`, `security-review`, `incident`, `db-review`, `lg-review`.
- **flexible** — procedural, judgment-driven. The skill prescribes a workflow but expects adaptation to context. No Iron Law. Examples: `plan-sprint`, `deep-plan`, `build-plan`, `learn`, `office-hours`, `lg-design`, `lg-scaffold`, `lg-add`, `lg-eval`, `lg-cheatsheet`, `weekly-goals`, `demo-script`, `ad-hoc-plan`, `self-verify`.
- **util** — operational, no rigor needed. Thin commands that do one thing. Examples: `sync`, `worktree`, `dev-server`, `harness-overview`.

## `kind` — priority class (when not `util`)

Used by `using-superpowers` priority rules and skill-discovery hints.

- **process** — determines HOW to approach work (planning, brainstorming, debugging). Fires first when multiple skills could apply.
- **implementation** — guides execution of the work itself (scaffolding, building, adding capabilities).
- **verification** — gates and quality checks (testing, reviewing, shipping). Fires last in a flow.

## `description` — trigger, not summary

A description tells future-you (or another agent) **when** to fire the skill, not **what** the skill does. The body of `SKILL.md` describes what.

**Bad** (workflow summary):

> Test-driven development workflow. Writes failing tests, runs them, implements, refactors.

**Good** (trigger):

> Use when implementing any feature or bugfix, before writing implementation code.

**Bad** (feature list):

> Aggregates lint, tests, security, db, and e2e checks into a single go/no-go verdict.

**Good** (trigger):

> Use when the user says "/pre-deploy", "ready to ship", or before pushing to production.

The trigger may include named slash-commands, user phrases, or situational conditions. Keep it concrete — the model uses it to decide whether to invoke.

## Body conventions

- **Rigid skills** put the Iron Law near the top (within the first 200 words). Heavy reference material (full Rationalization Table, expanded Red Flags) lives in sibling files in the skill folder, loaded on demand. A line like:

  > **REQUIRED SUB-FILE:** Read `rationalizations.md` if you find yourself making excuses.

- **Flexible skills** describe the workflow with enough detail to drive consistent execution without prescribing every step. Lean on judgment.

- **Util skills** are short — often a single command or a brief checklist.

- All skills with the harness's update-check pattern keep the `<update-check>` block immediately after the frontmatter. The block runs `bin/harness-update-check` and surfaces upgrade prompts.

## Validation

`bin/test-frontmatter` parses every `.claude/skills/*/SKILL.md` and asserts:

1. Frontmatter is present and parses as YAML.
2. `name` is non-empty and equals the parent folder name.
3. `description` is non-empty and starts with `Use when`.
4. `user-invocable` is exactly `true` or `false`.
5. `tier` is one of `rigid | flexible | util`.
6. `kind` is one of `process | implementation | verification` — or absent only when `tier: util`.

`/harness-health` runs the validator and fails if any skill is non-conformant.

## Naming rule

`name` in frontmatter MUST equal the folder name. If you rename a skill folder, update `name`. The validator catches mismatches.

## User-supremacy invariant

Skills are advisors; the user is principal. When `CLAUDE.md` or a direct user instruction conflicts with a skill body, follow the user. Rigid skills carry an italicized override note near the top of their body pointing at `CLAUDE.md` § Instruction precedence — keep that note on every rigid skill. The full hierarchy lives in the project's `CLAUDE.md`.
