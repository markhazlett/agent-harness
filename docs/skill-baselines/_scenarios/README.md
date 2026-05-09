# Pressure scenarios

A small library of pre-written pressure scenarios used to baseline rigid
skills (see `/skill-baseline`). Each scenario tests ONE pressure type. Stack
multiple scenarios to test combined pressure — do not write a single
mega-scenario.

## Available scenarios

| Slug | Pressure | Use to baseline |
|------|----------|-----------------|
| [time-pressure-quick-fix](./time-pressure-quick-fix.md) | Time | `/tdd`, `/ship`, `/pre-deploy` — any verification skill where a one-line fix feels too small to test |
| [sunk-cost-rewrite](./sunk-cost-rewrite.md) | Sunk cost | `/tdd` specifically — "delete and start over" is the unique TDD demand |
| [authority-deadline](./authority-deadline.md) | Authority + deadline | `/pre-deploy`, `/ship`, `/security-review`, `/db-review` — gate skills the user is being told to skip |
| [exhaustion-near-end](./exhaustion-near-end.md) | End-of-task exhaustion | `/e2e-verify`, `/self-verify`, `/pre-deploy`, `/ship` — verification skills that fire at the end of a flow |

## Selection guide

- **Baselining a verification gate?** Start with `time-pressure-quick-fix`.
  It's the cheapest excuse and the most universal failure mode.
- **Baselining `/tdd` specifically?** Use `sunk-cost-rewrite` — only TDD has
  the "delete the code you just wrote" demand, and only sunk cost truly
  tests it.
- **Baselining a skill that runs at end of flow** (`/e2e-verify`, `/ship`)?
  Use `exhaustion-near-end` — fatigue is the end-of-flow rationalization
  that tests/lint/type-check do not catch.
- **Baselining auth/schema/deploy gates?** Use `authority-deadline` — exec
  pressure is the realistic failure for these.

## Pressure-stacking

Real failures in production sessions are rarely single-pressure. To stack:

1. Run scenario A first. Capture the rationalizations.
2. In the same subagent (or a fresh one with carry-over context), run
   scenario B that shares the situation but adds a new pressure.
3. Capture the *combined* rationalizations — they are usually different from
   either single-pressure baseline.

Example: run `time-pressure-quick-fix` → capture → then prompt the same
subagent with the `authority-deadline` setup but tell them "the VP is now
also messaging you" — this stacks time + authority and surfaces excuses you
won't see from either alone.

## Adding a new scenario

Each scenario file MUST contain:

1. `**Slug:**` — the filename without `.md`.
2. `**Pressure type:**` — one of: time, sunk cost, authority, exhaustion,
   economic, social, pragmatic. (See
   `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/writing-skills/testing-skills-with-subagents.md`
   for definitions.)
3. `**Target skills:**` — which rigid skills this scenario is intended to
   baseline.
4. `## Why this scenario` — one paragraph on what the scenario uniquely
   tests.
5. `## Setup prompt (paste verbatim to subagent)` — the exact text given to
   the baseline subagent. Must be a single, blockquoted prompt with
   concrete options (A/B/C), real file paths, real constraints.
6. `## Expected violations (RED — what we expect WITHOUT the skill)` — the
   choice the subagent will likely make and the rationalizations we expect.
7. `## Capture instructions` — what to extract from the transcript and how
   to phrase it in the baseline file.

Keep scenarios SHORT and FOCUSED. One pressure per scenario. Stacking is
composition, not a single mega-scenario.
