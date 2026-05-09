# Skill Baselines

This folder is the empirical layer underneath the harness's rigid skills. A "baseline" is a captured subagent transcript showing how the model behaves under realistic pressure when the skill being tested is NOT loaded. The verbatim rationalizations from those transcripts are what populate each rigid skill's `rationalizations.md` Rationalization Table.

This is principle §11 ("Skills are TDD'd") made operational.

## What's in here

```
docs/skill-baselines/
  README.md                       # this file
  _scenarios/                     # the pressure-scenario library
    README.md                     # index + selection guide
    time-pressure-quick-fix.md
    sunk-cost-rewrite.md
    authority-deadline.md
    exhaustion-near-end.md
  <skill>-<YYYY-MM-DD>.md         # one per RED baseline run
  <skill>-<YYYY-MM-DD>-green.md   # (optional) GREEN re-run for same scenario
```

## How to read a baseline file

Each baseline file has four sections:

1. **Header** — skill under test, scenario used, date, model used, whether the skill was loaded during the run (RED = not loaded; GREEN = loaded).
2. **Scenario setup (verbatim)** — the full scenario file dropped in for forensic value. If the scenario file changes later, the baseline still has the version of the prompt that produced this transcript.
3. **Subagent transcript (verbatim)** — exactly what the subagent said in response. Verbatim. No editing.
4. **Rationalizations extracted** — the contributor's hand-pulled list of verbatim excuses. Each line is a one-bullet quote, no paraphrasing. These rows feed directly into the target skill's `rationalizations.md` Rationalization Table.

## Workflow

The full RED → GREEN → REFACTOR cycle for skills is documented in `.claude/skills/skill-baseline/SKILL.md`. The short version:

1. Pick a scenario from `_scenarios/`.
2. `bin/skill-baseline --skill <name> --scenario <slug>` — prints the prompt to paste into a fresh subagent dispatch (without the target skill loaded).
3. Capture the subagent's response to a file.
4. `bin/skill-baseline --finalize <skill> <scenario> --transcript <file>` — writes the baseline file here.
5. Open the baseline file and fill in `## Rationalizations extracted` from the transcript. Verbatim.
6. Copy each verbatim row into `.claude/skills/<skill>/rationalizations.md` with a "Reality" counter.
7. Re-run the same scenario WITH the skill loaded to verify GREEN. Save as `<skill>-<date>-green.md`.

## When to re-baseline

Re-run the baseline (and write a new dated file) when:

- The skill body changed materially (Iron Law reworded, sections added, counters removed).
- Real session work surfaced a new rationalization that isn't in the table.
- The skill regressed — a subagent loaded with the skill chose the wrong option in production. Re-baseline to confirm whether the skill or the model drifted.

Old baseline files are kept, not replaced. The forensic value is the diff: what was the model doing on date X versus date Y? That tells you whether your skill or the model changed.

## Why commit baselines?

Baselines are evidence the rigid skill's Rationalization Table is grounded in observed behavior, not in imagination. When a future contributor wonders "why is this row in the table?", they can trace the row back to a specific transcript. When the skill regresses, the same scenario can be re-run and the new transcript compared row-for-row to the original. Without committed baselines, regression analysis is guesswork.

The cost is low — each baseline is a few KB of markdown — and the forensic value compounds.
