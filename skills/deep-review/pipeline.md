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
    "<dim>": { "paths": [...], "exemplars": [...] }
  }
}
```

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
A finding that contradicts a stated convention is HIGH conviction;
a finding that proposes a different pattern is LOW conviction.

REFERENCE EXEMPLARS (existing files in this codebase you should treat as
authoritative for "good pattern"):
<list of exemplar paths from SCAN — read at least one before flagging
any pattern/structural finding. If the exemplars show a pattern your
finding contradicts, raise conviction. If the exemplars show the codebase
doesn't use the pattern you'd recommend, drop your finding to NIT or skip.>

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
  divergence:                   # OPTIONAL — only on `kind: question`. Triggers Stage 4.5.
    domain: <short label, e.g. "error handling style", "logging format", "test framework">
    options:
      - label: <one-line description of pattern A>
        evidence: ["path/to/a:42", "path/to/a2:18"]
      - label: <one-line description of pattern B>
        evidence: ["path/to/b:14"]
```

### When to emit `divergence`

A `kind: question` finding with `divergence:` populated is the dim subagent's way of saying: "I see ≥2 competing patterns for the same thing in the diff (or in the exemplars). The CONVENTIONS string from SCAN is silent on the choice. I can't tell which the author wants." The orchestrator surfaces these in Stage 4.5 and persists the user's decision to `CLAUDE.md` so future runs treat deviation as HIGH-conviction. Emit one finding per domain, not one per occurrence.

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

## Stage 4.5 — DECIDE pattern divergences (orchestrator + AskUserQuestion)

The dim subagents emit `kind: question` findings with `divergence:` populated when they see competing patterns and the CONVENTIONS string is silent on which is canonical. This stage turns those into recorded decisions before synthesis, so the next `/deep-review` run automatically enforces them.

**Algorithm:**

1. Collect every surviving finding with `divergence:` set (post-triage, post-revalidate).
2. Cap at **4 per run** (anti-fatigue: a real legacy diff can surface dozens; asking 20 questions sequentially makes the user dismiss them all). The remainder become `kind: chore` findings in the report with title `Pattern divergence on <domain> (deferred)` and the divergence options as evidence — so they're not lost.
3. For each capped divergence, the orchestrator calls `AskUserQuestion` with **one single-select question per divergence** (not multi-select, not batched):
   - `question`: `"Which pattern is canonical for <domain>?"`
   - `header`: `<domain>` truncated to 12 chars
   - `options`: each `divergence.options[i].label` as an option label, with `preview:` set to the file:line evidence for that option (rendered as a small markdown block showing the code samples). Add a final option `Skip — capture as chore` so the user can defer.
   - One question at a time — the AskUserQuestion tool supports multiple questions per call, but coupling pattern decisions across one prompt makes the side-by-side preview less effective.
4. After each answered divergence (not `Skip`):
   ```
   bash bin/deep-review-record-convention \
     --domain "<divergence.domain>" \
     --pattern "<the option's label>" \
     --why "<auto-generated: 'chosen during /deep-review on <date> over <other option labels>'>" \
     --evidence "<comma-joined file:line citations from all options>"
   ```
   The script appends to `CLAUDE.md` `## Conventions` (creating the section if absent). The choice is persisted; the next SCAN reads it back via the existing conventions-extraction path.
5. Skipped (or beyond-cap) divergences are written as `kind: chore` into the report under `## Worth thinking about` so the user sees them in the report even if not interactively resolved.

**Why this is its own stage:**
- It must run after Stage 4 (revalidate may DISPUTE a divergence — e.g., one of the "options" was already a known anti-pattern caught elsewhere).
- It must run before Stage 5 (the report's `## Conventions recorded` section depends on the answers).
- It's the only stage that mutates state outside `.deep-review/` (it edits `CLAUDE.md`). Treat its writes as auditable: every entry in `CLAUDE.md ## Conventions` is timestamped with the date `/deep-review` recorded it.

**Skip the stage entirely if** no divergence findings survived — proceed straight to synthesis.

---

## Stage 5 — SYNTHESIZE (orchestrator)

Build the final report. Save to `.deep-review/<YYYY-MM-DD>-<branch-slug>-<short-sha>.md` at the repo root. Branch slug = `git branch --show-current` with `/` replaced by `-`. Short-sha = `git rev-parse --short HEAD`. The short-sha suffix keeps re-runs on the same date+branch from silently overwriting each other while staying idempotent at the same HEAD.

The `.deep-review/` directory is a dotfile-style local-tooling output folder (think `.vscode/`, `.idea/`): the harness creates it on first run and writes reports into it. Teams choose whether to commit reports or `.gitignore` them on a per-repo basis — the skill is agnostic. The previous `docs/deep-reviews/` location was renamed in version 0.17.0 to avoid colliding with project doc conventions.

Then:
1. Run `bin/deep-review-validate <path>` — must exit 0.
2. Print the report path in your final message.
3. Call the `AskUserQuestion` tool with one single-select question: "Apply blocking fixes?" with options "Y (all)" / "S (step-by-step)" / "N (none — just review)". Wait for the user's answer.
4. If Y or S: dispatch implementation subagents **sequentially** (one Agent block per message, not parallel) for each `(blocking)` finding with `suggested_fix` + `file:line` + `evidence`. The Stage 2 fan-out pattern does not apply here — two parallel Edit-permitted agents targeting the same file race, and blocking items in the same file are plausible. After each fix, run `$HARNESS_TEST_CMD`. Step-by-step asks the user between findings.

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
**Reviewer:** /deep-review (SCAN → <N> dim subagents → triage → revalidate → decide → synthesis)

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

<-- If Stage 4.5 recorded any conventions, list them here so the user sees
the new rules that future reviews will enforce. Skip the section if no
divergences were decided this run. -->

## Conventions recorded (<N> items)

- **<domain>:** <pattern chosen>. <why>. _(seen at: <evidence>; written to CLAUDE.md ## Conventions)_

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
- Decide: <N> divergences surfaced, <N> recorded to CLAUDE.md, <N> deferred as chore (or "none")
```

### What changed from prior versions

- The five severity sections (`## BLOCKING`, `## HIGH`, `## MED`, `## LOW`, `## NIT`) are gone. The output is binary: `## Before merge` (blocking) and `## Worth thinking about` (everything else). `## Worth calling out` is the praise section.
- The verdict matrix is kept (it's the audit-trail receipt) but moved below the prose so the human-readable review leads.
- The verdict line is one of three phrases, not a CRIT/H/M/L count.
- Per-finding labels follow Conventional Comments, which gives the reader fast scannability without implying false severity precision.

---

## Full-codebase mode

Triggered from `SKILL.md` § Full-codebase mode. This section documents the mechanics: manifest shape, cost gate, per-chunk loop, aggregate synthesis.

### Stage 1 — SCAN (`bin/deep-review-scan --full-codebase`)

Invoke `bin/deep-review-scan --full-codebase`. The scan walks `git ls-files` (honoring `.gitignore`), groups files by detected module manifest, and emits:

```json
{
  "mode": "full-codebase",
  "chunks": [
    {
      "name": "packages/web",
      "files": ["packages/web/src/a.ts", ...],
      "stats": {"files": 42, "lines": 8400},
      "gates": {"db": false, "langgraph": false, "a11y": true},
      "scopes": { "<dim>": { "paths": [...], "exemplars": [...] } }
    },
    ...
  ],
  "conventions": "<verbatim ## Conventions from CLAUDE.md>",
  "totals": {"chunks": N, "files": M, "lines": K}
}
```

Module detection walks each file's parent directories looking for `package.json`, `pyproject.toml`, `setup.py`, `go.mod`, `Cargo.toml`, or `Gemfile`. If no manifest is found anywhere in the repo, the scan falls back to top-level-directory grouping (one chunk per top-level dir, plus a `root` chunk for files at the repo root). Files under no detected module root go to a `misc` chunk.

### Stage 0.5 — cost gate

Mandatory before any Stage 2 dispatch in full-codebase mode. The orchestrator:

1. Reads `manifest.totals.chunks` (call it `N`).
2. Prints the chunk list to the transcript: `chunk-name (file-count files, line-count lines)`, sorted descending by line count.
3. Calls `AskUserQuestion`:
   - `question`: `"Full-codebase /deep-review will run the 15-dim pipeline against <N> chunks. Proceed?"`
   - `header`: `"Cost gate"`
   - `options`:
     - `Proceed` — `description`: `"Estimated cost $<N×10>–$<N×15>, wall-clock ~<N×3>–<N×8> min."`
     - `Cancel` — `description`: `"Abort. No model calls made."`
4. `Cancel` → exit with `"/deep-review --full-codebase cancelled at cost gate."` and no report file. `Proceed` → continue to the per-chunk loop.

### Stages 2–5 per chunk

For each chunk in `manifest.chunks`:
- **Stage 2 DISPATCH.** Emit one message with N parallel `Agent` calls (15 minus gated-skip count). The SCOPE PACKET section of each per-dim prompt drops the "Diff hunks" subsection and uses `"File contents:"` instead — subagents read whole files in the chunk's paths.
- **Stage 3 TRIAGE.** Same conviction floors per FP profile.
- **Stage 4 REVALIDATE.** Same trigger rules.
- **Stage 4.5 DECIDE.** Cap raised from 4 to **8 per chunk** since full-codebase audits legitimately surface more pattern divergences.
- **Stage 5 partial synthesis.** Build the per-chunk report fragment using today's report skeleton, with `**Diff:**` replaced by `**Scope:** <chunk-name> (<files> files, <lines> lines)`.

Chunks run sequentially in the orchestrator's outer loop.

### Stage 5.5 — aggregate synthesis

Compose the aggregate report at `.deep-review/<YYYY-MM-DD>-full-codebase-<short-sha>.md`. Top-level verdict rolls up the worst per-chunk verdict: any chunk `Substantial concerns` → aggregate `Substantial concerns`; else any chunk `Address blocking items first` → aggregate `Address blocking items first`; else `Ship it`.

Skeleton:

```markdown
# Code Review — full-codebase
**Date:** <YYYY-MM-DD>
**Scope:** Full codebase (<N> chunks, <M> files, <K> lines)
**Commit:** <short-sha>
**Reviewer:** /deep-review --full-codebase (<N> × (SCAN → 15 dim subagents → triage → revalidate → decide → synthesis))

## Summary

<one paragraph; aggregate framing>

**Verdict:** Ship it | Address blocking items first | Substantial concerns

## Chunks reviewed

| # | Chunk | Files | Lines | Verdict | (blocking) items |
|---|-------|-------|-------|---------|-----------------|
| 1 | <name> | <N> | <L> | <verdict> | <count> |
| ... | | | | | |

## Chunk: <module-name>

<the per-chunk report skeleton, as-is — with **Scope:** instead of **Diff:**>

## Chunk: <next-module>

<...>

## Conventions recorded (aggregate)

<merged from all chunks; same per-domain format>

## Pipeline notes

- Mode: full-codebase
- Chunks: <N>
- Total dispatches: <N × 15> (minus gated skips)
- Cost (estimated): $<low>–$<high>
- Wall-clock (actual): <recorded by orchestrator>
```

Run `bin/deep-review-validate <path>` — must exit 0. Apply-fixes prompt runs once at the aggregate level, listing all `(blocking)` findings across chunks.

### Validator notes

`bin/deep-review-validate` accepts both diff and aggregate shapes. For aggregate reports (detected by the `**Scope:** Full codebase` prefix), the validator additionally requires a `## Chunks reviewed` section. Per-chunk dimension matrices satisfy the existing matrix-row checks because each chunk's `## What I audited` table is grep-matched at file scope.
