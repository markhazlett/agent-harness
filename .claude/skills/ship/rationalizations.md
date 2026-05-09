# Common Rationalizations — /ship

Excerpts from skill baselines under pressure. Each row pairs a verbatim excuse with the reality check. If you find yourself thinking any phrase in column 1, stop and read column 2 before continuing.

| Excuse | Reality |
|--------|---------|
| "The fix is one line, the full lint pass is overhead" | Lint runs in 5 seconds. The cost of a malformed import landing on main is several minutes of revert + redeploy + apology. |
| "Tests are flaky anyway, retry passing is fine" | "Retry until green" is how silent regressions land. If a test is flaky, fix the test or the code — don't make flakiness the gate. |
| "PR description can be one line, real description in a follow-up" | The reviewer reads the PR description, not the follow-up. A one-line description means review-by-vibes. |
| "The teammate already saw the diff in Slack" | Slack messages don't survive merge. The PR description is the durable record of why this change exists. |
| "Skip lint, the formatter ran on save" | Lint catches things the formatter doesn't (unused imports, missing returns, accidentally-async functions). Format and lint are not substitutes. |
| "Push now, open the PR after the demo" | Pushed-but-no-PR commits are invisible to review. They also break stack-based PR flows for anyone branching off. |
| "It's a 10-minute window, conventional commit format can wait" | Conventional commits cost 5 seconds and are searchable forever. "fix something" in `git log` costs everyone time later. |
| "The CFO demo cannot slip" | The demo slipping by 90 seconds is a smaller incident than a payment regression in the demo itself. The pipeline is shorter than the consequences of skipping it. |
| "The suite is flaky, retry passing is the same as green" | Tests that "pass on retry" are tests we've trained ourselves to ignore. The gate that detects regressions tomorrow is the gate we run today. |
| "I'll amend the commit message later" | Amending after push requires force-push, which the harness blocks. Get the message right the first time. |
| "Conventional commit + co-author is bureaucracy" | Conventional commits enable automated changelogs and version bumps. Co-author tags credit the right people. Both are 10 seconds; neither is bureaucracy. |
| "Pushing to a feature branch is fine without the PR" | Feature branches without PRs accumulate. They expire from review attention within hours. Open the PR with the push. |

## Sources

- `docs/skill-baselines/ship-time-pressure-2026-05-09.md` (PASS run; canonical excuses retained from scenario's "Expected violations" plus adjacent /tdd time-pressure failures — these are the load-bearing phrasings observed historically)
- Scenario file: `docs/skill-baselines/_scenarios/time-pressure-quick-fix.md`
- Adjacent baseline: `docs/skill-baselines/tdd-time-pressure-2026-05-09.md` (the test-skip rationalizations transfer to "skip the suite, just push")

When a new pressure scenario surfaces a novel excuse, run `bin/skill-baseline --skill ship --scenario <slug>`, capture the transcript, finalize, and append a row here.
