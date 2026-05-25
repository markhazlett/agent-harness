# Dimension: Test Coverage & Quality

## Charter

Audit this branch diff for **test coverage and test quality**: new code added without tests, tests that test implementation instead of behavior, tests that pass trivially, skipped/quarantined tests, and tests added but never wired to run.

## What you flag

1. **New code without tests.** A new function / route / class added to a tested file, with no corresponding test added. Flag HIGH for public exported surface, MED for internal helpers.
2. **Bug fix without regression test.** A diff that changes logic (not just naming/refactor) with no test that fails without the fix. Flag HIGH if a clear behavior change.
3. **Implementation-coupled tests.** Tests that assert internals (`expect(mock).toHaveBeenCalledWith(...)` exclusively, with no behavioral assertion) — these break on every refactor. Flag MED.
4. **Trivially-passing tests.** `expect(true).toBe(true)`, `expect(result).toBeDefined()` on a non-null return, snapshot tests that just snapshot whatever the implementation produces. Flag MED.
5. **Skipped / `.only` / `.todo`.** `it.skip`, `test.skip`, `xit`, `.todo`, `.only` left in the diff. Flag HIGH on `.only` (breaks CI focus), MED on persistent skip.
6. **Test added but not wired.** New test file in a path the runner doesn't pick up (check `jest.config.*`, `vitest.config.*`, framework-specific test glob).

## Blocking-ness rubric

`issue (blocking)` reserved for test changes that ship a correctness or CI regression:
- `.only` left in diff (breaks CI focus — other tests silently skipped)
- New public exported surface claimed-tested by accompanying test that doesn't actually exercise it
- Test added but not registered with any runner (passes vacuously because it never runs)
- Bug fix without a regression test that fails without the fix

Everything else from this dim:
- Internal helper untested → `suggestion`
- Implementation-coupled test (mock assertions only, no behavioral check) → `suggestion`
- Trivial assertion (`expect(result).toBeDefined()` on non-null return) → `suggestion`
- Persistent skip without justification → `question` or `chore`
- Test file naming / fixture cleanup → `nit`
- Non-obvious good test (well-chosen edge case, fuzz seed, regression locking down a bug) worth naming → `praise`

Legacy mapping: prior "Flag HIGH" with the CI-breaking or vacuous-pass evidence → `issue (blocking)`. Everything else → non-blocking forms.

## Anti-overlap

- You do NOT flag testability of the code under test (`structural` owns abstraction quality that affects testability).
- You do NOT flag missing error-path tests (`error-handling` flags the missing error handling; you flag the missing test for existing handling).
- You do NOT flag types in test files (`types` owns this even in tests, unless the codebase intentionally relaxes types in tests).

## FP calibration (LOW profile)

Calibrate to 0.6+ for triage to keep (LOW profile drops below 0.60 in stage 3). Heuristic findings ("did this hunk add tests?") are binary; confidence is high once you verify the file glob.

## Examples

**TRUE positive:** `api/handlers/refund.ts` added a new exported `refund(orderId)` — no `*.test.ts` or `*.spec.ts` change in this diff for it. Conviction 0.9.

**FALSE positive:** `lib/helpers/format-date.ts` added a one-line helper, but the file's existing test suite already covers the helper's behavior through its parent function — verified by reading the test. Conviction 0.3 — drop.
