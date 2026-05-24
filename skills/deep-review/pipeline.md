# /deep-review Pipeline — 5-Stage Reference

Loaded on demand from `SKILL.md`. This file is the orchestrator's playbook: stage contracts, model-tier routing, FP-profile-to-revalidate mapping, and the synthesis report format.

---

## Stage 1 — SCAN (deterministic, shell)

Run: `bin/deep-review-scan`

Reads `git diff main...HEAD`, detects gates from `.claude/hooks/config.sh`, mines reference exemplars (sibling files of each changed file), extracts a `## Conventions` section from CLAUDE.md if present, and emits a JSON manifest:

```json
{
  "diff": { "files": [...], "stats": {"added": N, "removed": N} },
  "gates": { "db": bool, "langgraph": bool, "a11y": bool },
  "conventions": "<verbatim ## Conventions or ## Patterns body from CLAUDE.md, or empty string>",
  "scopes": {
    "<dim>": { "paths": [...], "candidates": [...], "exemplars": [...] }
  }
}
```

The `candidates` arrays are dim-specific regex hits from SCAN (e.g., raw-SQL strings for security pre-screen, `Promise.all` patterns for concurrency). They are pre-screening hints, not findings — the dispatched subagent decides whether each candidate is a true positive after reading the surrounding context.

Gate logic:
- `db` → `gates.db = true` if any path matches `$HARNESS_DB_MIGRATIONS_DIR` or `$HARNESS_DB_SCHEMA_PATH`
- `langgraph` → `gates.langgraph = true` if `HARNESS_LANGGRAPH=true` AND any path matches `src/agents/**` or `agents/**`
- `a11y` → `gates.a11y = true` if any path has a frontend extension (`.tsx`, `.jsx`, `.vue`, `.svelte`, `.html`)

Exemplar-mining: for each file in the diff, scan emits up to 3 sibling files (same extension, same directory, NOT in the diff). Falls back to elsewhere-in-repo same-extension files if no qualifying siblings. The dispatched subagent reads these on demand to anchor "what's the codebase's convention" reasoning.

Conventions extraction: scan reads repo-root `CLAUDE.md` (if present), finds a `## Conventions` or `## Patterns` section, emits the body verbatim. The orchestrator includes this string in every per-dim prompt.

Parse the JSON; route from `gates` (which dims to skip with N/A), `scopes` (per-dim path lists + exemplars), and `conventions` (universal anchor).

---

## Stage 2 — DISPATCH (parallel subagents in one message)

**Emit ONE assistant message containing N `Agent` tool-use blocks.** N = 15 minus skipped gated dims (db, langgraph, a11y). Per harness principle §26 (parallelism is explicit and rewarded), all independent calls go in one message.

### Routing table

| Dimension | Method | subagent_type | Prompt source | FP profile |
|-----------|--------|---------------|---------------|------------|
| security | delegate | — | invoke `/security-review` | HIGH |
| db | delegate (if gates.db) | — | invoke `/db-review` | LOW |
| langgraph | delegate (if gates.langgraph) | — | invoke `/lg-review` | LOW-MED |
| structural | dispatch | dim-investigator-deep | `dimensions/structural.md` | MED-HIGH |
| performance | dispatch | dim-investigator-deep | `dimensions/performance.md` | HIGH |
| concurrency | dispatch | dim-investigator-deep | `dimensions/concurrency.md` | HIGH |
| error-handling | dispatch | dim-investigator-deep | `dimensions/error-handling.md` | MED |
| types | dispatch | dim-investigator | `dimensions/types.md` | LOW |
| observability | dispatch | dim-investigator | `dimensions/observability.md` | LOW |
| tests | dispatch | dim-investigator | `dimensions/tests.md` | LOW |
| api-drift | dispatch | dim-investigator | `dimensions/api-drift.md` | LOW |
| deps | dispatch | dim-investigator | `dimensions/deps.md` | MED |
| a11y | dispatch (if gates.a11y) | dim-investigator | `dimensions/a11y.md` | LOW |
| dead-code | dispatch | dim-investigator | `dimensions/dead-code.md` | MED |
| docs | dispatch | dim-investigator | `dimensions/docs.md` | LOW |

For delegated dims (security, db, langgraph), the FP profile is informational — the delegated skill produces its own verdicts. The orchestrator uses it when deciding whether to send adapted findings through Stage 4 revalidate.

### Per-dispatch prompt assembly

Each `Agent` call's `prompt` parameter contains:

```
SYSTEM (your charter):
<contents of dimensions/<dim>.md>

PROJECT CONTEXT:
<one-paragraph summary derived from CLAUDE.md preamble: stack, ORM, framework,
auth provider, API layer>

CONVENTIONS (from this repo's CLAUDE.md ## Conventions section; may be empty):
<verbatim conventions string from SCAN>

REFERENCE EXEMPLARS (existing files in this codebase you should treat as
authoritative for "good pattern"):
<list of exemplar paths from SCAN — read at least one before flagging
any pattern/structural finding>

SCOPE PACKET:
- Paths to read (from SCAN output for this dim):
  <list>
- Diff hunks for these paths:
  <unified diff, full hunks not just headers>

FP PROFILE: <HIGH | MED-HIGH | MED | LOW>

OUTPUT FORMAT:
<the fenced block spec from the agent definition>
```

For the three delegated dimensions (`security`, `db`, `langgraph`), do NOT use `Agent`. Invoke their slash commands inline (`/security-review`, `/db-review`, `/lg-review`) and adapt their final reports into the unified finding schema. (Note: those skills don't currently consume the conventions/exemplars context — that integration is future work.)

---

## Stage 3 — TRIAGE (uniform, single haiku agent)

Pass every finding from stage 2 to one `subagent_type: triage` dispatch. It applies:

| FP profile | Drop conviction threshold |
|-----------|---------------------------|
| HIGH | < 0.40 |
| MED-HIGH | < 0.45 |
| MED | < 0.50 |
| LOW | < 0.60 |

Plus dedup across dimensions and out-of-scope reclassification to NIT.

Output: filtered findings + a `triage_drops:` list with reasons.

---

## Stage 4 — REVALIDATE (conditional)

Run revalidate only on findings where:
- `severity ∈ {CRITICAL, HIGH, MED}` (i.e., ≥ WARN), AND
- `dimension ∈ {security, performance, concurrency, structural, error-handling, deps, dead-code}`

Dispatch one `subagent_type: revalidator` for all qualifying findings (single agent, batched input).

Verdicts: `CONFIRMED`, `DISPUTED`, `FIXED-IN-HEAD`, `FIXED-IN-COMMIT-<sha>`.

Apply:
- `FIXED-IN-*` → drop from report
- `DISPUTED` → demote to NIT, keep in report with refuting evidence
- `CONFIRMED` → keep at original severity

---

## Stage 5 — SYNTHESIZE (orchestrator)

Build the final report. Save to `docs/deep-reviews/<YYYY-MM-DD>-<branch-slug>.md`. Branch slug = `git branch --show-current` with `/` replaced by `-`.

Then:
1. Run `bin/deep-review-validate <path>` — must exit 0.
2. Print the report path in your final message.
3. Call the `AskUserQuestion` tool with one single-select question: "Apply BLOCKING fixes?" with options "Y (all)" / "S (step-by-step)" / "N (none — just review)". Wait for the user's answer.
4. If Y or S: dispatch one implementation subagent per BLOCKING finding with `suggested_fix` + `file:line` + `evidence`. After each fix, run `$HARNESS_TEST_CMD`. Step-by-step asks the user between findings.

### Final report skeleton

```markdown
# Deep Review — <branch-slug>
**Date:** <YYYY-MM-DD>
**Diff:** main..HEAD (<N> files, +<X>/-<Y> lines)
**Commit:** <short-sha>
**Pipeline:** SCAN → DISPATCH(<N>) → TRIAGE → REVALIDATE → SYNTHESIZE

## TL;DR
**Verdict:** GO | NEEDS-CHANGES | NO-GO
Counts: <CRIT> CRITICAL, <H> HIGH, <M> MED, <L> LOW, <N> NIT
Blocking dimensions: <list>

## Verdict Matrix
The "Verdict" column is one of `PASS` / `WARN` / `FAIL` / `N/A`. The "FP profile" column copies the per-dim value from Stage 2's routing table. The "Revalidated" column shows `yes (N confirmed)` for high-FP dims that went through Stage 4, `no` for dims that didn't qualify, or `n/a` for delegated dims that handle revalidation themselves.

| # | Dimension | Verdict | Findings | FP profile | Revalidated |
|---|-----------|---------|----------|-----------|-------------|
| 1 | security  | …       | …        | HIGH      | yes (N conf)|

## BLOCKING (<N>)
### 1. [<dim>] <file:line> — <title>
**Evidence:** <quoted code>
**Impact:** <what breaks>
**Suggested fix:** <minimal change>
**Revalidated:** CONFIRMED | DISPUTED | FIXED-IN-<sha>

## HIGH (<N>)
…

## MED (<N>)
…

## LOW (<N>)
…

## NIT (<N>)
…

## N/A dimensions
- <dim> — <one-line justification>

## Dispatched subagents
- <N> fired in parallel at <ISO timestamp>
- delegated: <list of skills invoked>

## Triage drops (<N>)
- <id>: <reason>

## Revalidate results
- CONFIRMED: <N>
- DISPUTED: <N> (demoted to NIT)
- FIXED-IN-HEAD: <N> (dropped)
- FIXED-IN-COMMIT: <N> (dropped, sha each)
```
