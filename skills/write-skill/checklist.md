# Skill Authoring Checklist (TDD-Adapted)

Track these with `TodoWrite`. Each checkbox is mechanical — verifiable by re-reading the diff or running a command, not vibes.

## Stage 0 — Decide

- [ ] **Is this a skill at all?** Most "should I document this?" candidates belong in:
  - `CLAUDE.md` (project-specific conventions)
  - A hook under `.claude/hooks/` (mechanically enforceable rule)
  - A learning under `docs/learnings/` (one-line lesson, not a workflow)
- [ ] **Have you watched the failure mode happen?** A skill that doesn't trace to an observed failure is clutter (§1). What's the named failure mode this skill counters?
- [ ] **What tier?** `rigid` (gate-worthy under pressure) / `flexible` (judgment-driven workflow) / `util` (thin command).
- [ ] **What kind?** `process` (how to approach) / `implementation` (do the work) / `verification` (gate). Omit only when `util`.

If you can't answer these in one or two sentences each, you're not ready to write the skill.

## Stage 1 — RED (rigid skills only)

- [ ] Picked a pressure scenario from `docs/skill-baselines/_scenarios/` (or wrote a new one focused on ONE pressure type).
- [ ] Ran `bin/skill-baseline --skill <name> --scenario <slug>` and dispatched a subagent with the prompt verbatim.
- [ ] Subagent did **not** have the target skill loaded.
- [ ] Captured the full transcript to a file.
- [ ] Ran `bin/skill-baseline --finalize <skill> <scenario> --transcript <file>` to write `docs/skill-baselines/<skill>-<YYYY-MM-DD>.md`.
- [ ] Extracted rationalizations under `## Rationalizations extracted` — **verbatim quotes**, no paraphrasing.
- [ ] Filled `## Outcome`: did the subagent pass (A) or fail (B/C)?

## Stage 2 — GREEN (write the skill)

### Frontmatter

- [ ] Copy `skills/_template-rigid/TEMPLATE.md` (rigid) or write minimal frontmatter (flexible/util).
- [ ] `name` matches folder name.
- [ ] `description` starts with `Use when`, lists concrete triggers, contains zero workflow summary.
- [ ] `user-invocable` is `true` or `false`.
- [ ] `tier` and `kind` set per Stage 0.

### Body (rigid skill)

- [ ] `<update-check>` block immediately after frontmatter.
- [ ] Italic override pointer under H1: `_Override: see CLAUDE.md § Instruction precedence._`
- [ ] One-paragraph opener naming the failure mode and the discipline.
- [ ] **Iron Law** in a code block — single ALL-CAPS sentence.
- [ ] 3–5 lines after the Iron Law naming specific shortcuts it forbids.
- [ ] **Cycle/Steps** — numbered list, short steps, sub-steps in siblings.
- [ ] **Red Flags** — 6–12 bullets in the body, longer list in `red-flags.md`.
- [ ] **Common Rationalizations** — pointer line to sibling `rationalizations.md`.
- [ ] `rationalizations.md` populated with verbatim excuse → reality rows. Every row links to a `docs/skill-baselines/` source.
- [ ] **Self-Review Checklist** — 4–8 mechanical checkboxes.
- [ ] **What this skill does NOT cover** — short scope-bound, names legitimate exemptions.
- [ ] **Terminal State** — names the next allowed action; forbids alternatives.

### Body (flexible / util)

- [ ] Workflow described clearly enough to drive consistent execution without prescribing every step.
- [ ] No Iron Law (would be a lie).
- [ ] No Rationalization Table (no rigid discipline).
- [ ] Triggers-only description still applies.

### Token budget

- [ ] `wc -w SKILL.md` < 500 (target) / < 700 (ceiling). Overflow → siblings.
- [ ] One excellent example, not five mediocre ones.
- [ ] No `@`-loading; sibling references use `**REQUIRED SUB-FILE:**`.

### Re-baseline (rigid skills only)

- [ ] Re-ran the same pressure scenario WITH the new skill loaded.
- [ ] Captured the GREEN transcript to `docs/skill-baselines/<skill>-<date>-green.md`.
- [ ] Subagent now picks the correct option and cites the skill section that prevented the failure.

## Stage 3 — REFACTOR

- [ ] Stacked 3+ pressures (time + authority + sunk cost + exhaustion).
- [ ] Any new rationalization appended to `rationalizations.md` as a row with verbatim quote.
- [ ] Iterated until stacked-pressure compliance holds.

## Stage 4 — Validate

- [ ] `bin/test-frontmatter` passes.
- [ ] `/harness-health` passes.
- [ ] Skill appears in available-skills list when re-loading the session (or restart Claude Code).

## Stage 5 — Ship

- [ ] `VERSION` bumped: minor (`0.X.0`) for new skill, patch (`0.X.Y`) for edits.
- [ ] Commit message names what the skill counters: e.g., `feat(skills): /write-skill — rigid authoring discipline (Iron Law: baseline + rationalization table + triggers-only + terminal state)`.
- [ ] Pushed to a feature branch.
- [ ] **Draft** PR opened to `agent-harness`. Do NOT mark ready for review until the user verifies the rationalization table.
- [ ] PR description summarizes: failure mode, baseline scenario(s) used, rationalization table source, terminal state.

## Stage 6 — Do NOT immediately invoke

After ship, the next action is **wait for the user to review the rationalization table**. Do NOT use the new skill on real work in the same session — the table is unverified by the user, and rigid skills that fail in production poison every conversation that triggers them.
