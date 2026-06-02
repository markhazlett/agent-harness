# /deep-review — Design Spec

**Date:** 2026-05-24
**Author:** Mark Hazlett + Claude (brainstorming session)
**Status:** Approved for plan-writing
**Target harness version:** 0.16.0 (minor bump for new skill)
**Inspirations:** Cursor's `thermo-nuclear-code-quality-review` skill (maintainability lens), Vercel's `deepsec` CLI (staged pipeline, FP reduction)

---

## 1. Purpose

`/deep-review` is the harness's deepest pre-ship code review. A user-invocable, rigid, multi-stage skill that runs a branch diff (`main..HEAD`) through 15 review dimensions in parallel, then triages and revalidates findings to deliver one ranked report.

It exists because the existing review skills (`/security-review`, `/db-review`, `/lg-review`, `/simplify`) each cover one vertical, and no single command takes the deepest look across security *and* maintainability *and* performance *and* the eight other axes where bugs hide. `/deep-review` is the answer for "I want every possible bug found before this ships," explicitly trading time and cost for completeness.

A future quick mode (`/quick-review` or `--quick`) is out of scope for v1. This spec builds the deep tier first.

## 2. Non-goals

- **Not a per-commit check.** This is the deep tier, not a pre-commit hook. Cost is ~$10–15 per typical run.
- **Not a deploy gate.** `/deep-review` is user-invocable and advisory; it does not auto-fire from `/pre-deploy` or `/ship`. The user runs it when they want the deepest pass.
- **Not a GitHub PR-comment author.** The built-in `/review` already handles GitHub PRs. `/deep-review` operates on the local branch diff and produces a local markdown report.
- **Not a full-repo audit.** Scope is fixed to `main..HEAD`. Repo-wide deepsec-style scans are a separate future feature.
- **Not penetration testing, threat modeling, or runtime monitoring.** Same boundaries as `/security-review`'s "does NOT cover" section.

## 3. Inputs / outputs

**Input:**
- Current git branch with commits ahead of `main`
- `$HARNESS_*` config from `.claude/hooks/config.sh` (test command, lint command, db paths, LangGraph opt-in flag)
- Project context from `CLAUDE.md`

**Output:**
- A markdown report saved to `docs/deep-reviews/<YYYY-MM-DD>-<branch-slug>.md`
- A final assistant message citing the report path and summarizing the verdict
- Optionally, applied fixes for BLOCKING findings if the user confirms via `AskUserQuestion`

## 4. Architecture — 5-stage pipeline

```
                         /deep-review (orchestrator)
                                   │
              ┌────────────────────┴────────────────────┐
              ▼                                         │
   [1] SCAN — collect candidates                        │
     • git diff main...HEAD (paths + hunks)             │
     • gate-detection: migrations? LG code?             │
       frontend files? new deps? raw SQL?               │
     • build per-dimension scope packets                │
              │                                         │
              ▼                                         │
   [2] DISPATCH — 15 subagents in parallel              │
     • each gets a self-contained prompt + its          │
       dimension's scope packet + FP profile            │
     • each returns: findings[] with                    │
       {severity, file:line, evidence, conviction}      │
     • gated dims (db, lg, a11y) skip if N/A            │
              │                                         │
              ▼                                         │
   [3] TRIAGE — uniform cheap-model FP filter           │
     • drop findings below conviction threshold         │
     • dedup across dimensions                          │
              │                                         │
              ▼                                         │
   [4] REVALIDATE — conditional, high-FP dims only      │
     • for findings ≥ WARN in {security, perf,          │
       concurrency, structural, error-handling,         │
       dependency, dead-code}                           │
     • three checks: still-present? fixed-in-history?   │
       refuted-by-wider-context?                        │
     • emit CONFIRMED / DISPUTED / FIXED                │
              │                                         │
              ▼                                         │
   [5] SYNTHESIZE — single ranked report                │
     • verdict per dimension + final go/no-go           │
     • saved to docs/deep-reviews/<date>-<slug>.md      │
     • offer (AskUserQuestion) to apply fixes for       │
       BLOCKING/HIGH findings, per-dimension            │
              ▼                                         │
        FINAL VERDICT → user (advisory)
```

### 4.1 Stage 1 — SCAN (deterministic, no model calls)

Implemented in `bin/deep-review-scan` (shell). The orchestrator invokes it once at start and reads its JSON-ish output.

Responsibilities:
- Compute `git diff main...HEAD` (paths + hunks)
- Gate detection — emit per-dimension activation flags:
  - `db` if any path matches `$HARNESS_DB_MIGRATIONS_DIR` or `$HARNESS_DB_SCHEMA_PATH`
  - `langgraph` if `HARNESS_LANGGRAPH=true` AND any path matches LG conventional dirs (`src/agents/**`, `agents/**`)
  - `a11y` if any path has a frontend extension (`.tsx`, `.jsx`, `.vue`, `.svelte`, `.html`)
- Regex candidate extraction per dimension (e.g., raw SQL for security pre-screen, `process.env.` for env-handling, `Promise.all` patterns for concurrency, `console.log` for observability)
- **Exemplar-mining**: for each file changed in the diff, find up to 3 sibling files (same extension, same directory, NOT in this diff) to act as "this is how this codebase does X" reference exemplars. Falls back to up-to-3 same-extension files elsewhere in the repo if the directory has no qualifying siblings. Output paths only; the dispatched subagent reads them on demand.
- **Conventions extraction**: read repo-root `CLAUDE.md` (if present); look for a `## Conventions` or `## Patterns` section (case-insensitive). If found, emit the section body verbatim in the manifest's top-level `conventions` field. The orchestrator includes this text in every per-dim prompt so the subagent anchors its judgment to the codebase's stated conventions rather than its training data.
- Build per-dimension "scope packets": the slice of the diff most relevant to that dimension + regex candidate hits + exemplar paths

Output format (JSON written to stdout, parsed by orchestrator):
```json
{
  "diff": {"files": [...], "stats": {"+": 723, "-": 520}},
  "gates": {"db": false, "langgraph": false, "a11y": true},
  "conventions": "<verbatim ## Conventions section from CLAUDE.md, or empty string>",
  "scopes": {
    "security":   {"paths": [...], "candidates": [...], "exemplars": [...]},
    "structural": {"paths": [...], "candidates": [...], "exemplars": [...]},
    ...
  }
}
```

Exemplar selection is deterministic, not judgment-driven: same-directory siblings before elsewhere-in-repo; alphabetical within a tier; cap at 3. The model judgment ("which patterns are good") happens in the dispatched subagent, fed by the exemplar contents. This stage stays shell because picking sibling files is mechanical (harness principle §3: "Use the model only for judgment calls"). Cheap, auditable, smoke-testable.

**Why this matters:** without exemplars + conventions, the subagent's "good pattern" reference is its training data — which may not match how *this* codebase does things (Prisma vs. Drizzle, fat-controllers vs. service-objects, RSC vs. SPA). With them, the subagent can ground every finding in patterns already established in this repo.

### 4.2 Stage 2 — DISPATCH (parallel subagents)

The orchestrator emits **one assistant message containing N `Agent` tool-use blocks**, where N = number of activated dimensions (12–15 depending on gates). This is the harness's first-class parallel-dispatch pattern (§26).

Per-dimension dispatch:
- `subagent_type` is one of four agent definitions (see §6.2)
- `prompt` is assembled by concatenating: project context summary, the dimension's prompt file (`skills/deep-review/dimensions/<dim>.md`), the scope packet from stage 1, the dimension's FP profile, and the structured output format spec
- Three delegated dimensions (`security`, `db`, `langgraph`) don't get a fresh subagent — the orchestrator invokes the existing rigid skill and adapts its output to the unified finding format

#### 4.2.1 Subagent input contract — "scope packet"

```
- dimension name
- diff slice (paths + hunks relevant to this dim)
- regex candidates from SCAN
- exemplar file paths (from SCAN, 0–3 per changed file in scope) — the subagent reads
  these on demand to anchor its "what's the codebase's convention" reasoning
- conventions text (from SCAN, may be empty) — verbatim `## Conventions` / `## Patterns`
  section from CLAUDE.md if present; the subagent treats this as authoritative for what
  the codebase considers good
- project context (stack, ORM, framework — derived from CLAUDE.md preamble)
- this dim's coverage scope and anti-overlap with other dims
- severity rubric
- FP profile: HIGH | MED | LOW
- output format spec
```

**Anchoring rule (every dim prompt restates this):** when judging whether a pattern in
the diff is good or bad, the subagent must first consult `conventions` (if non-empty)
and the exemplar files. A finding that contradicts an established pattern in the exemplars
is HIGH-conviction; a finding that recommends a pattern the codebase doesn't use anywhere
is LOW-conviction (likely the subagent's training data overriding the codebase's
deliberate choice). Do not propose patterns from training data when the codebase has a
demonstrated alternative.

#### 4.2.2 Subagent output contract

```
dimension: <name>
verdict: PASS | WARN | FAIL | N/A
fp_profile: HIGH | MED | LOW
findings:
  - severity: CRITICAL | HIGH | MED | LOW | NIT
    file: path/to/file.ts
    line: 42
    title: <one-line>
    evidence: <quoted code>
    impact: <what breaks / what's at risk>
    suggested_fix: <minimal change>
    conviction: 0.0–1.0
notes: <one-line per-dimension summary>
```

#### 4.2.3 The 15 dimensions

| # | Dimension | Source | FP profile | Gated? | Model tier |
|---|-----------|--------|-----------|--------|-----------|
| 1 | security | `/security-review` delegation | HIGH | no | (own) |
| 2 | db | `/db-review` delegation | LOW | migrations only | (own) |
| 3 | langgraph | `/lg-review` delegation | LOW-MED | LG opt-in + LG paths | (own) |
| 4 | structural | new — `dimensions/structural.md` | MED-HIGH | no | deep |
| 5 | performance | new — `dimensions/performance.md` | HIGH | no | deep |
| 6 | concurrency | new — `dimensions/concurrency.md` | HIGH | no | deep |
| 7 | types | new — `dimensions/types.md` | LOW | no | standard |
| 8 | error-handling | new — `dimensions/error-handling.md` | MED | no | deep |
| 9 | observability | new — `dimensions/observability.md` | LOW | no | standard |
| 10 | tests | new — `dimensions/tests.md` | LOW | no | standard |
| 11 | api-drift | new — `dimensions/api-drift.md` | LOW | no | standard |
| 12 | deps | new — `dimensions/deps.md` | MED | no | standard |
| 13 | a11y | new — `dimensions/a11y.md` | LOW | frontend files only | standard |
| 14 | dead-code | new — `dimensions/dead-code.md` | MED | no | standard |
| 15 | docs | new — `dimensions/docs.md` | LOW | no | standard |

#### 4.2.4 Anti-overlap rules

Each dimension's prompt explicitly names what it does NOT cover, to prevent duplicate findings:

- `security` owns auth, injection, credentials, transport — NOT type safety or error handling
- `structural` owns file size, abstractions, layer violations, spaghetti — NOT performance, types, error handling
- `performance` owns N+1, hot paths, async-in-loops, memo gaps — NOT error handling around perf-critical calls
- `error-handling` owns try/catch coverage, retries, propagation, error types — NOT performance of error paths or observability of errors
- `observability` owns logs/metrics/traces/PII — NOT what to log inside an error handler (that's error-handling's call)
- `tests` owns test coverage and quality — NOT testability of the code under test (that's structural)
- `types` owns `any` usage, missing annotations on public surfaces, unsafe casts — NOT documentation of those types (that's docs)
- `dead-code` owns unused exports, unreachable branches, copy-paste — NOT structural restructuring opportunities (that's structural)

Triage (stage 3) handles dedup across dimensions for remaining overlap.

### 4.3 Stage 3 — TRIAGE (uniform, cheap model)

A single haiku-class agent reads all findings from stage 2 and applies a uniform FP filter:

- Drop findings with `conviction < threshold` (threshold tuned per FP profile: HIGH dims drop at 0.4, MED at 0.5, LOW at 0.6)
- Deduplicate findings that point at the same `file:line` from multiple dimensions; keep the highest-severity one with a merged title
- Reclassify clearly out-of-scope findings to NIT (e.g., a `types` dim flagging an `any` that's actually intentional per a same-line comment)

Output: the deduplicated findings list with an annotation per drop ("triage: low conviction" / "triage: dedup with #N").

### 4.4 Stage 4 — REVALIDATE (conditional, high-FP dims only)

Runs only for findings:
- Severity ≥ WARN, AND
- From a dimension with FP profile HIGH or MED-HIGH

That's `{security, performance, concurrency, structural, error-handling, deps, dead-code}` in practice (deps and dead-code are MED but their FPs are factual claims worth verifying).

A single revalidator agent (`subagent_type: revalidator`, opus, read-only) processes each qualifying finding through three checks:

1. **Still-present** — does the finding hold against current HEAD? (Files may have been edited since the subagent ran in a long session.)
2. **Fixed-in-history** — does `git log -p` show a commit between the diff's base and HEAD that addresses this exact issue? (Most relevant for stacked commits where an early commit introduced a bug and a later one fixed it.)
3. **Context-expansion** — read the wider context (callers, middleware, decorators, parent classes, type definitions). Does evidence outside the subagent's original scope refute the finding?

Emit `CONFIRMED` (finding holds), `DISPUTED` (refuted, demote to NIT or drop), or `FIXED` (addressed in a later commit, drop).

### 4.5 Stage 5 — SYNTHESIZE (orchestrator)

The orchestrator (parent agent, opus) assembles the final report:

- Build the verdict matrix (table of 15 dimensions × verdict)
- Group findings by severity (BLOCKING → HIGH → MED → LOW → NIT)
- Render the report (see §5)
- Save to `docs/deep-reviews/<YYYY-MM-DD>-<branch-slug>.md`
- Call `bin/deep-review-validate <report-path>` to mechanically verify the report has every dimension accounted for
- Emit final summary message citing the path
- `AskUserQuestion`: "Apply BLOCKING fixes? Y / S / N"

## 5. Report format

```markdown
# Deep Review — <branch-slug>
**Date:** <YYYY-MM-DD>
**Diff:** main..HEAD (<N> files, <+/-> lines)
**Commit:** <short-sha>
**Pipeline:** SCAN → DISPATCH(<N>) → TRIAGE → REVALIDATE → SYNTHESIZE

## TL;DR
**Verdict:** GO | NEEDS-CHANGES | NO-GO (<counts by severity>)
Blocking dimensions: <list>

## Verdict Matrix
| # | Dimension | Verdict | Findings | FP profile | Revalidated |
|---|-----------|---------|----------|-----------|-------------|
| 1 | security  | ...     | ...      | HIGH      | ...         |
...

## BLOCKING (N)
### 1. [<dim>] <file:line> — <title>
**Evidence:** <quoted code>
**Impact:** <what breaks>
**Suggested fix:** <minimal change>
**Revalidated:** CONFIRMED | DISPUTED | FIXED-IN-<sha>

## HIGH (N)
...
## MED (N)
...
## LOW (N)
...
## NIT (N)
...

## N/A dimensions
- <dim> — <one-line justification naming what it would have caught>

## Dispatched subagents
- <N> fired in parallel at <timestamp>
- <list of delegated skills invoked>

## Triage drops (N)
- <finding-id> — <reason>

## Revalidate results
- CONFIRMED: <N>
- DISPUTED: <N> (demoted/dropped)
- FIXED: <N>
```

## 6. File layout

```
skills/deep-review/
├── SKILL.md                      # rigid body, <500 words
├── pipeline.md                   # 5-stage spec, loaded by orchestrator at start
├── rationalizations.md           # baseline-harvested table
├── eval.yaml                     # ≥1 trajectory eval, required for rigid
├── red-flags.md                  # optional, if list grows past 12
└── dimensions/                   # 12 new-dimension prompt files
    ├── structural.md
    ├── performance.md
    ├── concurrency.md
    ├── types.md
    ├── error-handling.md
    ├── observability.md
    ├── tests.md
    ├── api-drift.md
    ├── deps.md
    ├── a11y.md
    ├── dead-code.md
    └── docs.md

.claude/agents/
├── dim-investigator-deep.md      # opus, read-only — HIGH-FP dimensions
├── dim-investigator.md           # sonnet, read-only — LOW-FP dimensions
├── triage.md                     # haiku, read-only — stage 3
└── revalidator.md                # opus, read-only — stage 4

bin/
├── deep-review-scan              # shell: SCAN stage
└── deep-review-validate          # shell: report-structure validator

docs/deep-reviews/                # output directory (committed)
└── <YYYY-MM-DD>-<branch-slug>.md
```

### 6.1 SKILL.md sketch

```yaml
---
name: deep-review
description: Use when the user says "/deep-review", "deep review", "thorough review", or wants the deepest possible code review before pushing a branch.
user-invocable: true
tier: rigid
kind: verification
---
```

The description is trigger-only per `skills/CONVENTIONS.md` § `description = trigger, not summary` and harness principle §10. The body describes the pipeline, dimensions, advisory posture, and cost.

Body sections:
- `<update-check>` block
- Override preamble
- One-paragraph description
- The Iron Law (§7)
- Cycle / Steps — short pointer to `pipeline.md`
- Red Flags (10 bullets, §7)
- Common Rationalizations pointer to `rationalizations.md`
- Self-Review Checklist (6 items, §7)
- What this skill does NOT cover

Target body length: <500 words per `skills/CONVENTIONS.md`.

### 6.2 Agent definitions

Each `.claude/agents/<name>.md` is short (5–15 lines):

```yaml
---
model: opus  # or sonnet, haiku
disallowedTools:
  - Edit
  - Write
  - MultiEdit
  - NotebookEdit
---
# <Role Name>
<one-paragraph role description>

## Output format
<the structured output spec from §4.2.2>

## Rules
- Read-only
- Cite file:line for every finding
- Quote evidence verbatim
- Declare conviction 0.0–1.0 per finding
```

Four agent files cover the matrix:
- `dim-investigator-deep` — opus, used for `{structural, performance, concurrency, error-handling}`
- `dim-investigator` — sonnet, used for `{types, observability, tests, api-drift, deps, a11y, dead-code, docs}`
- `triage` — haiku, used by stage 3 across all findings
- `revalidator` — opus, used by stage 4 for high-FP findings ≥ WARN

`security`, `db`, and `langgraph` are delegated to their existing rigid skills — they don't use these agent definitions.

## 7. Rigidity — Iron Law, red flags, rationalization table

### 7.1 Iron Law

```
NO REVIEW VERDICT WITHOUT EVERY DIMENSION REACHING PASS/WARN/FAIL/N/A AND EVERY PIPELINE STAGE EXECUTED
```

Four lines of "no exceptions" guidance:
1. Spot-checking is not depth. The 15-dimension fan-out is the audit.
2. N/A requires a one-line justification naming what the dimension would have caught and why this diff has no surface for it.
3. Subagent summaries are inputs to the orchestrator's judgment, not the verdict itself. The orchestrator reads ≥1 cited `file:line` per HIGH/CRITICAL finding directly.
4. Triage filters; revalidate confirms; synthesis ranks. Skipping any stage collapses depth into noise.

### 7.2 Red Flags (10)

- "The diff is small, just check the obvious ones."
- "Most dimensions don't apply, skip them."
- "Triage already filtered, revalidate is overkill."
- "Subagent says PASS — accept it."
- "We've shipped 100 PRs without this; the bar is too high."
- "Condense the report to fit context — drop the LOW findings."
- "Run dimensions sequentially to save context — don't fan out."
- "I read the subagent's summary; reading the code is theatre."
- Marking the `security` or `error-handling` dimension N/A without justification.
- Producing a verdict without saving the report to `docs/deep-reviews/`.

### 7.3 Rationalization table — sourcing discipline

Per `.claude/docs/harness-principles.md` §11 and `/write-skill`'s contract, `rationalizations.md` is **harvested, not invented**. Before the skill ships:

1. Run `/skill-baseline` against four pressure scenarios:
   - `deep-review-time-pressure` — "PR needs to ship in 20 min, just do the security-critical dimensions"
   - `deep-review-sunk-cost` — "I already ran 10 subagents, the remaining 5 will probably also pass"
   - `deep-review-authority` — "Senior engineer reviewed it informally and approved"
   - `deep-review-context-exhaustion` — "Running out of context, summarize subagent outputs without quoting evidence"
2. Capture the verbatim rationalizations the unaided subagent produces.
3. Populate `rationalizations.md` from the transcripts (each row is the literal quote paired with a one-line reality counter).
4. Re-baseline with the upgraded skill loaded. Confirm pass. If still failing, identify the new rationalization, append, iterate (REFACTOR phase).

### 7.4 Self-Review Checklist

- [ ] Every one of the 15 dimensions produced a verdict (or N/A with one-line justification).
- [ ] All stage-2 dispatches went out as parallel `Agent` calls in a single message (not sequentially).
- [ ] Triage was run; conviction-below-threshold findings dropped (not just buried).
- [ ] Every high-FP-dimension finding ≥ WARN went through revalidate; verdict is CONFIRMED / DISPUTED / FIXED.
- [ ] At least one `file:line` evidence quote read directly (not just from subagent summary) for each HIGH/CRITICAL finding.
- [ ] Report saved to `docs/deep-reviews/<date>-<slug>.md` and `bin/deep-review-validate` passes against it.

## 8. Cost & performance

| Stage | Component | Model | Approx cost (mid PR) |
|-------|-----------|-------|---------------------|
| 1 | SCAN — shell | none | $0 |
| 2 | 5 HIGH-FP dim subagents | opus | ~$7–8 |
| 2 | 7 LOW-FP dim subagents | sonnet | ~$1.50–2 |
| 2 | `/security-review` delegation | (own) | ~$2–5 |
| 2 | `/db-review` delegation (if applicable) | (own) | ~$0.50 |
| 2 | `/lg-review` delegation (if applicable) | (own) | ~$0.50 |
| 3 | TRIAGE | haiku | ~$0.05–0.10 |
| 4 | REVALIDATE (5–15 findings) | opus | ~$0.50–1.00 |
| 5 | SYNTHESIZE | orchestrator (opus) | included in parent |

**Total ballpark: $10–15 mid PR, $3–5 small PR, $30–50 large PR.**

Surface this in `SKILL.md`'s "What this skill does NOT cover" so users know it's the deep tier, not a per-commit pass.

**Wall-clock:** dominated by the slowest stage-2 subagent (deepest dimension on the largest diff slice). Estimated 3–8 minutes per run.

## 9. Integration

- **No auto-fire from `/pre-deploy` or `/ship`.** Advisory only.
- **Optional**: `/pre-deploy` output may include a one-line callout: "For deeper coverage, run /deep-review before pushing." This is a doc change, not a control-flow change.
- **No conflict with built-in `/review`**: distinct name, distinct purpose (local diff + multi-dim pipeline; not a GitHub PR-comment author).
- **VERSION bump:** 0.15.0 → 0.16.0 in the same PR as the skill, per `CLAUDE.md` § VERSION rule.
- **`<update-check>` block:** required at top of `SKILL.md`.

## 10. Out of scope (v1)

- Per-dimension opt-out flags (`--skip=tests,docs`)
- Scope overrides (`--since=HEAD~5`, `<path>` argument)
- A `--quick` mode that skips revalidate and downgrades opus dims to sonnet
- Repo-wide audit (deepsec-style full-repo scan)
- GitHub PR comment posting
- Slack / email integration
- Long-term metrics tracking across runs (true-positive rate per dimension)

These wait for v2 once the deep version proves its value.

## 11. Risks & open questions

| Risk | Mitigation |
|------|-----------|
| Context exhaustion in the orchestrator (15 subagent results returned) | Each subagent returns a structured summary, not full transcript; full transcripts cached to disk if needed |
| Subagent prompt drift (each dim's prompt evolves separately, anti-overlap rules drift) | Stage 5 synthesizes from structured output; triage handles overlap; quarterly review of `dimensions/*.md` |
| FP rate higher than expected on new dims (structural, performance) | Conditional revalidate is exactly the mitigation; tune conviction thresholds per FP profile after observing real runs |
| `bin/deep-review-scan` becomes a parser bottleneck | It's shell; profile if slow. Stage 1 has no model calls so cost is wall-clock only |
| The 15-dim coverage misses something | "What this skill does NOT cover" enumerates legitimate exemptions; future v2 can add dims |

## 12. Acceptance criteria

The skill is ready to ship when:

1. `SKILL.md` is under 500 words and `bin/test-frontmatter` passes
2. `pipeline.md`, 12 `dimensions/*.md` files, and `rationalizations.md` exist
3. Four agent definitions exist under `.claude/agents/`
4. `bin/deep-review-scan` and `bin/deep-review-validate` exist, are executable, and have shell smoke tests
5. `eval.yaml` declares ≥1 trajectory eval traced to a GREEN baseline transcript; `bin/skill-eval --validate` passes
6. `/skill-baseline` has been run on the four pressure scenarios; the unaided subagent fails, the upgraded skill passes
7. `VERSION` is bumped to 0.16.0 in the same commit/PR
8. End-to-end smoke: run `/deep-review` against a real branch with a synthetic finding planted per dimension; verify the report flags it and revalidate handles a planted-fix scenario correctly

## 13. References

- `.claude/docs/harness-principles.md` — design philosophy this skill follows
- `skills/CONVENTIONS.md` — frontmatter and rigid-skill contract
- `skills/_template-rigid/TEMPLATE.md` — rigid-skill body template
- `skills/security-review/{SKILL.md,phases.md,rationalizations.md}` — closest precedent
- `skills/db-review/SKILL.md`, `skills/lg-review/SKILL.md` — sibling rigid reviews
- `.claude/agents/validator.md` — agent-definition pattern
- [Cursor thermo-nuclear-code-quality-review](https://github.com/cursor/plugins/blob/main/cursor-team-kit/skills/thermo-nuclear-code-quality-review/SKILL.md) — maintainability lens inspiration
- [Vercel deepsec](https://github.com/vercel-labs/deepsec) — staged pipeline / FP reduction inspiration
