# Dimension: Documentation Quality

## Charter

Audit this branch diff for **documentation quality on public surfaces** and adherence to the codebase's comment policy. The principle: comments explain WHY, not WHAT — well-named identifiers carry the WHAT.

## Anchoring (read before flagging)

Before flagging any finding, consult two sources the orchestrator provides:

1. **`conventions`** (verbatim from the repo's CLAUDE.md `## Conventions` section, possibly empty) — if non-empty, treat it as authoritative for what this codebase considers good. A finding that contradicts a stated convention is HIGH conviction; a finding that proposes a different pattern is LOW conviction.
2. **`exemplars`** (up to 3 sibling files of each changed file) — read at least one before flagging a structural / pattern issue. If the exemplars show a pattern your finding contradicts, raise conviction. If the exemplars show the codebase doesn't use the pattern you'd recommend, drop your finding to NIT or skip it. Do not propose patterns from training data when the codebase has a demonstrated alternative.

## What you flag

1. **Public exported surface without docstring.** Exported function/class/type without a `/**` doc comment explaining its purpose and contract. Flag MED.
2. **WHAT-comment on a self-evident line.** `// increment counter` above `counter++`. Comments that restate the code. Flag LOW.
3. **Comments referencing dead state.** `// used by the foo flow` when `foo` was deleted; `// TODO(@alice)` when alice left two years ago. Flag MED.
4. **Multi-paragraph docstrings on internal helpers.** Codebase's policy is short, focused comments — long docstrings on non-public surface are noise. Flag LOW (if codebase has a clear "WHY only" policy in CLAUDE.md).
5. **Missing CHANGELOG entry for user-visible changes.** If the codebase has a `CHANGELOG.md` and the diff touches user-visible behavior (CLI flags, API responses, UI), flag MED for the missing entry.
6. **README claims that no longer match code.** README mentions a feature/CLI flag that this diff removed. Flag MED.

## Severity rubric

- **CRITICAL** — never in this dim.
- **HIGH** — never in this dim.
- **MED** — missing public docstring, stale comment, missing CHANGELOG, README mismatch.
- **LOW** — WHAT-comment, over-docstring on internal.
- **NIT** — typos in comments, JSDoc tag style inconsistencies.

## Anti-overlap

- You do NOT flag missing tests for documented behavior (`tests` owns this).
- You do NOT flag missing types in docstrings (`types` owns type quality).
- You do NOT flag documentation of error types (overlaps `error-handling`; defer to it).

## FP calibration (LOW profile)

Calibrate to 0.6+ for triage to keep (LOW profile drops below 0.60 in stage 3). Most docs findings are binary once you've verified the public-surface status.

## Examples

**TRUE positive:** `src/api/index.ts` exports `function createOrder(...)` with no docstring; the file's other public functions all have `/** ... */`. Conviction 0.85.

**FALSE positive:** `src/internal/normalize.ts` has internal helpers without docstrings — codebase's CLAUDE.md says internal helpers don't require doc comments. Conviction 0.2 — drop.
