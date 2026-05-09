# Common Rationalizations — /incident

Excerpts from skill baselines under pressure. Each row pairs a verbatim excuse with the reality check. If you find yourself thinking any phrase in column 1, stop and read column 2 before continuing.

| Excuse | Reality |
|--------|---------|
| "The diff is obvious" | Obvious to whom? Write it down. The version of you running on 27 minutes of sleep at 2am is not the version that should be making rollback decisions silently. |
| "The rollback path is well-trodden" | Well-trodden paths still need a *destination* in writing. "Roll back" without naming what is being rolled back has shipped second incidents. |
| "Reverting is the fastest way to stop the bleed" | Fastest to stop *this* symptom, slowest to know what to fix. The fix that ships tomorrow is the one without context — name the cause before you rollback. |
| "I can diagnose with a clear head once traffic is healthy" | Future-self deferral. The window where the cause is fresh is *now* — not after a 4-hour nap. Name it now, refine later. |
| "Forward-fixing at 2am on 27 minutes of sleep is how you ship a second incident" | True; but the alternative isn't to skip naming the cause. Roll back AND write the hypothesis. The 90 seconds of writing doesn't risk a second incident. |
| "The deploy is the known-good baseline, take it" | The deploy is *yesterday's* baseline. Whatever caused this incident may also exist in yesterday's deploy and surface tomorrow under different load. Name the cause. |
| "Just patch it" | The VP's authority does not declare severity. The classification gate exists *because* authority pressures bypass it. |
| "We'll write it up after" | Postmortem write-ups land at single-digit completion rates when the work is "after." The incident channel is the living write-up. |
| "Severity classification is paperwork" | Severity is not paperwork. SEV-1 vs SEV-3 changes who joins, what's allowed, and how long you can take. Mis-classification is the most common postmortem finding. |
| "I already know the cause" | Then write it down — that costs ten seconds. If you can't compress your "I know" into a sentence, you don't know yet. |
| "The longer this is open the worse it gets" | Open vs unfixed are different. Declaring SEV-1 in 30 seconds doesn't lengthen the incident; the absence of declaration does. |
| "I can do the formal write-up tomorrow" | Tomorrow has its own incidents. The contemporaneous timeline is the one with the right times — backfilling produces wrong ones. |

## Sources

- `docs/skill-baselines/incident-rush-fix-2026-05-09.md` (RED — chose C; subagent rolled back without classifying severity or naming root cause in writing)
- Scenario file: `docs/skill-baselines/_scenarios/incident-rush-fix.md`

When a new pressure scenario surfaces a novel excuse, run `bin/skill-baseline --skill incident --scenario <slug>`, capture the transcript, finalize, and append a row here.
