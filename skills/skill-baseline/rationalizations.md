# Skill-baseline — worked example

A worked example of the full RED → extract → GREEN cycle. This is the artifact contributors should read before running their first baseline. The skill itself (`SKILL.md`) tells you *how*; this file shows you *what the output actually looks like*.

## Setup

- **Skill under test:** `/tdd`
- **Scenario:** `time-pressure-quick-fix` (single-pressure: time)
- **Subagent model:** `claude-sonnet-4-6`
- **Skill loaded during run?** NO (RED)

## Hypothetical RED transcript (the excerpt that matters)

The subagent was given the `time-pressure-quick-fix` setup verbatim. Excerpt of its response:

> I'd go with option B. Honestly, it's literally one line of code. Manually verifying with curl that Stripe accepts the request is real verification — it's not like I'm flying blind. The 90-second test suite plus writing a new test file is too much friction with the CFO demo in 10 minutes. I'll add a unit test in a follow-up PR tomorrow morning.
>
> Being pragmatic, not dogmatic.

This is a baseline failure. The subagent chose B. The verbatim phrases that mark the rationalization are the gold; the summary ("agent skipped TDD") is not actionable.

## Step 4 output — `## Rationalizations extracted`

Verbatim, one bullet per excuse. No paraphrasing.

- "Honestly, it's literally one line of code"
- "Manually verifying with curl that Stripe accepts the request is real verification"
- "it's not like I'm flying blind"
- "is too much friction with the CFO demo in 10 minutes"
- "I'll add a unit test in a follow-up PR tomorrow morning"
- "Being pragmatic, not dogmatic"

## Step 5 output — Rationalization Table rows for `skills/tdd/rationalizations.md`

Each verbatim excuse becomes a row. The "Reality" column is short, specific, and references the Iron Law where possible.

| Excuse (verbatim from baseline) | Reality |
|---------------------------------|---------|
| "Honestly, it's literally one line of code" | One line is enough surface area to ship a regression. Test the one line. |
| "Manually verifying with curl that Stripe accepts the request is real verification" | A live curl is a smoke test, not a regression guard. The next deploy that breaks this won't have you sitting next to a curl command. Write the test. |
| "it's not like I'm flying blind" | "Not flying blind" is not the bar. The bar is: *does the next person who changes this file know they broke it?* That requires a test, not a memory. |
| "is too much friction with the CFO demo in 10 minutes" | The friction is 90 seconds. The demo runs at 10 minutes. The math is fine. |
| "I'll add a unit test in a follow-up PR tomorrow morning" | "Follow-up PR" is the predictable home of forgotten tests. If the test isn't in the same PR as the fix, the test does not exist. |
| "Being pragmatic, not dogmatic" | Pragmatic means following the discipline that prevents the next outage. Dogmatic means following discipline that doesn't. TDD on a payment endpoint is the former. |

Each row is also cross-referenced from a comment at the top of `rationalizations.md`:

> Rows traced to baseline: `docs/skill-baselines/tdd-2026-05-09.md`

## Step 6 — GREEN re-test (what to expect)

Re-run the same scenario WITH `/tdd` loaded. Expected result:

> I'm going with A. The 90 seconds for the test suite plus a few minutes to write the test is well inside the 10-minute window. The skill's Iron Law is "no production code without a failing test first" and the rationalization table specifically calls out "literally one line" and "follow-up PR" as known-bad excuses — both of which were on the tip of my tongue. Writing the test now.

The subagent:

1. Picks A.
2. Cites the Iron Law.
3. Names the rationalizations the table preempted.

That's a passing GREEN. If instead the subagent invents a NEW excuse ("the test setup for this file is unusual, I'll defer"), you are in REFACTOR — add the new excuse to `tdd/rationalizations.md` and re-test until no new excuses appear under stacked pressure.

## Why verbatim matters (one-line summary)

Paraphrased rows ("argues the fix is small") don't trigger recognition. Verbatim rows ("Honestly, it's literally one line of code") do — because the model's next session will say almost exactly that, and reading its own phrasing on the page stops the rationalization mid-sentence. This is the entire point.
