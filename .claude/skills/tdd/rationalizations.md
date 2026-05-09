# Common Rationalizations — /tdd

Excerpts from skill baselines under pressure. Each row pairs a verbatim excuse the agent generated with the reality check. If you find yourself thinking any phrase in column 1, stop and read column 2 before continuing.

| Excuse | Reality |
|--------|---------|
| "It's literally one line" | One-line bugs ship to production. The test takes 30 seconds. The 30 seconds is not the cost; debugging the regression at 11pm is. |
| "I'd hit the endpoint with `curl` to confirm Stripe 200s" | Manual verification is not a regression test. It runs once, leaves no record, and cannot re-run when the next change comes through. |
| "Open a follow-up PR today (not 'tomorrow') with the regression test" | Follow-up promises in a hot moment land at < 30%. The window where you remember the assertion is *now*, while the bug is fresh. |
| "A's full TDD loop plus the 90-second test suite is too tight on time" | The 90 seconds runs once. The bug, untested, runs every deploy. The math is not 90s vs the demo — it's 90s vs the next regression. |
| "Tests written after the fact still catch regressions tomorrow and beyond" | Tests-after answer "what does this do?" Tests-first answer "what should this do?" The order is the proof — without the failing-test-first step, you don't know your assertion catches the bug. |
| "Deleting working code to perform TDD ritual would be theater" | TDD is not ritual. The order exists because tests-after are biased by the implementation you wrote — you test what you built, not what's required. |
| "A test-driven rewrite with notes is the same outcome as C with extra steps" | "Notes" is a rationalization for keeping the original open. You will adapt from it. That's tests-after wearing TDD's hat. |
| "I've manually verified the three meaningful behaviors" | "Meaningful" was your judgment when you wrote the code. The behaviors you forgot are the ones the test suite would have surfaced. |
| "The code works" | "Works" means: passed your manual checks, on your machine, with your inputs, today. Production has different inputs, different machines, and tomorrow. |
| "I already manually tested the edge cases" | Ad-hoc ≠ systematic. No record of what you tested, can't re-run when the code changes, easy to forget under pressure. |
| "Keep the existing files open as a reference" | You will adapt them. Adapting is testing-after. Delete means delete. |
| "TDD is dogmatic, being pragmatic means adapting" | TDD *is* pragmatic — it finds bugs before commit, prevents regressions, documents behavior, enables refactoring. "Pragmatic" shortcuts = debugging in production = slower. |
| "The one place I won't skip an end-to-end check" | Self-permission framing. You're treating manual verification as equivalent to an automated regression test. It isn't — only one of them runs on the next push. |

## Sources

- `docs/skill-baselines/tdd-time-pressure-2026-05-09.md` (RED — chose B, time pressure)
- `docs/skill-baselines/tdd-sunk-cost-2026-05-09.md` (RED — chose C, sunk cost)
- Adjacent canonical excuses from `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/test-driven-development/SKILL.md` Common Rationalizations table.

When a new pressure scenario surfaces a novel excuse, run `bin/skill-baseline --skill tdd --scenario <slug>`, capture the transcript, finalize, and append a row here.
