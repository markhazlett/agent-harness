# Agent-Friendliness Grade — {{DATE}}

**Repository:** `{{REPO}}` • **Branch:** `{{BRANCH}}` • **Commit:** `{{SHA}}` • **Mode:** `{{MODE}}`
**Audience:** the engineering team that has to do (or push back on) the work below. Tone is direct; objections are taken seriously. **Rubric:** `.claude/docs/agent-friendliness-rubric.md`.

## Overall: **{{GRADE}}** ({{NUMERIC}}/100)

> {{PLAIN_ENGLISH_VERDICT}}

{{#RED_FLAGS_PRESENT}}**Grade capped at C** by red flag(s): {{RED_FLAGS_LIST}}. See §Anti-pattern flags below.{{/RED_FLAGS_PRESENT}}

{{#OUT_OF_SCOPE_NOTE}}*Note: parts of the rubric were authored against web/service repos and translate imperfectly here — flagged inline below.*{{/OUT_OF_SCOPE_NOTE}}

**One-paragraph reader's digest.** {{EXEC_SUMMARY}}

---

## Discovery preamble

Everything below was graded against the toolchain detected from this repo, not against defaults. If a category reads `none detected`, that's a finding — the dimensions that depend on it surface that fact below rather than substituting an assumed tool.

| Category | Detected |
|---|---|
| Forge | {{DISCOVERY_FORGE}} |
| CI host | {{DISCOVERY_CI_HOST}} |
| Task / build runner | {{DISCOVERY_TASK_RUNNER}} |
| Branch-protection source | {{DISCOVERY_BRANCH_PROTECTION_SOURCE}} |
| Containerisation / dev env | {{DISCOVERY_CONTAINER}} |
| Lockfile(s) | {{DISCOVERY_LOCKFILES}} |
| Secrets scanner | {{DISCOVERY_SECRETS_SCANNER}} |
| Primary language(s) | {{DISCOVERY_LANGUAGES}} |
| Monorepo | {{DISCOVERY_MONOREPO}} |

{{#DISCOVERY_NOTES}}*Notes:* {{DISCOVERY_NOTES_BODY}}{{/DISCOVERY_NOTES}}

---

## Score table

| Dim | Dimension | Weight | Grade | Numeric | Top drivers |
|---|---|---|---|---|---|
| D1 | Onboarding context | 13% | {{D1_GRADE}} | {{D1_NUM}} | {{D1_DRIVERS}} |
| D2 | Build/test/lint loop | 18% | {{D2_GRADE}} | {{D2_NUM}} | {{D2_DRIVERS}} |
| D3 | Code navigability & locality | 14% | {{D3_GRADE}} | {{D3_NUM}} | {{D3_DRIVERS}} |
| D4 | Deterministic mechanical gates | 11% | {{D4_GRADE}} | {{D4_NUM}} | {{D4_DRIVERS}} |
| D5 | Failure honesty | 9% | {{D5_GRADE}} | {{D5_NUM}} | {{D5_DRIVERS}} |
| D6 | Reproducibility & hermeticity | 7% | {{D6_GRADE}} | {{D6_NUM}} | {{D6_DRIVERS}} |
| D7 | Change-safety affordances | 11% | {{D7_GRADE}} | {{D7_NUM}} | {{D7_DRIVERS}} |
| D8 | Conventions discoverable from code | 8% | {{D8_GRADE}} | {{D8_NUM}} | {{D8_DRIVERS}} |
| D9 | Token-economy / context efficiency | 5% | {{D9_GRADE}} | {{D9_NUM}} | {{D9_DRIVERS}} |
| D10 | Agent-vantage security & runtime observability | 4% | {{D10_GRADE}} | {{D10_NUM}} | {{D10_DRIVERS}} |

---

## Per-dimension breakdown

Each section defends the score: why it matters for *this* codebase, what we found, the cost of leaving it, and the most likely objection.

<!-- Repeat this block for D1–D10 -->

### D{{N}} — {{NAME}} — **{{GRADE}}** ({{NUM}}/100, weight {{WEIGHT}}%)

**Why this matters here.** {{PLAIN_ENGLISH_FOR_THIS_REPO}}
<!-- 2–3 sentences. Translate the rubric's "Plain-English case" into this repo's terms. Name the specific files / commands / patterns in this repo it applies to. No jargon. -->

**What we found.** {{EVIDENCE_NARRATIVE}}
<!-- The signals that drove the letter, with specific evidence: file paths, command runtimes, grep counts. "D2 scored C because `npm test` ran in 4m 17s; the agent will run this 3–5× per task." Numbers beat adjectives. -->

**Cost of leaving this alone.** {{COST_FRAMING}}
<!-- Use the rubric's "Cost of leaving this alone" framings, with this repo's actual numbers plugged in. State assumptions. If you can't quantify honestly, say "hard to quantify; shows up as …" and describe the failure mode. -->

**Most likely objection.** _"{{OBJECTION_VERBATIM}}"_ — {{OBJECTION_RESPONSE}}
<!-- Pull from the rubric's "Common objections" table; pick the one most likely to apply to THIS codebase (not the textbook one). Concede the legitimate part of the objection before defending the dimension. -->

**Signals measured:**

| Signal | Result | Notes |
|---|---|---|
| {{SIGNAL_1}} | ✅/❌/⚠️/n.m. | {{SIGNAL_1_DETAIL}} |
| {{SIGNAL_2}} | … | … |

{{#JUDGMENT_SIGNAL}}
*Judgment sample.* `{{SAMPLED_PATH}}` — {{JUDGMENT_VERDICT}}
{{/JUDGMENT_SIGNAL}}

{{#FULL_MODE}}**→ Backlog items addressing this:** #{{LINKED_BACKLOG_NUMS}}.{{/FULL_MODE}}

<!-- end of dimension block; repeat for D1–D10 -->

---

## Anti-pattern flags

{{#RED_FLAGS}}
- 🚩 **{{FLAG_NAME}}** — {{FLAG_EVIDENCE}} (rubric §6 #{{FLAG_NUM}}). _Why this caps the grade:_ {{FLAG_RATIONALE}}
{{/RED_FLAGS}}
{{^RED_FLAGS}}*None detected.*{{/RED_FLAGS}}

---

## Top 3 highest-leverage fixes

The single changes most likely to move the grade up, weighted by (dimension weight × gap from A × inverse effort). If you read nothing else, read these.

### 1. {{TOP_1_TITLE}}

- **Dim:** D{{TOP_1_DIM}} ({{TOP_1_WEIGHT}}%) • **Effort:** {{TOP_1_EFFORT}}
- **Why this, why now.** {{TOP_1_WHY}}
- **Objection you'll hear.** _"{{TOP_1_OBJECTION}}"_ — {{TOP_1_OBJECTION_RESPONSE}}
- **Agent handoff.** `{{TOP_1_HANDOFF}}`

### 2. {{TOP_2_TITLE}}

- **Dim:** D{{TOP_2_DIM}} ({{TOP_2_WEIGHT}}%) • **Effort:** {{TOP_2_EFFORT}}
- **Why this, why now.** {{TOP_2_WHY}}
- **Objection you'll hear.** _"{{TOP_2_OBJECTION}}"_ — {{TOP_2_OBJECTION_RESPONSE}}
- **Agent handoff.** `{{TOP_2_HANDOFF}}`

### 3. {{TOP_3_TITLE}}

- **Dim:** D{{TOP_3_DIM}} ({{TOP_3_WEIGHT}}%) • **Effort:** {{TOP_3_EFFORT}}
- **Why this, why now.** {{TOP_3_WHY}}
- **Objection you'll hear.** _"{{TOP_3_OBJECTION}}"_ — {{TOP_3_OBJECTION_RESPONSE}}
- **Agent handoff.** `{{TOP_3_HANDOFF}}`

---

{{#FULL_MODE}}

## Full backlog

Ordered by leverage. Skim the High-leverage section first; Medium and Low are for when you've cleared the top.

### High leverage

<!-- Each entry uses the same shape as the Top 3 above. -->

#### {{B_N}}. {{B_TITLE}}

- **Dim:** D{{B_DIM}} ({{B_WEIGHT}}%) • **Effort:** {{B_EFFORT}}
- **Why this, why now.** {{B_WHY}}
- **Objection you'll hear.** _"{{B_OBJECTION}}"_ — {{B_OBJECTION_RESPONSE}}
- **Agent handoff.** `{{B_HANDOFF}}`

<!-- repeat -->

### Medium leverage

*(same shape — abbreviated)*

### Low leverage / polish

*(same shape — abbreviated)*

---

## Diff vs previous report ({{PRIOR_DATE}})

| Dim | Prior | Now | Δ | What changed |
|---|---|---|---|---|
| D1 | {{D1_PRIOR}} | {{D1_GRADE}} | {{D1_DELTA}} | {{D1_DELTA_NOTE}} |
| D2 | {{D2_PRIOR}} | {{D2_GRADE}} | {{D2_DELTA}} | {{D2_DELTA_NOTE}} |
| D3 | {{D3_PRIOR}} | {{D3_GRADE}} | {{D3_DELTA}} | {{D3_DELTA_NOTE}} |
| D4 | {{D4_PRIOR}} | {{D4_GRADE}} | {{D4_DELTA}} | {{D4_DELTA_NOTE}} |
| D5 | {{D5_PRIOR}} | {{D5_GRADE}} | {{D5_DELTA}} | {{D5_DELTA_NOTE}} |
| D6 | {{D6_PRIOR}} | {{D6_GRADE}} | {{D6_DELTA}} | {{D6_DELTA_NOTE}} |
| D7 | {{D7_PRIOR}} | {{D7_GRADE}} | {{D7_DELTA}} | {{D7_DELTA_NOTE}} |
| D8 | {{D8_PRIOR}} | {{D8_GRADE}} | {{D8_DELTA}} | {{D8_DELTA_NOTE}} |
| D9 | {{D9_PRIOR}} | {{D9_GRADE}} | {{D9_DELTA}} | {{D9_DELTA_NOTE}} |
| D10 | {{D10_PRIOR}} | {{D10_GRADE}} | {{D10_DELTA}} | {{D10_DELTA_NOTE}} |
| **Overall** | **{{OVERALL_PRIOR}}** | **{{GRADE}}** | **{{OVERALL_DELTA}}** | |

**Resolved since last report.** {{RESOLVED_LIST}}
**New issues since last report.** {{NEW_ISSUES_LIST}}
**Backlog items that moved.** {{BACKLOG_DELTA}}

{{/FULL_MODE}}

---

## Methodology notes

- Rubric: `.claude/docs/agent-friendliness-rubric.md` ({{RUBRIC_VERSION}}).
- Mechanical signals run by `/grade-codebase` against the working tree at `{{SHA}}`. Reproduce with `/grade-codebase {{MODE}}`.
- Judgment signals contribute at most 50% of any dimension's score.
- Cost framings assume Claude Sonnet token rates as of {{COST_DATE}} (~$3/M input, ~$15/M output). Adjust mentally for your provider.
- Signals that couldn't be measured (missing tools, no network) are marked **n.m.** rather than scored — they don't count against the dimension.
{{#NOTES}}
- {{NOTE}}
{{/NOTES}}

**If you disagree with a grade**, file an objection: open the rubric, find the dimension's "Common objections" table, see whether yours is listed. If it is and you still disagree, the rubric is wrong — open a PR to update it. If it's not, add it.
