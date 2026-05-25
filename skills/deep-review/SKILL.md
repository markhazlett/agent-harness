---
name: deep-review
description: Use when the user says "/deep-review", "deep review", "thorough review", or wants the deepest possible code review before pushing a branch.
user-invocable: true
tier: rigid
kind: verification
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Run `/harness-update` to pull it in." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Deep Review

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

The deepest pre-ship code review tier. Runs a 5-stage pipeline (SCAN → DISPATCH → TRIAGE → REVALIDATE → SYNTHESIZE) across 15 dimensions in parallel, then delivers the result as a code review — not a severity-graded incident report. Advisory only; does not auto-fire from `/ship` or `/pre-deploy`. Optimized for completeness over speed; typical mid-PR cost is $10–15 and 3–8 minutes wall-clock.

## How the review reads

The output should feel like a senior engineer pair-reviewing beside the author — not a SOC ticket. That means:

- **Binary calibration only: `(blocking)` vs `(non-blocking)`**. No CRITICAL/HIGH/MED/LOW/NIT ladder. The `(blocking)` bar is borrowed from Google's code-review standard: block only if shipping the change as-is would worsen overall code health in a way the author would acknowledge once shown. Everything else is `(non-blocking)`.
- **Conventional Comments vocabulary** for finding kinds: `issue` / `suggestion` / `question` / `nit` / `praise` / `thought` / `chore` / `note`. See `pipeline.md` for the per-kind contract.
- **Conversational tone**: ask questions where there's genuine uncertainty, anchor on the author's intent before suggesting alternatives, use I-statements for opinion, pair every `issue` with a `suggestion`, praise the non-obvious specifically (and sparingly).
- **Default-positive verdict**: "Ship it" / "Address blocking items first" / "Substantial concerns" — modeled on Google's `Approve with non-blocking comments` default.

## The Iron Law

```
NO REVIEW VERDICT WITHOUT EVERY DIMENSION REACHING PASS/WARN/FAIL/N/A AND EVERY PIPELINE STAGE EXECUTED
```

No exceptions:
- Spot-checking is not depth. The 15-dimension fan-out IS the audit.
- N/A requires a one-line justification naming what the dimension would have caught and why this diff has no surface for it. "Probably doesn't apply" is not a verdict.
- Subagent summaries are inputs to the orchestrator's judgment, not the verdict itself (harness §27 — "trust but verify"). The orchestrator reads at least one cited `file:line` per `(blocking)` finding directly.
- Triage filters; revalidate confirms; synthesis ranks. Skipping any stage collapses depth into noise.

## Gate Sequence

**REQUIRED SUB-FILE:** Read `pipeline.md` for the full 5-stage spec (routing table, prompt assembly, kind vocabulary, report skeleton).

1. **Stage 1 — SCAN.** Run `bin/deep-review-scan`; parse the JSON manifest (diff, gates, conventions, scopes with exemplars).
2. **Stage 2 — DISPATCH.** Emit ONE message with N parallel `Agent` tool-use blocks per the routing table in `pipeline.md`. Each dispatch carries the dim charter, PROJECT CONTEXT, CONVENTIONS (from SCAN), REFERENCE EXEMPLARS (from SCAN), scope packet, FP profile. Delegate `security`, `db`, `langgraph` to their existing skills.
3. **Stage 3 — TRIAGE.** Dispatch `subagent_type: triage` (haiku) over all findings. Apply per-FP-profile conviction thresholds + dedup. Dedup keeps the highest-impact citation per `file:line` (blocking > non-blocking issue > suggestion > question > nit).
4. **Stage 4 — REVALIDATE.** Dispatch `subagent_type: revalidator` (opus) over every `(blocking)` finding AND every load-bearing `(non-blocking) issue` (conviction ≥ 0.7) from the high-FP dims `{security, performance, concurrency, structural, error-handling, deps, dead-code}`. Apply CONFIRMED/DISPUTED/FIXED verdicts.
5. **Stage 5 — SYNTHESIZE.** Build the report per `pipeline.md`'s skeleton (Summary → Before merge → Worth thinking about → Worth calling out → coverage matrix → N/A → pipeline notes). Save to `docs/deep-reviews/<YYYY-MM-DD>-<branch-slug>.md`. Run `bin/deep-review-validate` against it — must exit 0. Offer fixes via the `AskUserQuestion` tool.

## Red Flags — STOP

- "The diff is small, just check the obvious ones."
- "Most dimensions don't apply, skip them."
- "Triage already filtered, revalidate is overkill."
- "Subagent says PASS — accept it."
- "We've shipped 100 PRs without this; the bar is too high."
- "Condense the report to fit context — drop the non-blocking comments."
- "Run dimensions sequentially to save context — don't fan out."
- "I read the subagent's summary; reading the code is theatre."
- "Mark this `(blocking)` because it's important" — without naming the code-health regression that ships if it isn't addressed.
- "Skip the praise section, it's filler" — non-obvious praise is what makes the review feel like a colleague rather than a linter.
- Marking the `security` or `error-handling` dimension N/A without justification.
- Producing a verdict without saving the report to `docs/deep-reviews/`.

**All of these mean: stop. Run the missing stage / dispatch / verification before any verdict.**

## Tone discipline (apply during synthesis)

Borrowed from Hauer's "OIR" (Observation → Impact → Request) and Greiler's review-guidelines work:

- **Talk about the code, not the author.** "This branch has three exit paths" — not "you wrote this with three exits."
- **Ask, don't assert, when uncertain.** "What happens if `userId` is null here?" beats "This is broken."
- **Explain the *why*, every time.** A `suggestion` without reasoning reads as taste. Cite the cost of NOT changing.
- **Anchor on author's intent first.** State your understanding of the goal before proposing alternatives.
- **Pair every `issue` with a `suggestion`.** Never leave the author guessing the remedy.
- **Praise the non-obvious.** Generic praise ("nice work") deflates. Specific praise ("the bounded-channel choice here is exactly right for the backpressure case") lands.
- **Reserve `(blocking)` for code-health regressions.** Not preferences, not style, not "I'd have done it differently." If you cannot name what ships broken, it's `(non-blocking)`.
- **Don't stack suggestions into a rewrite.** Cap to the items that actually matter; defer the rest to a follow-up issue.

## Common Rationalizations

**REQUIRED SUB-FILE:** Read `rationalizations.md` if you find yourself making excuses. The verbatim-excuse-to-reality table is harvested from `/skill-baseline` runs against the unaided subagent.

> **Note:** `rationalizations.md` currently contains a placeholder structure (section headers + scenario references). A follow-up PR will populate it with verbatim rationalizations from real RED-phase baseline transcripts captured against scenarios in `docs/skill-baselines/_scenarios/deep-review-*.md`. Until then, the four "Universal counters" rows are the load-bearing protection.

## Self-Review Checklist

- [ ] Every one of the 15 dimensions produced a verdict (or N/A with one-line justification).
- [ ] All stage-2 dispatches went out as parallel `Agent` calls in a single message.
- [ ] Triage was run; conviction-below-threshold findings dropped (not just buried).
- [ ] Every `(blocking)` finding AND every high-FP-dim load-bearing `(non-blocking) issue` (conviction ≥ 0.7) went through revalidate; verdict is CONFIRMED / DISPUTED / FIXED.
- [ ] At least one `file:line` evidence quote read directly (not just from subagent summary) for each `(blocking)` finding.
- [ ] Report saved to `docs/deep-reviews/<date>-<slug>.md` AND `bin/deep-review-validate <path>` exits 0.
- [ ] Verdict line in TL;DR is one of: "Ship it" / "Address blocking items first" / "Substantial concerns" — not a graded severity total.
- [ ] Every `issue (blocking)` is paired with a concrete `suggestion`. If not, the review is incomplete.

Cannot check all boxes? You skipped the skill. Start over from the missing stage.

## What this skill does NOT cover

- **The cheap per-commit pass.** Use `/pre-deploy`, `/simplify`, or `/security-review` standalone for that. `/deep-review` is the deep tier.
- **Full-repo / module-wide audits.** Scope is always `main..HEAD`. Repo-wide deepsec-style scans are a future feature.
- **Penetration testing, threat modeling, runtime monitoring.** Same boundaries as `/security-review`.
- **GitHub PR review comments.** Use the built-in `/review` for that. `/deep-review` produces a local markdown report.
