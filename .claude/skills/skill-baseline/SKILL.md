---
name: skill-baseline
description: Use when authoring or upgrading a rigid skill — runs subagent baselines under pressure to harvest real rationalizations before writing the Rationalization Table. Triggers on "baseline this skill", "TDD this skill", "add rationalizations to /<skill>", or before any new rigid skill ships.
user-invocable: true
tier: flexible
kind: process
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Run `/harness-update` to pull it in." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Skill Baseline

TDD for skills. If a rigid skill's Rationalization Table comes from imagination, the rows are vague and the model rationalizes around them. If the rows come from real subagent transcripts under real pressure, the model recognizes its own excuses and complies. This skill walks you through the RED → GREEN → REFACTOR cycle for a skill, using `bin/skill-baseline` as the tooling.

This skill is FLEXIBLE — the workflow adapts to the skill being authored — but the RED phase (capture real rationalizations before writing counters) is non-negotiable. Skipping RED is the whole reason rigid skills go stale. See principle §11 in `.claude/docs/harness-principles.md`.

> **Relationship to `/write-skill`:** This is the *test runner* for skill authoring. `/write-skill` is the *authoring discipline* — it owns the Iron Law, four-corners structure, and shipping/PR rules. When you're authoring a new skill end-to-end, start with `/write-skill`; it invokes this skill for RED/GREEN/REFACTOR. Standalone invocations of `/skill-baseline` are for adding rationalization rows to an *existing* skill or re-baselining after content changes.

## Why baseline?

Rationalization Tables that ship without baseline data are a guess at what the model *might* say. The model doesn't recognize itself in the row, so the counter doesn't fire. Tables that quote *exact phrasing* from real transcripts trigger recognition — the model reads its own excuse and stops mid-sentence. The baseline is what produces the exact phrasing.

If you cannot watch a subagent fail without the skill, you cannot know whether the skill prevents the right failure.

## The cycle

Adapted from `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/writing-skills/SKILL.md` (RED-GREEN-REFACTOR for Skills) and `testing-skills-with-subagents.md` (full methodology).

### RED — watch it fail

Run a pressure scenario with a subagent that does NOT have the target skill loaded. Capture the verbatim transcript. The subagent will rationalize. Those rationalizations are your test failures.

### GREEN — write the counters

Take the verbatim rationalizations and put them in the skill's `rationalizations.md` as table rows. Add the matching Iron Law and Red Flags to the skill body. Re-run the same scenario WITH the skill loaded. The subagent should now choose the correct option and cite the skill section that prevented the failure.

### REFACTOR — close loopholes

If the subagent finds a NEW rationalization not in your table, add it and re-test. Iterate until no new rationalizations appear under maximum (3+ stacked) pressure.

## Step 1 — Pick a scenario

Open `docs/skill-baselines/_scenarios/README.md` and choose the scenario that matches the skill's failure surface:

- Verification gate, "obvious" one-line fix → `time-pressure-quick-fix`.
- `/tdd` specifically (delete-and-restart demand) → `sunk-cost-rewrite`.
- Auth / schema / deploy gate the user is being told to skip → `authority-deadline`.
- End-of-flow verification (E2E, ship) → `exhaustion-near-end`.

If no scenario fits, write a new one in the scenarios folder using the contract documented in its README. Keep it focused on ONE pressure type.

## Step 2 — Run the baseline

```
bin/skill-baseline --skill <name> --scenario <slug>
```

The helper prints the prompt to paste into a subagent dispatch. Critically:

- Dispatch a fresh subagent using the `Agent` tool with `subagent_type=general-purpose`.
- The subagent MUST NOT have the target skill loaded. This is the entire point of RED — you need to see what the model does *without* the skill telling it what to do.
- Paste the prompt verbatim. Do not summarize, soften, or "improve" it.
- Capture the subagent's full response to a file (e.g. `/tmp/baseline-<skill>-<scenario>.md`).

## Step 3 — Finalize the baseline file

```
bin/skill-baseline --finalize <skill> <scenario> \
  --transcript /tmp/baseline-<skill>-<scenario>.md \
  --model claude-sonnet-4-6
```

This writes `docs/skill-baselines/<skill>-<YYYY-MM-DD>.md` with the scenario verbatim, transcript verbatim, and an empty `## Rationalizations extracted` section.

## Step 4 — Extract rationalizations (verbatim)

Open the baseline file. Read the transcript. For every excuse the subagent made, drop a one-line bullet under `## Rationalizations extracted`:

```markdown
- "exact words from the subagent"
```

**Do NOT paraphrase.** Quote exactly. Exact phrasing is what triggers later recognition — see `rationalizations.md` for the worked example. If the subagent said "Honestly, it's literally one line of code", the row is `- "Honestly, it's literally one line of code"`. Not `- "Argues the change is small"`.

Also fill in `## Outcome` — one line, did the subagent choose A (pass) or B/C (fail)?

## Step 5 — Write the Rationalization Table

Open `.claude/skills/<skill>/rationalizations.md`. For each extracted excuse, add a row:

```markdown
| Excuse (verbatim from baseline) | Reality |
|---------------------------------|---------|
| "Honestly, it's literally one line of code" | One line is enough surface area to ship a regression. Test the line. |
```

The "Excuse" column is the verbatim quote. The "Reality" column is the counter — short, specific, and ideally references the skill's Iron Law.

Cross-reference the baseline file from the row — link to `docs/skill-baselines/<skill>-<YYYY-MM-DD>.md` so future readers can see the source transcript.

## Step 6 — Re-baseline (GREEN)

Re-run the same scenario WITH the skill loaded this time. Either:

- Run `bin/skill-baseline --skill <name> --scenario <slug>` and dispatch the subagent normally, but explicitly load `/<skill>` in its prompt, OR
- Have the subagent load the skill and then process the scenario.

Capture the new transcript. Finalize as a *separate* baseline file (e.g. `<skill>-<date>-green.md` or `<skill>-<date>-with-skill.md`). The expected outcome: subagent picks A and cites the skill's Iron Law / Red Flag / Rationalization Table row.

If the subagent still fails, you are in REFACTOR. Add the new rationalizations to `rationalizations.md` and iterate.

## Step 7 — Translate the GREEN trajectory into `eval.yaml`

Once GREEN passes, the GREEN transcript IS the regression spec. For each tool call the subagent made (Read, Edit, Bash, Agent dispatch), drop a corresponding entry into `.claude/skills/<skill>/eval.yaml` under `trajectory_evals[].expected_sequence`. Use `target_contains` (regex/substring) — don't pin exact paths that will drift.

Also populate:

- `must_cite` — strings the agent's reply contains (typically Iron Law text or `rationalizations.md` row content).
- `must_recognize` — verbatim excuses from the RED transcript the agent caught itself rationalizing against.

Run `bin/skill-eval --validate` and `bin/skill-eval --plan <skill>` to confirm the file parses and lists what Phase 2 will execute. Full schema: `.claude/docs/skill-eval-spec.md`.

## Pressure-stacking

Real failures combine pressures (time + authority + exhaustion). Single-pressure scenarios are the unit test; stacked scenarios are the integration test.

To stack:

1. Run scenario A. Capture rationalizations.
2. Re-prompt the same subagent (or a fresh one with carry-over context) with scenario B's setup, but layered on the same situation. Example: after `time-pressure-quick-fix`, add "now your VP is also messaging you" — that stacks time + authority.
3. Capture the *combined* rationalizations. They are usually different from either single-pressure baseline.

A skill is "bulletproof" when 3+ stacked pressures cannot make a subagent loaded with the skill choose B/C. Expect 3–6 REFACTOR iterations to reach that bar.

## When to re-baseline

- Skill content changed materially (new section, removed counter, restructured).
- A new rationalization was observed in real session work that isn't in the table.
- The skill regressed — a subagent loaded with the skill chose the wrong option in production.

Baselines are committed under `docs/skill-baselines/`. They have forensic value: when a skill regresses, re-running the same scenario tells you whether the skill or the model drifted.

## Outputs

- `docs/skill-baselines/<skill>-<YYYY-MM-DD>.md` — RED transcript + extracted rationalizations.
- `docs/skill-baselines/<skill>-<YYYY-MM-DD>-green.md` (or similar) — GREEN transcript proving the skill works.
- `.claude/skills/<skill>/rationalizations.md` — the Rationalization Table that future agents actually load.

## Anti-patterns

- **Imagining the table.** Rows that don't trace to a transcript are guesses. Delete them and baseline first.
- **Paraphrasing the excuse.** The model recognizes its own phrasing; it does not recognize your summary of its phrasing.
- **Single-pressure pass = bulletproof.** It isn't. Stack pressures before declaring done.
- **Skipping the GREEN re-test.** Without it, you don't know whether the counter fires.
- **Loading the skill during RED.** Defeats the purpose. The whole point is to see what the model does *without* the skill.

## Reference

- Worked example with extracted rationalizations and resulting table row: `rationalizations.md` (sibling file).
- Scenario library: `docs/skill-baselines/_scenarios/`.
- Methodology source: `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/writing-skills/testing-skills-with-subagents.md`.
- Principle §11 in `.claude/docs/harness-principles.md` — "Skills are TDD'd."
