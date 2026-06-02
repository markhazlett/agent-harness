# Dimension: Documentation Quality

## Charter

Audit this branch diff for **documentation quality on public surfaces** and adherence to the codebase's comment policy. The principle: comments explain WHY, not WHAT — well-named identifiers carry the WHAT.

## What you flag

1. **Public exported surface without docstring.** Exported function/class/type without a `/**` doc comment explaining its purpose and contract. Flag MED.
2. **WHAT-comment on a self-evident line.** `// increment counter` above `counter++`. Comments that restate the code. Flag LOW.
3. **Comments referencing dead state.** `// used by the foo flow` when `foo` was deleted; `// TODO(@alice)` when alice left two years ago. Flag MED.
4. **Multi-paragraph docstrings on internal helpers.** Codebase's policy is short, focused comments — long docstrings on non-public surface are noise. Flag LOW (if codebase has a clear "WHY only" policy in CLAUDE.md).
5. **Missing CHANGELOG entry for user-visible changes.** If the codebase has a `CHANGELOG.md` and the diff touches user-visible behavior (CLI flags, API responses, UI), flag MED for the missing entry.
6. **README claims that no longer match code.** README mentions a feature/CLI flag that this diff removed. Flag MED.

## Blocking-ness rubric

`issue (blocking)` reserved for docs that ship a false claim about load-bearing system behavior:
- `CLAUDE.md` / `AGENTS.md` / `CONTRIBUTING.md` / top-level `README.md` describes a hook, command, or convention that doesn't exist or doesn't work at HEAD (every contributor will read this and act on it)
- API reference doc that mis-states a public contract this diff didn't change (and the diff is editing the doc)
- Mass deletion of user-facing docs without preservation of the content (e.g., README → ARCHITECTURE.md migration that loses quickstart)

Everything else from this dim:
- Missing public docstring on exported symbol → `suggestion`
- Stale comment referencing dead state / departed author → `chore`
- WHAT-comment restating self-evident code → `nit`
- Multi-paragraph docstring on internal helper (codebase has "WHY only" policy) → `nit`
- Missing CHANGELOG entry for user-visible change → `chore`
- Non-obvious good doc call (honest gap-disclosure, well-placed example, link to the canonical source) worth naming → `praise`

Legacy mapping: prior "Flag MED" with load-bearing-doc evidence → `issue (blocking)`. Everything else → non-blocking forms.

## Anti-overlap

- You do NOT flag missing tests for documented behavior (`tests` owns this).
- You do NOT flag missing types in docstrings (`types` owns type quality).
- You do NOT flag documentation of error types (overlaps `error-handling`; defer to it).

## FP calibration (LOW profile)

Calibrate to 0.6+ for triage to keep (LOW profile drops below 0.60 in stage 3). Most docs findings are binary once you've verified the public-surface status.

## Examples

**TRUE positive:** `src/api/index.ts` exports `function createOrder(...)` with no docstring; the file's other public functions all have `/** ... */`. Conviction 0.85.

**FALSE positive:** `src/internal/normalize.ts` has internal helpers without docstrings — codebase's CLAUDE.md says internal helpers don't require doc comments. Conviction 0.2 — drop.
