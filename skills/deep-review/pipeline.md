# /deep-review Pipeline — 5-Stage Reference

Loaded on demand from `SKILL.md`. This file is the orchestrator's playbook: stage contracts, model-tier routing, FP-profile-to-revalidate mapping, the finding-kind vocabulary, and the synthesis report format.

The output is a **code review**, not a deepsec-style severity report. See `SKILL.md` § "How the review reads" for the design intent; this file is the mechanics.

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

For delegated dims (security, db, langgraph), the FP profile is informational — the delegated skill produces its own findings. The orchestrator adapts the delegated output into the unified finding schema (kind + blocking) for triage/revalidate/synthesis.

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

## Finding schema (used by all dim subagents)

Every finding from Stage 2 (and the adapted output from delegated dims) conforms to this shape:

```
- kind: issue | suggestion | question | nit | praise | thought | chore | note
  blocking: true | false        # only `issue` can be true; everything else is always false
  file: path/to/file            # required for issue/suggestion/question/nit/praise/chore; optional for thought/note
  line: 42                      # required when `file` is set
  title: <one-line>
  evidence: <quoted code, verbatim>   # required for issue/suggestion/nit/praise; optional for question/thought/note
  why_it_matters: <one to three sentences, conversational, explain the cost of not addressing>
  suggested_fix: <minimal change, explicit>   # required for issue and suggestion; optional otherwise
  conviction: 0.0-1.0
```

### Kind contract (Conventional Comments adaptation)

| kind | When to use | `(blocking)` permitted? |
|------|-------------|-------------------------|
| `issue` | Concrete problem in the diff | yes — when the change ships a code-health regression |
| `suggestion` | Proposed improvement with reasoning | no — always non-blocking |
| `question` | Concern with uncertain relevance — open dialogue | no |
| `nit` | Trivial preference, formatting, micro-style | no |
| `praise` | Specific, non-obvious good call | no |
| `thought` | Non-blocking idea or mentoring framing | no |
| `chore` | Small required maintenance task (CHANGELOG, lint fix, doc update) | no — but raise as `issue (blocking)` if a release gate depends on it |
| `note` | FYI for the reader, no action expected | no |

### The `(blocking)` bar

Borrowed from Google's eng-practices standard: an item is `(blocking)` only if shipping the diff as-is would worsen overall code health in a way the author would acknowledge as worth fixing once shown. Concretely:

- Correctness regression (bug, race, partial-failure invariant break)
- Security exposure with a plausible exploit path
- Documented behavior that no longer matches the code (load-bearing docs)
- API contract change without versioning / migration
- Test claims pass for behavior that doesn't exist

Reserve `(blocking)` ruthlessly. The bar is "the author would say 'oh yeah, that's broken, let me fix that.'" If you cannot name what ships broken, it's `(non-blocking)`.

### Conviction calibration (same as before)

Per FP profile, drop in triage:
- HIGH profile: < 0.40
- MED-HIGH profile: < 0.45
- MED profile: < 0.50
- LOW profile: < 0.60

Conviction is independent of `kind` and `blocking`. A low-conviction `(blocking)` issue still ships — but should be paired with a `question` to the author if you're not sure your interpretation of intent is right.

---

## Stage 3 — TRIAGE (uniform, single haiku agent)

Pass every finding from stage 2 to one `subagent_type: triage` dispatch. It applies:

1. **Conviction-floor drop** per FP profile (table above).
2. **Dedup across dimensions.** Findings at the same `file:line` from multiple dims: keep the highest-impact citation. Impact order: `issue (blocking)` > `issue (non-blocking)` > `suggestion` > `question` > `nit` > `praise` > `thought` > `note`. Merge the dropped titles into the surviving one as "(also flagged by: <dim1>, <dim2>)".
3. **Out-of-scope reclassification.** If a finding's content clearly belongs to another dim, demote to `nit` and annotate "(reclassified from <dim>)".

Output: filtered findings + a `triage_drops:` list with reasons.

---

## Stage 4 — REVALIDATE (conditional)

Run revalidate on any finding where ALL of the following hold:
- `kind == issue`
- `blocking == true` OR (`blocking == false` AND `conviction >= 0.7` AND `dimension ∈ {security, performance, concurrency, structural, error-handling, deps, dead-code}`)

Dispatch one `subagent_type: revalidator` for all qualifying findings (single agent, batched input).

Verdicts: `CONFIRMED`, `DISPUTED`, `FIXED-IN-HEAD`, `FIXED-IN-COMMIT-<sha>`.

Apply:
- `FIXED-IN-*` → drop from report
- `DISPUTED` → demote to `nit`, keep in report with refuting evidence quoted
- `CONFIRMED` → keep as-is

---

## Stage 5 — SYNTHESIZE (orchestrator)

Build the final report. Save to `docs/deep-reviews/<YYYY-MM-DD>-<branch-slug>.md`. Branch slug = `git branch --show-current` with `/` replaced by `-`.

Then:
1. Run `bin/deep-review-validate <path>` — must exit 0.
2. Print the report path in your final message.
3. Call the `AskUserQuestion` tool with one single-select question: "Apply blocking fixes?" with options "Y (all)" / "S (step-by-step)" / "N (none — just review)". Wait for the user's answer.
4. If Y or S: dispatch one implementation subagent per `(blocking)` finding with `suggested_fix` + `file:line` + `evidence`. After each fix, run `$HARNESS_TEST_CMD`. Step-by-step asks the user between findings.

### Verdict line

The top-of-report verdict is one of three phrases (mapped, not graded):

- **"Ship it"** — zero `(blocking)` items
- **"Address blocking items first"** — one or more `(blocking)` items
- **"Substantial concerns"** — three or more `(blocking)` items, OR a systemic pattern (same blocking issue in 3+ files), OR a single `(blocking)` with revalidate verdict `DISPUTED` flipped to a deeper systemic concern by the orchestrator

### Final report skeleton

```markdown
# Code Review — <branch-slug>
**Date:** <YYYY-MM-DD>
**Diff:** main..HEAD (<N> files, +<X>/-<Y> lines)
**Commit:** <short-sha>
**Reviewer:** /deep-review (SCAN → <N> dim subagents → triage → revalidate → synthesis)

## Summary

<one short paragraph in pair-engineer tone. State what shipped, what stands
out, and the headline question. First person is OK. Plainspoken. End with
the verdict line.>

**Verdict:** Ship it | Address blocking items first | Substantial concerns

<-- If any (blocking) items: -->

## Before merge (<N> items)

<For each (blocking) item, one ### subsection:>

### `<file:line>` — <one-line title>

**issue (blocking):** <conversational framing. Quote the evidence inline.
Explain why it matters — the cost to users/callers/future maintainers if
this ships as-is. Anchor on what the author was probably trying to do.>

**suggestion:** <concrete remedy with reasoning. Show the line/diff to add
or remove.>

**revalidated:** CONFIRMED | DISPUTED-flipped | FIXED-IN-<sha>

<-- If any non-blocking comments worth raising: -->

## Worth thinking about (<N> items)

<Group by file path. Each item is one bullet using Conventional Comments
labels: suggestion / question / nit / thought / chore. Keep each to one
or two sentences. The bar: would a senior engineer mention this in
review, or is it a linter's job?>

### `<file>`

- **suggestion (non-blocking):** <…>
- **question:** <…>
- **nit:** <…>
- **thought:** <…>

<-- If genuinely non-obvious praise exists. Skip the section entirely if
not — empty praise reads as inflation. -->

## Worth calling out (<N> items)

- **praise:** `<file:line>` — <specific, names the non-obvious good call>

## What I audited

<Verdict matrix for transparency about coverage. The "Items raised" column
counts surviving findings post-triage, post-dedup, post-revalidate.>

| # | Dimension | Verdict | Items raised | Revalidated |
|---|-----------|---------|--------------|-------------|
| 1 | security  | PASS    | 0            | yes         |
| 2 | db        | N/A     | —            | n/a         |
| … | …         | …       | …            | …           |

## N/A dimensions

- <dim> — <one-line justification naming what this dim would have caught and why this diff has no surface for it>

## Pipeline notes

- Dispatched: <N> subagents in parallel at <ISO timestamp>
- Delegated: <list of skills invoked>
- Triage drops: <N> (or "none") — <one-line per drop with reason>
- Revalidate: <N> CONFIRMED, <N> DISPUTED, <N> FIXED
```

### What changed from prior versions

- The five severity sections (`## BLOCKING`, `## HIGH`, `## MED`, `## LOW`, `## NIT`) are gone. The output is binary: `## Before merge` (blocking) and `## Worth thinking about` (everything else). `## Worth calling out` is the praise section.
- The verdict matrix is kept (it's the audit-trail receipt) but moved below the prose so the human-readable review leads.
- The verdict line is one of three phrases, not a CRIT/H/M/L count.
- Per-finding labels follow Conventional Comments, which gives the reader fast scannability without implying false severity precision.
