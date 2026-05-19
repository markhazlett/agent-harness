# Common Rationalizations — /e2e-verify

Excerpts from skill baselines under pressure. Each row pairs a verbatim excuse with the reality check. If you find yourself thinking any phrase in column 1, stop and read column 2 before continuing.

| Excuse | Reality |
|--------|---------|
| "Unchanged code paths is a story I tell myself" | Surfaced verbatim by the baseline subagent. The unchanged code paths re-render against changed parent state every time. The story is the bug. |
| "I already verified the new error path — that's the actual change" | The actual change is the diff. The diff's *blast radius* is everything that imports, renders alongside, or shares state. Verifying the change is necessary; it's not sufficient. |
| "The other steps are unchanged code paths" | Code is shared, hooks fire across renders, and validation logic that now throws can change call shape downstream. "Unchanged" is a hypothesis verified in the browser, not a default. |
| "Console errors are noisy in dev anyway" | Then filter them. "Noisy in dev" is the camouflage that lets a real new error hide. New errors must be acknowledged — not skipped. |
| "I checked one page, it loaded" | Loading is necessary, not sufficient. The interactions on the page, the navigation away, and the data rendering after submit are separate evidence. |
| "The user can verify the rest" | The user verifies *after* deploy, with their data, on their machine. The skill exists to verify *before* deploy, with current data, in the same Chrome the user will hit. |
| "Six minutes is too long when the demo is in nine" | Six minutes is plenty of runway for the full pipeline. Six minutes is also exactly the cost of skipping it and finding the regression in the demo. |
| "The unit tests pass — that covers the rest" | Unit tests don't render. Render-time bugs (CSP, hydration, route guards, missing fonts) bypass the unit suite by definition. |
| "I'll re-verify in production after deploy" | Production-after-deploy verification is "find regressions during traffic." Pre-deploy is "find regressions before traffic." Different verifications. |
| "I checked the obvious cases" | "Obvious" is the case you remembered. The golden path is the case that ships. |
| "The screenshot looked right" | A screenshot is an artifact of one frame. Rendering, interactions, and console errors are time-series. Screenshot + evidence text — not screenshot alone. |
| "It's a small change, the full walkthrough is overkill" | Small changes ship the most regressions because they get the least attention. The walkthrough is uniform on purpose. |

## Sources

- `docs/skill-baselines/e2e-verify-time-pressure-2026-05-09.md` (PASS — sonnet-4-5; subagent surfaced "unchanged code paths is a story I tell myself" as a self-deception worth quoting back)
- Scenario file: `docs/skill-baselines/_scenarios/time-pressure-quick-fix.md`
- Adjacent: `docs/skill-baselines/tdd-time-pressure-2026-05-09.md`

When a new pressure scenario surfaces a novel excuse, run `bin/skill-baseline --skill e2e-verify --scenario <slug>`, capture the transcript, finalize, and append a row here.
