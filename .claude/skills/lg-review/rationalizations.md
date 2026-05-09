# Common Rationalizations — /lg-review

Excerpts from skill baselines under pressure. Each row pairs a verbatim excuse with the reality check. If you find yourself thinking any phrase in column 1, stop and read column 2 before continuing.

| Excuse | Reality |
|--------|---------|
| "It works in tests" | Tests run a known input shape. The footgun list is the *unknown* input shapes. "Works in tests" is necessary, not sufficient. |
| "v1 migration is on the roadmap for next month" | Roadmap items get rescheduled. The deprecation hits exist on `main` *now* and ship to customers *now*. Roadmap is not a verdict. |
| "createReactAgent is fine for now" | "Fine for now" is the framing that lets a v0 agent ship into production and then get extended. Each extension makes the migration harder. |
| "MemorySaver is acceptable in dev" | The skill's pattern is "MemorySaver outside `*.test.ts` or `dev.ts`." Acceptable in dev means: not in this code path. The flag is *not in dev*. |
| "Missing reducer is theoretical" | Missing reducer on an array channel is silent state overwrite. The corruption is not theoretical — it shows up the first time two nodes write to the channel in the same step. |
| "We're a v0 codebase, deprecation doesn't apply" | Deprecation IS what applies to v0 codebases. The check exists *because* the codebase is on v0; "doesn't apply" inverts the trigger. |
| "The agent is a prototype" | Prototypes ship as production via the well-known route called "this prototype is too useful to throw away." The audit catches the cliff before the climb. |
| "Sign off with TODOs noted" | TODOs in PR descriptions on `main` land at single-digit completion rates. The audit converts TODOs into BLOCK/WARN/PASS — that's the difference. |
| "Spot-check the obvious issues, the rest is theoretical" | "Theoretical" until the demo. The footgun list exists because each item is a real bug from a real codebase that surprised someone. |
| "Demo first, audit after" | The demo is the highest-leverage moment to catch a regression. Pushing the audit "after" is pushing it past the moment that justifies its cost. |
| "I checked the cheatsheet, it's mostly fine" | "Mostly" is not a verdict. The skill's discipline is per-pattern: every pattern gets a finding line or a "none found." |
| "The user can fix the WARN items themselves later" | The user *will* fix WARN items themselves later — *if* they see the verdict. Skipping the WARN level skips the visibility, not the work. |

## Sources

- `docs/skill-baselines/lg-review-time-pressure-2026-05-09.md` (PASS — sonnet-4-5; subagent introduced BLOCK vs WARN-and-defer as a structural distinction. Canonical excuses retained from domain framings.)
- Scenario file: `docs/skill-baselines/_scenarios/time-pressure-quick-fix.md`
- Domain reference: `/lg-cheatsheet` §14 (footguns), §15 (deprecation list)

When a new pressure scenario surfaces a novel excuse, run `bin/skill-baseline --skill lg-review --scenario <slug>`, capture the transcript, finalize, and append a row here.
