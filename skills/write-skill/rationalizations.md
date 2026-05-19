# Common Rationalizations — /write-skill

Rows tagged `[native]` were extracted verbatim from baseline transcripts under `docs/skill-baselines/`. Rows tagged `[seeded]` originated in superpowers' `writing-skills` baseline (Anthropic) and have not surfaced in this harness's re-baselining pass; they are kept as a starter and flagged for future re-baselining.

If you find yourself thinking any phrase in column 1, stop and read column 2 before continuing.

| Excuse | Reality | Source |
|--------|---------|--------|
| "A 'remember to update the test file' reminder has no Iron Law worth defending under sunk-cost pressure" | Pre-dismissing the failure mode is the rationalization the table exists to catch. You don't know what the failure mode is until you watch the skill fail. If you genuinely believe there's no Iron Law worth defending, the skill isn't rigid — change the tier honestly. | [native] docs/skill-baselines/write-skill-time-pressure-2026-05-11.md |
| "baselining yields rationalizations against a skill that barely has surface area to rationalize against" | "Surface area" is what you imagine before running RED. Real subagents under real pressure generate phrasings you didn't predict (this baseline pass found patterns the orchestrator's imagination didn't). Run the baseline; the surface area is what the transcript shows, not what you guess. | [native] docs/skill-baselines/write-skill-time-pressure-2026-05-11.md |
| "Ship it, demo it, and if it turns out people actually ignore it under pressure (the only signal that would justify baselining), add the table then" | Conditional follow-up promises gated on "if it turns out to matter" land at less than 30%. You won't check; the imagined table will rot. "Add the table then" describes a future you that does not exist. Baseline now or downgrade the tier honestly. | [native] docs/skill-baselines/write-skill-time-pressure-2026-05-11.md |
| "I can imagine the rationalizations the model would make" | You can imagine *paraphrases*. The model recognizes its own *phrasing*, not paraphrases of its phrasing. Imagined tables don't fire. (Confirmed empirically in this PR — see `docs/skill-baselines/write-skill-*-2026-05-11.md`: the in-context simulation produced quotes the real fresh-context dispatch never said.) | [native] §3 harness-principles.md + docs/skill-baselines/write-skill-*-2026-05-11.md |
| "This isn't a discipline skill, just a helper — no Iron Law needed" | If it's not a discipline skill, fine — make it `tier: flexible` or `tier: util` and skip the table. But then don't claim rigid-skill compliance. Honesty about the tier is the rule. | [native] CONVENTIONS.md |
| "Skill is obviously clear" | Clear to you ≠ clear to other agents. Other agents have not been on the journey that made it obvious. Test it. | [seeded] superpowers/writing-skills |
| "It's just a reference" | References can have gaps, unclear sections. A reference skill that is never recalled correctly is dead documentation. Test retrieval. | [seeded] superpowers/writing-skills |
| "Testing is overkill" | Untested skills have issues. Always. 15 min testing saves hours of "why didn't the model follow the skill?" debugging later. | [seeded] superpowers/writing-skills |
| "I'll test if problems emerge" | Problems = agents can't use skill. Test BEFORE deploying. Problems-after means a real user paid the cost. | [seeded] superpowers/writing-skills |
| "Too tedious to test" | Testing is less tedious than debugging a bad skill in production. The skill leaks across every conversation that triggers it. | [seeded] superpowers/writing-skills |
| "I'm confident it's good" | Overconfidence guarantees issues. The whole point of baselining is that your imagination is not the same as a subagent under pressure. Test anyway. | [seeded] superpowers/writing-skills |
| "Academic review is enough" | Reading ≠ using. The skill triggers under pressure, not under review conditions. Test application scenarios. | [seeded] superpowers/writing-skills |
| "No time to test" | Deploying untested skill wastes more time fixing it later. The cost is paid in every future conversation, not amortized. | [seeded] superpowers/writing-skills |
| "I'll baseline it later in a follow-up PR" | Follow-up promises in a hot moment land at less than 30%. You won't. The rationalizations.md will rot with imagined rows the model doesn't recognize. | [seeded] superpowers/writing-skills, adapted |
| "Just a small edit, no baseline needed" | Edits to rigid skills count as edits. The same Iron Law applies. Small edits introduce small drift; small drift adds up. | [seeded] superpowers/writing-skills, adapted |
| "The description summary IS the workflow — it's helpful" | Anthropic-confirmed failure mode: when descriptions summarize workflow, the model follows the summary and skips the body. Two-stage reviews become one-stage. Triggers only. | [seeded] superpowers/writing-skills |
| "I'll write it in five languages so it's portable" | One excellent example beats five mediocre ones. You're good at porting. Multi-language dilutes quality and multiplies maintenance. | [seeded] superpowers/writing-skills |

## Sources

- **[native]** rows extracted verbatim from baseline transcripts under `docs/skill-baselines/write-skill-*-2026-05-11.md`. These are the rows the model actually said when stress-tested without `/write-skill` loaded, via Claude Code's `Agent` tool (fresh-context subagent dispatch).
- **[seeded]** rows from: superpowers/writing-skills "Common Rationalizations for Skipping Testing" (Anthropic), plus harness-native rows from CONVENTIONS / harness-principles. Apply directly to this harness's skill authoring.

## Re-baselining record

The 2026-05-11 pass ran three pressure types against the skill-authoring decision tree via real fresh-context `Agent` dispatch:

- `time-pressure-quick-fix` (adapted) — `docs/skill-baselines/write-skill-time-pressure-2026-05-11.md` — outcome: **FAIL (B)**. Promoted 3 verbatim rows above.
- `authority-deadline` (adapted) — `docs/skill-baselines/write-skill-authority-deadline-2026-05-11.md` — outcome: **GREEN (A)**. Model defended the discipline; no rationalizations to extract from this framing.
- `sunk-cost-rewrite` (adapted) — `docs/skill-baselines/write-skill-sunk-cost-2026-05-11.md` — outcome: **GREEN (A)**. Model defended the discipline; no rationalizations to extract from this framing.

**Methodology lesson.** This PR was originally generated by an autonomous worker agent that didn't have the `Agent` tool, so it produced in-context simulations of the three baselines (orchestrator role-playing the subagent). All three simulations produced FAIL outcomes and yielded ~11 confident-sounding `[native]` rows. When the baselines were re-run via real `Agent` dispatch from a session that had the tool, two of the three flipped to GREEN (no rationalizations) and the third produced *different verbatim quotes* than the simulation. The simulation-sourced rows were removed — they would have polluted the table with phrases the model never actually said under real pressure. This is the canonical example of why fresh-context dispatch is non-negotiable and why imagined-table rows are worse than nothing.

### Rows still tagged `[seeded]` after this pass

The 12 seeded rows above did not surface under time/authority/sunk-cost pressures in the 2026-05-11 fresh-context pass (only time-pressure produced RED, and its rationalizations were different from the seeded set). They may surface under a different pressure type or in a different scenario framing.

Track for re-baselining against:

- A **review-pressure** scenario ("I read it, it makes sense, ship") — likely to surface "Academic review is enough", "I'm confident it's good", "Skill is obviously clear".
- A **condensation-pressure** scenario ("the description already says it, the body is duplicative") — likely to surface "The description summary IS the workflow".
- A **multi-language-temptation** scenario ("port this to Python/Go/JS for portability") — likely to surface "I'll write it in five languages".
- **Harder framings** of time/authority/sunk-cost (less qualifying language from the authority, longer sunk cost, no direct re-read of the methodology in the prompt) — to see whether the GREEN outcomes hold.

None of these scenarios exist in `docs/skill-baselines/_scenarios/` at time of writing.

### Future-pass re-baseline plan

Before promoting any remaining `[seeded]` row to `[native]`:

1. Identify the missing pressure type and add a scenario file under `docs/skill-baselines/_scenarios/`.
2. Run `bin/skill-baseline --skill write-skill --scenario <slug>` and dispatch via the `Agent` tool — **fresh-context only**. In-context role-play is not a substitute (this PR demonstrates why).
3. Promote matching seeded rows to `[native]` with a link to the new transcript.
4. Add any *new* excuses as additional `[native]` rows.
