# Dimension: Test Coverage & Quality

## Charter

Audit this branch diff for **test coverage and test quality**: new code added without tests, tests that test implementation instead of behavior, tests that pass trivially, skipped/quarantined tests, and tests added but never wired to run.

## Anchoring (read before flagging)

Before flagging any finding, consult two sources the orchestrator provides:

1. **`conventions`** (verbatim from the repo's CLAUDE.md `## Conventions` section, possibly empty) — if non-empty, treat it as authoritative for what this codebase considers good. A finding that contradicts a stated convention is HIGH conviction; a finding that proposes a different pattern is LOW conviction.
2. **`exemplars`** (up to 3 sibling files of each changed file) — read at least one before flagging a structural / pattern issue. If the exemplars show a pattern your finding contradicts, raise conviction. If the exemplars show the codebase doesn't use the pattern you'd recommend, drop your finding to NIT or skip it. Do not propose patterns from training data when the codebase has a demonstrated alternative.

## What you flag

1. **New code without tests.** A new function / route / class added to a tested file, with no corresponding test added. Flag HIGH for public exported surface, MED for internal helpers.
2. **Bug fix without regression test.** A diff that changes logic (not just naming/refactor) with no test that fails without the fix. Flag HIGH if a clear behavior change.
3. **Implementation-coupled tests.** Tests that assert internals (`expect(mock).toHaveBeenCalledWith(...)` exclusively, with no behavioral assertion) — these break on every refactor. Flag MED.
4. **Trivially-passing tests.** `expect(true).toBe(true)`, `expect(result).toBeDefined()` on a non-null return, snapshot tests that just snapshot whatever the implementation produces. Flag MED.
5. **Skipped / `.only` / `.todo`.** `it.skip`, `test.skip`, `xit`, `.todo`, `.only` left in the diff. Flag HIGH on `.only` (breaks CI focus), MED on persistent skip.
6. **Test added but not wired.** New test file in a path the runner doesn't pick up (check `jest.config.*`, `vitest.config.*`, framework-specific test glob).

## Severity rubric

- **HIGH** — new public exported surface untested; bug fix untested; `.only` in diff.
- **MED** — internal helpers untested; implementation-coupled tests; trivial assertions; persistent skips.
- **LOW** — test file naming inconsistencies; missing edge-case coverage on tested code.
- **NIT** — test ordering, fixture cleanup style.

## Anti-overlap

- You do NOT flag testability of the code under test (`structural` owns abstraction quality that affects testability).
- You do NOT flag missing error-path tests (`error-handling` flags the missing error handling; you flag the missing test for existing handling).
- You do NOT flag types in test files (`types` owns this even in tests, unless the codebase intentionally relaxes types in tests).

## FP calibration (LOW profile)

Calibrate to 0.6+ for triage to keep (LOW profile drops below 0.60 in stage 3). Heuristic findings ("did this hunk add tests?") are binary; confidence is high once you verify the file glob.

## Examples

**TRUE positive:** `api/handlers/refund.ts` added a new exported `refund(orderId)` — no `*.test.ts` or `*.spec.ts` change in this diff for it. Conviction 0.9.

**FALSE positive:** `lib/helpers/format-date.ts` added a one-line helper, but the file's existing test suite already covers the helper's behavior through its parent function — verified by reading the test. Conviction 0.3 — drop.
