# Expected grade — `stale-context`

**This fixture is a deliberate negative case.** It is the repro of the false-A
that motivated the liveness-probe layer: a context doc that is *present,
well-formatted, and dead*.

## What's rigged

`CLAUDE.md` (and the `.ai/conventions.md` it references) make concrete claims
that the actual code contradicts:

| Claim in the doc | Reality |
|---|---|
| "Run the test suite: `make test`" | No `Makefile` exists; the real command is `vitest run` (`package.json`) |
| "HTTP handlers live in `services/`" | No `services/` directory; code is in `src/` |
| "DB access goes through `src/db/client.ts`; never import `pg` directly" | No `src/db/client.ts`; `src/index.ts` imports `pg` directly |

3 of 3 sampled claims are false → the doc is **misleading**, not merely
incomplete.

## Required grading outcome (the model-graded dogfood assertion)

- **D1 must score D or F**, never C — present-but-misleading scores *below*
  absent (rubric §4).
- **Red flag #15** (stale/misleading context) must fire.
- The **compounding-context cap** must apply: overall grade **capped at C**.
- The report's D1 liveness-probe block must show ≥3 verified claims with
  ≥1 failing, plus the followed reference into `.ai/`.

A run that returns D1 ≥ C, or an overall grade above C, is a **regression** —
the exact bug this calibration set guards against.

## What `bin/test-grade-fixtures` checks mechanically

That the fixture remains a valid negative: at least one doc-cited path does
not exist, and at least one doc-cited command has no backing target. It does
**not** test the model's judgment (that's the dogfood run above).
