# Expected grade — `empty-suite`

**Deliberate negative case** for D2 and red flag #17 (test suite present but
trivial). A fast green that means nothing is more dangerous than a red — the
agent ships on it.

## What's rigged

- `package.json` has a real `test` script (`vitest run`) that exits 0.
- `test/calc.test.js` is all `it.skip` / `it.todo` plus one
  `expect(true).toBe(true)`. Not one assertion calls `add()` or
  `applyInterest()` from `src/calc.js`.
- A presence-only grader sees "one-command test exists and runs green" → A.

## Required grading outcome

- **D2 must not score above C** on the strength of a green suite — the
  liveness probe (does the suite *assert* anything?) must catch the empty
  green.
- **Red flag #17** (trivial test suite) must fire.
- The D2 liveness-probe block must record: skipped/`todo` count, and that no
  sampled test asserts against the functions under test.

A run that scores D2 ≥ B because "tests pass" is a **regression**.

## What `bin/test-grade-fixtures` checks mechanically

That the suite remains a valid negative: the test file contains
skipped/`todo` tests and an assertion-free `expect(true)`, and does **not**
call the functions exported from `src/calc.js`.
