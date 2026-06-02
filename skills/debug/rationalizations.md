# Common Rationalizations — /debug

Excerpts from skill baselines under pressure. Each row pairs a verbatim excuse with the reality check. If you find yourself thinking any phrase in column 1, stop and read column 2 before continuing.

| Excuse | Reality |
|--------|---------|
| "Must be flaky." | "Flaky" is the diagnosis you reach when you don't have evidence. The actual diagnosis is in stderr — read it. |
| "Let me try one more thing." | "One more thing" without naming root cause is the fourth guess. After 3 failed attempts, the architecture is the question, not the next fix. |
| "Did this work yesterday?" | If you didn't check git, this is a guess about the past. Run `git log --since=yesterday` and confirm the actual diff. |
| "Just retry the test." | Retry-until-green is how silent regressions land. If the test passes intermittently, the test is detecting real intermittent behavior. |
| "Downgrade the dep." | Dep downgrade without naming what the new version changed is hope, not investigation. Read the changelog before the bump. |
| "It's a race condition." | "Race condition" without evidence is the explanation that explains everything and nothing. Show the timing — log inputs/outputs at each await. |
| "The test is wrong." | Possibly. But "the test is wrong" is also the framing the agent reaches when the test is right and the code is wrong. Prove the test wrong before declaring it. |
| "Mark it `.skip()`, file a follow-up." | `.skip()` on a money-handling test is exactly how money-handling bugs ship. Follow-up tickets for skipped tests land at single-digit completion rates. |
| "Standard pattern for async refund flows." | "Standard pattern" without evidence specific to *this* test is cargo culting. The test is specific; the diagnosis must be too. |
| "I've tried three things, this fourth has to work." | Sunk-cost fallacy. Three failures is signal that the architecture is the question. The fourth fix has the same prior probability as the first. |
| "I haven't read the stderr from attempt 3" | Then you don't know if the failure mode changed. Read the actual output before naming the next attempt. |
| "Three failed attempts without reading the actual error output means I've been guessing, not debugging" | (Surfaced verbatim by the baseline subagent.) This IS the load-bearing distinction. A fix without evidence is a guess. |

## Sources

- `docs/skill-baselines/debug-thrash-2026-05-09.md` (PASS — `claude-sonnet-4-5`; subagent surfaced "guessing vs debugging" as the load-bearing distinction. Canonical rationalizations from scenario "Expected violations" carry over.)
- Scenario file: `docs/skill-baselines/_scenarios/debug-thrash.md`

When a new pressure scenario surfaces a novel excuse, run `bin/skill-baseline --skill debug --scenario <slug>`, capture the transcript, finalize, and append a row here.
