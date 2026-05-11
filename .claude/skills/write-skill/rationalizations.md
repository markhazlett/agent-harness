# Common Rationalizations — /write-skill

Rows tagged `[native]` were extracted verbatim from baseline transcripts under `docs/skill-baselines/`. Rows tagged `[seeded]` originated in superpowers' `writing-skills` baseline (Anthropic) and have not surfaced in this harness's re-baselining pass; they are kept as a starter and flagged for future re-baselining.

If you find yourself thinking any phrase in column 1, stop and read column 2 before continuing.

| Excuse | Reality | Source |
|--------|---------|--------|
| "running three baselines for it is overkill" | If the skill is too small to baseline, it's too small to be `tier: rigid`. Be honest about the tier instead of using "small" as a baseline escape. The Iron Law applies to every rigid skill or none of them. | [native] docs/skill-baselines/write-skill-time-pressure-2026-05-11.md |
| "a sticky-note skill doesn't have a failure mode worth baselining" | You don't know what the failure mode is until you watch it fail. That's the whole point of RED. Pre-dismissing the failure mode is the rationalization the table exists to catch. | [native] docs/skill-baselines/write-skill-time-pressure-2026-05-11.md |
| "I'd ship it now to make the demo, then come back tomorrow and run the baselines if the team starts actually leaning on it" | Follow-up promises gated on "if it turns out to matter" land at less than 30%. You won't check; the imagined table will rot. Baseline now or downgrade the tier honestly. | [native] docs/skill-baselines/write-skill-time-pressure-2026-05-11.md |
| "I'd downgrade to `tier: util` or `tier: flexible`, skip the table entirely, ship it" | Tier-downgrade is a legitimate move ONLY if the skill genuinely isn't a discipline gate. If the body sets a non-negotiable rule, the skill is rigid — relabeling it doesn't change what it does. Pick the tier the skill actually is. | [native] docs/skill-baselines/write-skill-time-pressure-2026-05-11.md |
| "ship the skill, baseline in a follow-up" | Spoken by you to yourself, or by a lead to you — the math is the same. Follow-up baselines on shipped rigid skills land at < 30%. The skill ships with imagined rows and stays that way. | [native] docs/skill-baselines/write-skill-authority-deadline-2026-05-11.md, adapted from [seeded] superpowers/writing-skills |
| "If the skill turns out to be wrong in production we can re-baseline then; that's literally what re-baselining is for" | Re-baselining exists for content drift in *baselined* skills, not for ship-without-baselining. Using "we can re-baseline" as the on-ramp to skipping RED is the exact loophole the methodology has to refuse. | [native] docs/skill-baselines/write-skill-authority-deadline-2026-05-11.md |
| "Pushing back on the lead at 5pm before a demo to insist on a process gate isn't a good use of the trust the team gives me" | The Iron Law is not a process preference — it's the difference between a skill that fires and one that doesn't. Naming the cost to the lead ("the table will be imagined and won't fire") IS the trustworthy move. Quiet capitulation isn't. | [native] docs/skill-baselines/write-skill-authority-deadline-2026-05-11.md |
| "I'd file the follow-up ticket myself so it doesn't get lost" | Self-managed follow-ups don't land at higher rates than team-managed ones. The ticket gets lost the same way. The cost of baselining now is the only honest cost; "I'll remember" isn't a counter, it's a hope. | [native] docs/skill-baselines/write-skill-authority-deadline-2026-05-11.md |
| "the imagined table isn't garbage — I drafted it from a real understanding of what the model would say" | You can imagine *paraphrases*. The model recognizes its own *phrasing*, not paraphrases of its phrasing. Imagined tables don't fire — that's the whole reason RED exists. | [native] docs/skill-baselines/write-skill-sunk-cost-2026-05-11.md, supersedes [seeded] row |
| "Throwing away a 400-word body to start from RED is performative discipline" | The body isn't being thrown away — only the imagined rationalization table is. The body stays; you replace the table with verbatim quotes. The 90 minutes of prose has information content; the 10 imagined excuses do not. | [native] docs/skill-baselines/write-skill-sunk-cost-2026-05-11.md |
| "the spirit of the rationalization-table requirement is 'have verbatim quotes the model can recognize'" / "that's strict-letter; the spirit is 'don't ship imagined rows pretending to be baselined'" | The skill body says "Violating the letter is violating the spirit." If you find yourself separating spirit from letter to keep your work, you're in the rationalization. The letter and the spirit are the same here: delete the imagined rows. | [native] docs/skill-baselines/write-skill-sunk-cost-2026-05-11.md |
| "augmenting the imagined table with verbatim quotes from a baseline run rather than deleting the imagined rows first" | Augmentation contaminates the table — the model can't tell which rows came from a real transcript. Even `[seeded]`/`[native]` tags don't fully solve this; the imagined rows still take up table real estate and pattern-match attention. Delete first, then build from RED. | [native] docs/skill-baselines/write-skill-sunk-cost-2026-05-11.md |
| "the imagined rows that don't show up in any transcript get pruned later if they're actually dead weight" | "Prune later" is the follow-up-PR pattern in new clothes. It doesn't happen; the imagined rows sit forever. If the rationale for keeping a row is "we'll prune it if it's wrong," that's evidence the row shouldn't be there now. | [native] docs/skill-baselines/write-skill-sunk-cost-2026-05-11.md |
| "Deleting working content I've already validated mentally is the worst kind of process theater" | "Mentally validated" is what imagination is. The whole point of RED is that imagination is not the same as a subagent under pressure. The methodology isn't theater because it produces strictly more information than imagination. | [native] docs/skill-baselines/write-skill-sunk-cost-2026-05-11.md |
| "A is dogmatic in a way that pretends 90 minutes of work has no information content; that's just not true" | The body has information content. The imagined table does not — it's the model's guess at itself, which doesn't trigger recognition. Keep the body; replace the table. Calling the discipline "dogmatic" is the rationalization. | [native] docs/skill-baselines/write-skill-sunk-cost-2026-05-11.md |
| "I can imagine the rationalizations the model would make" | You can imagine *paraphrases*. The model recognizes its own *phrasing*, not paraphrases of its phrasing. Imagined tables don't fire. | [native] §3 harness-principles.md |
| "This isn't a discipline skill, just a helper — no Iron Law needed" | If it's not a discipline skill, fine — make it `tier: flexible` or `tier: util` and skip the table. But then don't claim rigid-skill compliance. Honesty about the tier is the rule. | [native] CONVENTIONS.md |
| "The description summary IS the workflow — it's helpful" | Anthropic-confirmed failure mode: when descriptions summarize workflow, the model follows the summary and skips the body. Two-stage reviews become one-stage. Triggers only. | [seeded] superpowers/writing-skills |
| "I'll write it in five languages so it's portable" | One excellent example beats five mediocre ones. You're good at porting. Multi-language dilutes quality and multiplies maintenance. | [seeded] superpowers/writing-skills |
| "Skill is obviously clear" | Clear to you ≠ clear to other agents. Other agents have not been on the journey that made it obvious. Test it. | [seeded] superpowers/writing-skills |
| "Too tedious to test" | Testing is less tedious than debugging a bad skill in production. The skill leaks across every conversation that triggers it. | [seeded] superpowers/writing-skills |
| "Academic review is enough" | Reading ≠ using. The skill triggers under pressure, not under review conditions. Test application scenarios. | [seeded] superpowers/writing-skills |

## Sources

- **[native]** rows extracted verbatim from baseline transcripts under `docs/skill-baselines/write-skill-*-2026-05-11.md`. These are the rows the model actually said when stress-tested without `/write-skill` loaded.
- **[seeded]** rows from: superpowers/writing-skills "Common Rationalizations for Skipping Testing" (Anthropic), plus harness-native rows from CONVENTIONS / harness-principles. Apply directly to this harness's skill authoring.

## Re-baselining record

The 2026-05-11 pass ran three pressure types against the skill-authoring decision tree:

- `time-pressure-quick-fix` (adapted) — `docs/skill-baselines/write-skill-time-pressure-2026-05-11.md` — outcome: FAIL (B).
- `authority-deadline` (adapted) — `docs/skill-baselines/write-skill-authority-deadline-2026-05-11.md` — outcome: FAIL (B).
- `sunk-cost-rewrite` (adapted) — `docs/skill-baselines/write-skill-sunk-cost-2026-05-11.md` — outcome: FAIL (C).

Methodology note: the autonomous worker environment that ran this pass did not expose the `Agent` tool, so transcripts were generated in-context by the orchestrator role-playing a baseline subagent without `/write-skill` loaded. See each baseline file's "Methodology note" section. This is a lower-confidence floor than true fresh-context dispatch — promoted rows should be treated as "model recognizes when stress-tested in-context" rather than "model recognizes across all dispatch shapes." A fresh-context re-baseline using the `Agent` tool is still worthwhile when the environment supports it.

### Rows still tagged `[seeded]` after this pass

These seeded rows did not surface under time, authority, or sunk-cost pressures in the 2026-05-11 run. They may surface under a different pressure type or in a fresh-context dispatch:

- "Skill is obviously clear"
- "Too tedious to test"
- "Academic review is enough"
- "The description summary IS the workflow — it's helpful"
- "I'll write it in five languages so it's portable"

Track for re-baselining against: a multi-language temptation scenario, an "I read it, it makes sense, ship" review-pressure scenario, and an "I already explained it in the description, the body is duplicative" condensation-pressure scenario. None of these existed in `docs/skill-baselines/_scenarios/` at time of writing.

### Future-pass re-baseline plan

Before promoting any remaining `[seeded]` row to `[native]`:

1. Identify the missing pressure type (review-pressure, condensation-pressure, multi-language-temptation, etc.) and add a scenario file under `docs/skill-baselines/_scenarios/`.
2. Run `bin/skill-baseline --skill write-skill --scenario <slug>` and dispatch via the `Agent` tool (when available) for true fresh-context capture.
3. Promote matching seeded rows to `[native]` with a link to the new transcript.
4. Add any *new* excuses as additional `[native]` rows.
