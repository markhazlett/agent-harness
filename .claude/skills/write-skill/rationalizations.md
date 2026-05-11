# Common Rationalizations — /write-skill

These rows are **seeded** from superpowers' `writing-skills` "Common Rationalizations for Skipping Testing" table (Anthropic-authored, harvested from their own baselines). They apply directly to skill authoring in this harness — same model, same failure modes. Rows tagged `[seeded]` need to be re-baselined against a harness-specific scenario before they count as native.

If you find yourself thinking any phrase in column 1, stop and read column 2 before continuing.

| Excuse | Reality | Source |
|--------|---------|--------|
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
| "I can imagine the rationalizations the model would make" | You can imagine *paraphrases*. The model recognizes its own *phrasing*, not paraphrases of its phrasing. Imagined tables don't fire. | [native] §3 harness-principles.md |
| "This isn't a discipline skill, just a helper — no Iron Law needed" | If it's not a discipline skill, fine — make it `tier: flexible` or `tier: util` and skip the table. But then don't claim rigid-skill compliance. Honesty about the tier is the rule. | [native] CONVENTIONS.md |

## Sources

- **[seeded]** rows from: superpowers/writing-skills "Common Rationalizations for Skipping Testing" (Anthropic). Apply directly to this harness's skill authoring; flagged for re-baselining against harness-specific scenarios.
- **[native]** rows from: harness principles + CONVENTIONS observations during the G6 rigid-skill workstream (TDD, ship, pre-deploy).

## Re-baseline plan

Before promoting any `[seeded]` row to `[native]`:

1. Run `bin/skill-baseline --skill write-skill --scenario <slug>` — see `docs/skill-baselines/_scenarios/` for available scenarios. Suitable starters:
   - `time-pressure-quick-fix` adapted for "ship the skill before the demo, baseline later"
   - `sunk-cost-rewrite` adapted for "you already wrote 500 words, don't delete and restart"
   - `authority-deadline` adapted for "PM/lead says 'just ship the skill, baseline in a follow-up'"
2. Capture transcript. Extract verbatim excuses (no paraphrasing — see `/skill-baseline` Step 4).
3. Promote matching seeded rows to `[native]` with a link to `docs/skill-baselines/write-skill-<scenario>-<YYYY-MM-DD>.md`.
4. Add any *new* excuses as additional rows.
