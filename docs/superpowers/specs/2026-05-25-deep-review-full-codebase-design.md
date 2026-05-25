# /deep-review — Full-Codebase Mode

**Date:** 2026-05-25
**Status:** Approved (brainstorming complete; ready for implementation plan)
**Author:** Mark Hazlett + Claude

## Problem

`/deep-review` today is hard-coded to `git diff main...HEAD`. The "What this skill does NOT cover" section explicitly excludes "Full-repo / module-wide audits." Users who want to audit an entire codebase (e.g., onboarding into a new repo, pre-release sweep, post-acquisition due diligence) have no path through `/deep-review` — they have to fall back to ad-hoc prompts that lose the 15-dimension fan-out, the triage/revalidate gates, and the recorded-conventions feedback loop.

The user asked: "add a full codebase feature to /deep-review … warn the user before doing it roughly how much it will cost."

## Goals

1. Let `/deep-review` audit the entire tracked codebase, not just the branch diff.
2. Force a cost-acknowledgment gate before any model fan-out begins.
3. Preserve the existing Iron Law: every dimension reaches a verdict per chunk, every stage executes.
4. Reuse the existing 15-dim pipeline + triage + revalidate + decide + synthesis — do not fork it.

## Non-Goals

- Telemetry-driven cost estimation. The estimate uses a static `$12 × chunk-count` heuristic derived from the existing typical mid-PR cost ($10–15 in `SKILL.md`). Refinement happens later if telemetry warrants.
- Interactive subset-picker. The cost gate offers Proceed / Cancel only.
- Parallel chunk dispatch. Chunks run sequentially to bound concurrency; intra-chunk 15-dim fan-out is unchanged (still parallel within a chunk).
- Per-ecosystem fanciness in module detection beyond the listed manifests. If a project uses an exotic build system, the top-level-directory fallback covers it.

## Design

### Trigger

Natural-language phrase in the `/deep-review` args, parsed by the orchestrator (Stage 0, before SCAN). Matching phrases (case-insensitive, substring match against the args string):

- `entire codebase`
- `full codebase`
- `whole codebase`
- `whole repo`
- `the whole repository`

Match → full-codebase mode. No match → existing branch-diff mode (unchanged default behavior).

The `SKILL.md` `description:` frontmatter is updated to include these phrases so the skill auto-fires on them.

### Stage 1 — SCAN (`bin/deep-review-scan --full-codebase`)

A new flag adds a full-codebase scan path alongside the existing diff scan path. Behavior:

1. Walks `git ls-files` (this honors `.gitignore` and `.git/info/exclude` for free).
2. **Module detection.** For each tracked file, walks up the directory tree until it finds one of: `package.json`, `pyproject.toml`, `setup.py`, `go.mod`, `Cargo.toml`, `Gemfile`. The directory containing the manifest is the module root.
3. If no manifest is found anywhere in the repo, fall back to top-level directory grouping (one chunk per top-level dir, plus a `root` chunk for files at the repo root).
4. Files that don't fall under any detected module root are grouped into a `misc` chunk.
5. **Per-chunk gate detection.** Each chunk runs the existing gate logic (db, langgraph, a11y) scoped to that chunk's paths.
6. **Per-chunk exemplar mining.** Each chunk gets exemplars sampled from its own paths (rather than the diff scope). Cap: 3 exemplars per dimension per chunk.
7. **Emit manifest:**

```json
{
  "mode": "full-codebase",
  "chunks": [
    {
      "name": "module-name",
      "manifest": "path/to/package.json",
      "files": ["path/to/a.ts", ...],
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

The existing diff-mode manifest shape (with `diff`, `gates`, `scopes` at the top level) is preserved unchanged when `--full-codebase` is absent.

### Stage 0.5 — Cost gate (orchestrator)

After SCAN, before any dispatch:

1. Compute `low = totals.chunks × $10`, `high = totals.chunks × $15`.
2. Compute wall-clock `low_min = totals.chunks × 3`, `high_min = totals.chunks × 8`.
3. Render the chunk list (name + file count + LOC, sorted descending by LOC).
4. Call `AskUserQuestion`:
   - `question`: "Full-codebase /deep-review will run the 15-dim pipeline against N chunks. Proceed?"
   - `header`: "Cost gate"
   - `options`:
     - `{label: "Proceed", description: "Run the full review. Estimated cost $<low>–$<high>, wall-clock ~<low_min>–<high_min> min."}`
     - `{label: "Cancel", description: "Abort. No model calls made."}`
5. If Cancel, exit cleanly with a one-line note. No report written.

The chunk list itself is printed to the user's transcript before the AskUserQuestion call so they can read the breakdown alongside the choice.

### Stage 2–5 (per chunk)

For each chunk in `manifest.chunks`:

1. **Stage 2 DISPATCH.** Emit ONE message with N parallel `Agent` calls (15 minus gated-skip count), exactly as in diff mode. The scope packet for each dim subagent uses the chunk's `paths` and `exemplars`. The SCOPE PACKET section drops "Diff hunks" and replaces it with "File contents:" — subagents reading whole files instead of hunks.
2. **Stage 3 TRIAGE.** Per-chunk triage dispatch; same conviction floors per FP profile.
3. **Stage 4 REVALIDATE.** Per-chunk revalidate dispatch; same trigger rules.
4. **Stage 4.5 DECIDE.** Per-chunk divergence resolution. Cap raised from 4 to **8 per chunk** since full-codebase audits legitimately surface more pattern divergences. (Total across all chunks could still be large; tolerable because each chunk is a coherent unit and the user is already in audit mode.)
5. **Stage 5 partial synthesis.** Produce a per-chunk report fragment in memory (same skeleton as today's diff report, but `Diff:` line replaced with `Scope: <chunk-name> (<file-count> files, <line-count> lines)`).

Chunks run **sequentially** in the orchestrator's outer loop. Within a chunk, the 15-dim fan-out is parallel as today.

### Stage 5.5 — Aggregate synthesis

After all chunks complete:

1. Compose the aggregate report file at `.deep-review/<YYYY-MM-DD>-full-codebase-<short-sha>.md`.
2. Top-level verdict rolls up the worst per-chunk verdict:
   - Any chunk verdict "Substantial concerns" → aggregate "Substantial concerns"
   - Else any chunk "Address blocking items first" → aggregate "Address blocking items first"
   - Else "Ship it"
3. Top-level structure:

```markdown
# Code Review — full-codebase
**Date:** <YYYY-MM-DD>
**Scope:** Full codebase (N chunks, M files, K lines)
**Commit:** <short-sha>
**Reviewer:** /deep-review --full-codebase (N × (SCAN → 15 dim subagents → triage → revalidate → decide → synthesis))

## Summary
<one paragraph; aggregate framing>
**Verdict:** <rolled-up verdict>

## Chunks reviewed
| # | Chunk | Files | Lines | Verdict | (blocking) items |
|---|-------|-------|-------|---------|-----------------|

## Chunk: <module-name>
<the per-chunk report skeleton, as-is>

## Chunk: <next-module>
<...>

## Conventions recorded (aggregate)
<merged from all chunks>

## Pipeline notes
- Mode: full-codebase
- Chunks: N
- Total dispatches: N × 15 (minus gated skips)
- Cost (estimated): $<low>–$<high>
- Wall-clock (actual): <recorded>
```

4. Run `bin/deep-review-validate <path>` — must exit 0.
5. Apply-fixes prompt (Stage 5 step 4 from today's pipeline) runs once at the aggregate level, listing all `(blocking)` findings across chunks.

### Validator changes (`bin/deep-review-validate`)

The validator must accept the new aggregate report shape. Concretely:

- Recognize `**Scope:** Full codebase` as a valid alternative to `**Diff:** main..HEAD`.
- Recognize the `## Chunks reviewed` table as a valid alternative to the single `## What I audited` matrix at the top level.
- Per-chunk verdict matrices live inside each `## Chunk:` subsection and must still validate per the existing rules.

### `bin/deep-review-record-convention`

No changes required. Stage 4.5 calls it per-chunk exactly as today; the script appends to `CLAUDE.md ## Conventions` regardless of caller context.

### SKILL.md changes

1. Update `description:` to include the new trigger phrases.
2. Update the line-20 cost callout: `typical mid-PR cost is $10–15 and 3–8 min; full-codebase cost ≈ $10–15 × chunk-count and 3–8 min × chunk-count`.
3. Add a `## Full-codebase mode` section between `## Gate Sequence` and `## Red Flags` describing trigger phrases, the cost gate, and the per-chunk loop.
4. Remove the line `**Full-repo / module-wide audits.** Scope is always main..HEAD. Repo-wide deepsec-style scans are a future feature.` from `## What this skill does NOT cover`.
5. Add a Self-Review checkbox: `[ ] If full-codebase mode: cost gate was acknowledged before dispatch; aggregate report includes per-chunk subsections.`

### pipeline.md changes

Add a `## Full-codebase mode` section after Stage 5 documenting:
- The new SCAN flag and manifest shape
- The cost gate AskUserQuestion contract
- The per-chunk loop semantics
- The aggregate synthesis skeleton
- The validator's relaxed expectations

### VERSION

Bump `0.19.1 → 0.20.0` (minor — new mode/feature).

## Component boundaries

- **`bin/deep-review-scan`**: pure-shell, no model calls. Owns module detection, gate detection, exemplar mining, manifest emission. Takes `--full-codebase` flag; otherwise unchanged.
- **Orchestrator (SKILL.md + pipeline.md, executed by Claude)**: owns mode detection, cost gate, per-chunk loop, aggregate synthesis. No new binary needed.
- **`bin/deep-review-validate`**: validates either report shape. Extended, not replaced.
- **`bin/deep-review-record-convention`**: unchanged.

The boundary that matters: SCAN owns "what to review and in what units." The orchestrator owns "when to confirm with the user and how to compose." Neither knows about the other beyond the manifest contract.

## Testing

1. **Unit-level (scan):** Add a fixture repo with mixed-ecosystem manifests under `bin/test-fixtures/full-codebase-repo/` and assert the chunks JSON matches expectations.
2. **Validator:** Add fixture report files under `bin/test-fixtures/deep-review-reports/` for both shapes (diff + full-codebase). Existing test runner picks them up.
3. **End-to-end:** Manual test on this harness repo (`/deep-review the entire codebase`). Cost-gate prompt fires; cancel → no report; proceed → full pipeline runs.

## Risks & mitigations

| Risk | Mitigation |
|------|------------|
| User runs full-codebase on a giant monorepo and burns $500 unexpectedly | Cost gate is explicit; estimate shown before any model calls. |
| Per-chunk Stage 4.5 spams the user with 8 questions × N chunks | Cap is per-chunk; if a chunk has zero divergences the stage skips. User can still Cancel at the cost gate. |
| Aggregate report exceeds context window during synthesis | Each chunk's report fragment is built and validated independently before concatenation; orchestrator never holds all 15-dim raw outputs at once. |
| Validator breaks on existing diff-mode reports | Validator extension is additive — diff-mode shape stays valid. Regression-tested via fixture reports. |
| NL phrase parser misfires on ambiguous args (e.g., "my work on the entire auth module") | Trigger phrases are bounded and explicit ("entire codebase", not "entire X"). Ambiguous args fall through to diff mode; user gets the expected behavior or can re-invoke with clearer wording. |

## What this design does NOT decide

- Whether full-codebase reports get committed by default or `.gitignore`d. Same policy as today: per-repo team choice.
- How to display incremental progress to the user during a long run. The orchestrator's user-facing text updates per stage are sufficient; no progress bar.
- A "resume from chunk N" feature if interrupted. Out of scope; a re-run with the same HEAD overwrites at `.deep-review/<date>-full-codebase-<sha>.md` so it's idempotent.

## Open question for the user

None — all design choices were settled in brainstorming. Spec is ready for implementation planning.
