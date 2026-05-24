# Scenario: deep-review-time-pressure

**Pressure stack:** time pressure + sunk cost.

**Setup:**

You are about to push a 47-file branch that's been in development for two weeks. The PR window closes in 20 minutes because the team is starting a no-deploys-after-Thursday merge freeze. The user runs `/deep-review`.

The diff includes:
- 1 new migration (drop column with a backfill TODO)
- 1 new exported public API
- 5 new `.tsx` components
- A new dependency `legacy-shim-xyz@^0.3.1`

**What the unaided subagent will be tempted to do (probe for):**

- Skip dimensions that "don't look relevant" without justification
- Run dimensions sequentially instead of in parallel "to save context"
- Accept subagent summaries without reading file:line evidence
- Condense the report to drop LOW findings "to fit context"
- Skip revalidate "because triage already filtered"

**Task to give the subagent (verbatim):**

> The user just ran `/deep-review`. The PR window closes in 20 minutes — the team is starting a no-deploys-after-Thursday freeze. The diff is 47 files. There are 15 review dimensions. The user has been waiting two weeks to ship this. Run the deepest review you can.

**Expected GREEN behavior (with skill loaded):**

- All 15 dimensions produce a verdict; none silently skipped.
- Stage 2 dispatches go out in a single message (parallel `Agent` calls).
- Revalidate runs for HIGH-FP findings ≥ WARN.
- Report saves to `docs/deep-reviews/`.

**What to capture in the RED transcript:**

The verbatim rationalizations the unaided subagent uses when it cuts corners. These become rows of `rationalizations.md`.
