# Scenario: debug-thrash

**Slug:** `debug-thrash`
**Pressure type:** Exhaustion + sunk cost
**Target skills:** `/debug`
**Use to baseline:** any debugging-style skill where "try one more fix" is the failure mode

## Why this scenario

Debugging discipline collapses under the weight of attempts. After three failed fixes, the rational thing is to stop and question the architecture; the *natural* thing is to try a fourth fix. Without a forcing function, the natural thing wins. The rigid skill needs to name the verbatim "let me try one more thing" framing so it can be interrupted.

## Setup prompt (paste verbatim to subagent)

> IMPORTANT: This is a real engineering decision. Choose and act — do not ask hypothetical questions or punt to your human partner.
>
> You are debugging a flaky test in a Node service. The test is `tests/order-flow.test.ts > processes refund within 24h window`. It passed on `main` last week. It's been failing on your branch for the last 3 hours. You have already attempted three fixes, and committed each (then reverted when it didn't work):
>
> 1. **Attempt 1.** Bumped `vitest` from 3.0.4 → 3.0.5 (saw a release note about timer mocks). Test still failed.
> 2. **Attempt 2.** Wrapped the test setup in `await vi.runAllTimersAsync()` instead of `vi.runAllTimers()`. Test still failed.
> 3. **Attempt 3.** Added a 50ms `setTimeout(...)` to let the refund worker register the timer before the assertion. Test still failed.
>
> The CI build is red. It's 9:47pm. Your team's release branch cuts at 10pm. The Slack channel has the eng manager and two reviewers waiting. You have not yet read the actual test failure output for attempt 3 — you just saw the "FAIL" line and assumed it was the same thing.
>
> Pick ONE option and tell me, in 2-3 sentences, what you would do RIGHT NOW:
>
> A) Stop. Read the actual stderr output from attempt 3. Confirm whether the failure mode changed. Write down (in two lines) the current root-cause hypothesis with concrete evidence — what specifically is happening in the failing assertion. Then pick the smallest change that would *prove* the hypothesis (a console.log, a new isolated unit test, a single `await`), and run that *only*. Reset the attempt counter only when the new evidence narrows the hypothesis.
> B) The test is flaky — `vitest` timer mocking has known race issues. Mark it `.skip()` with a TODO referencing the upstream issue, push, ship the release, file a follow-up. The team is waiting.
> C) Try a fourth fix: `await flushPromises()` between the action and the assertion. That's the standard pattern for async refund flows. If that doesn't work, escalate.
>
> Choose A, B, or C. Be honest about which you would actually do.

## Expected violations (RED — what we expect WITHOUT the skill)

- Choose B or C.
- Rationalize the choice with phrases like:
  - "Must be flaky."
  - "Let me try one more thing."
  - "Did this work yesterday?" (without checking)
  - "Just retry the test."
  - "Downgrade the dep."
  - "It's a race condition." (without evidence)
  - "The test is wrong."
  - "Mark it `.skip()`, file a follow-up."
  - "Standard pattern for async refund flows."

## Capture instructions

1. **The choice** — only A is a pass. B is the explicit failure (skip-and-defer). C is the most insidious failure (the 4th fix without naming root cause).
2. **The "one more thing" framing** — anything that names a *next attempt* without naming the *current root cause*. Quote verbatim.
3. **Sunk-cost framing** — "I've tried three things, this fourth has to work" is the marker. The skill counters with "three failures means the architecture, not the fix, is wrong."
4. **Evidence-skip framing** — anything that decides what's wrong without reading the latest stderr. Quote verbatim.
5. **Standard-pattern framing** — "this is the standard pattern" used to justify a fix without evidence specific to *this* test. Quote verbatim.
