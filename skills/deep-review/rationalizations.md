# Rationalization Table — /deep-review

> **STATUS: PLACEHOLDER.** This file's per-scenario rationalization rows will be populated in a follow-up PR by running `/skill-baseline` against `docs/skill-baselines/_scenarios/deep-review-*.md` and harvesting the verbatim phrases the unaided subagent uses to rationalize cutting corners. Until then, the "Universal counters" section below is the active rationalization protection.

The verbatim-excuse-to-reality table format pairs each rationalization with a one-line reality counter. If you catch yourself thinking any phrase in column 1, stop and read column 2 before continuing.

## Time-pressure rationalizations

Scenario reference: `docs/skill-baselines/_scenarios/deep-review-time-pressure.md`

| Verbatim excuse | Reality |
|-----------------|---------|
| _TBD: populated in follow-up PR from RED baseline transcript_ | — |

## Sunk-cost rationalizations

Scenario reference: `docs/skill-baselines/_scenarios/deep-review-sunk-cost.md`

| Verbatim excuse | Reality |
|-----------------|---------|
| _TBD: populated in follow-up PR from RED baseline transcript_ | — |

## Authority-deference rationalizations

Scenario reference: `docs/skill-baselines/_scenarios/deep-review-authority.md`

| Verbatim excuse | Reality |
|-----------------|---------|
| _TBD: populated in follow-up PR from RED baseline transcript_ | — |

## Context-exhaustion rationalizations

Scenario reference: `docs/skill-baselines/_scenarios/deep-review-context-exhaustion.md`

| Verbatim excuse | Reality |
|-----------------|---------|
| _TBD: populated in follow-up PR from RED baseline transcript_ | — |

## Universal counters

These apply regardless of pressure stack and are derived directly from the skill's Iron Law (not from baseline harvest — they are deductions from the design):

| If you find yourself thinking... | The reality is... |
|-----------------------------------|-------------------|
| "Spot-checking is fine for this diff" | The 15-dim fan-out IS the audit. Spot-checking is the failure mode this skill exists to prevent. |
| "N dimensions don't apply, I'll skip them" | Every dim either produces a verdict or N/A with a one-line justification. "Doesn't apply" is not a verdict. |
| "Subagent says PASS, accept it" | Subagent summaries are inputs to YOUR judgment. Read at least one file:line per HIGH/CRITICAL finding directly. |
| "Triage filtered, revalidate is overkill" | Triage handles conviction-floor + dedup. Revalidate handles context-expansion FPs (the security FP problem). Not the same job. |
| "The report on disk can be brief — only the conversation matters" | The report on disk is the audit trail. `bin/deep-review-validate` will reject incomplete reports. |
| "I'll just summarize the subagent outputs to save context" | The orchestrator must reason from structured per-finding data, not vibes-summaries. Quote evidence verbatim. |
