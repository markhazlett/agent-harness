# Agent-Friendliness Grade — {{DATE}}

**Repository:** `{{REPO}}` • **Branch:** `{{BRANCH}}` • **Commit:** `{{SHA}}` • **Mode:** `{{MODE}}`
**Rubric version:** `.claude/docs/agent-friendliness-rubric.md` ({{RUBRIC_SHA}})

## Overall: **{{GRADE}}** ({{NUMERIC}}/100)

> {{PLAIN_ENGLISH_VERDICT}}

{{#RED_FLAGS_PRESENT}}**Grade capped at C** by red flag(s): {{RED_FLAGS_LIST}}. See §Anti-pattern flags below.{{/RED_FLAGS_PRESENT}}

**Stack detected:** {{STACK}} {{#MONOREPO}} (monorepo: {{MONOREPO_TOOL}}){{/MONOREPO}}
{{#OUT_OF_SCOPE_NOTE}}*Note: parts of the rubric were authored against web/service repos and translate imperfectly here — see notes below.*{{/OUT_OF_SCOPE_NOTE}}

---

## Per-dimension scores

| Dim | Dimension | Weight | Grade | Numeric | Top drivers |
|---|---|---|---|---|---|
| D1 | Onboarding context | 15% | {{D1_GRADE}} | {{D1_NUM}} | {{D1_DRIVERS}} |
| D2 | Build/test/lint loop | 18% | {{D2_GRADE}} | {{D2_NUM}} | {{D2_DRIVERS}} |
| D3 | Code navigability & locality | 15% | {{D3_GRADE}} | {{D3_NUM}} | {{D3_DRIVERS}} |
| D4 | Deterministic mechanical gates | 12% | {{D4_GRADE}} | {{D4_NUM}} | {{D4_DRIVERS}} |
| D5 | Failure honesty | 10% | {{D5_GRADE}} | {{D5_NUM}} | {{D5_DRIVERS}} |
| D6 | Reproducibility & hermeticity | 8% | {{D6_GRADE}} | {{D6_NUM}} | {{D6_DRIVERS}} |
| D7 | Change-safety affordances | 12% | {{D7_GRADE}} | {{D7_NUM}} | {{D7_DRIVERS}} |
| D8 | Conventions discoverable from code | 10% | {{D8_GRADE}} | {{D8_NUM}} | {{D8_DRIVERS}} |

---

## Signal detail

For each dimension, list the mechanical and judgment signals that were measured, the result, and (for judgment) the file sampled.

### D1 — Onboarding context — {{D1_GRADE}}

- ✅/❌ AGENTS.md or CLAUDE.md present — `{{D1_S1_RESULT}}`
- ✅/❌ Covers six core areas (Commands / Testing / Project structure / Code style / Git workflow / Boundaries) — `{{D1_S2_RESULT}}`
- ✅/❌ Length 50–500 lines — `{{D1_S3_RESULT}}`
- ✅/❌ Commands are copy-pasteable (no placeholders) — `{{D1_S4_RESULT}}`
- *(judgment)* README quickstart ends in a runnable command — sampled `{{D1_J1_PATH}}` — {{D1_J1_VERDICT}}

### D2 — Build/test/lint loop — {{D2_GRADE}}

*(same structure — fill from rubric §3.D2)*

### D3 — Code navigability & locality — {{D3_GRADE}}

*(...)*

### D4 — Deterministic mechanical gates — {{D4_GRADE}}

*(...)*

### D5 — Failure honesty — {{D5_GRADE}}

*(...)*

### D6 — Reproducibility & hermeticity — {{D6_GRADE}}

*(...)*

### D7 — Change-safety affordances — {{D7_GRADE}}

*(...)*

### D8 — Conventions discoverable from code — {{D8_GRADE}}

*(...)*

---

## Anti-pattern flags

{{#RED_FLAGS}}
- 🚩 **{{FLAG_NAME}}** — {{FLAG_EVIDENCE}} (rubric §6 #{{FLAG_NUM}})
{{/RED_FLAGS}}
{{^RED_FLAGS}}*None detected.*{{/RED_FLAGS}}

---

## Top issues

The 3 single changes most likely to move the grade up, ordered by leverage (dimension weight × gap from A).

1. **{{TOP_1_TITLE}}** — D{{TOP_1_DIM}} ({{TOP_1_WEIGHT}}%). {{TOP_1_DETAIL}}
2. **{{TOP_2_TITLE}}** — D{{TOP_2_DIM}} ({{TOP_2_WEIGHT}}%). {{TOP_2_DETAIL}}
3. **{{TOP_3_TITLE}}** — D{{TOP_3_DIM}} ({{TOP_3_WEIGHT}}%). {{TOP_3_DETAIL}}

---

{{#FULL_MODE}}

## Backlog (full mode)

Ordered by leverage. Each task is sized S/M/L and includes an agent-handoff one-liner so the user can dispatch them to an agent without re-explaining.

### High leverage

| # | Task | Dim | Effort | Agent handoff |
|---|---|---|---|---|
| 1 | {{B1_TITLE}} | D{{B1_DIM}} | {{B1_EFFORT}} | {{B1_HANDOFF}} |
| 2 | {{B2_TITLE}} | D{{B2_DIM}} | {{B2_EFFORT}} | {{B2_HANDOFF}} |
| … | | | | |

### Medium leverage

*(...)*

### Low leverage / polish

*(...)*

---

## Diff vs previous report ({{PRIOR_DATE}})

| Dim | Prior | Now | Δ |
|---|---|---|---|
| D1 | {{D1_PRIOR}} | {{D1_GRADE}} | {{D1_DELTA}} |
| D2 | {{D2_PRIOR}} | {{D2_GRADE}} | {{D2_DELTA}} |
| … | | | |
| **Overall** | **{{OVERALL_PRIOR}}** | **{{GRADE}}** | **{{OVERALL_DELTA}}** |

**Resolved since last report:** {{RESOLVED_LIST}}
**New issues since last report:** {{NEW_ISSUES_LIST}}

{{/FULL_MODE}}

---

## Methodology notes

- Rubric: `.claude/docs/agent-friendliness-rubric.md`
- Mechanical signals run by `/grade-codebase` against the working tree at `{{SHA}}`. Reproduce with `/grade-codebase {{MODE}}`.
- Judgment signals contribute at most 50% of any dimension's score.
- Signals that couldn't be measured (missing tools, no network) are marked "not measured" rather than scored.
{{#NOTES}}
- {{NOTE}}
{{/NOTES}}
