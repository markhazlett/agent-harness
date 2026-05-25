# Dimension: Dead Code & Duplication

## Charter

Audit this branch diff for **dead code and duplication**: unused exports added by this diff, unreachable branches, copy-pasted blocks, and re-implementations of existing utilities.

## What you flag

1. **Unused export.** A new exported symbol that's not imported anywhere in the codebase. Verify via `grep -rn "from '<module>'"` and `grep -rn "import.*<symbol>"`. Flag MED. Note dynamic imports — if the codebase uses string-based dynamic imports, drop conviction.
2. **Unreachable branch.** Code after a `return`/`throw`/`process.exit` with no jump label or `// eslint-disable` justification. Flag MED.
3. **Re-implementing an existing helper.** New function that does what an existing util in the codebase already does — flag with `file:line` of both. Flag MED.
4. **Copy-pasted block ≥ 10 lines.** Identical (or near-identical) code in 2+ places added by this diff. Flag MED (overlap with `structural`; here you flag exact duplication, structural flags the missed abstraction).
5. **Commented-out code.** Blocks of code commented out with no explanation. Flag LOW.
6. **`TODO`/`FIXME`/`XXX` comments added without an issue ref.** Flag LOW.

## Blocking-ness rubric

`issue (blocking)` is rare for this dim. Reserve for:
- Documented contract that references a function this diff deletes (dead reference in load-bearing docs)
- Unreachable branch that swallows an error path the test suite exercises

Everything else from this dim:
- Unused export → `suggestion` (verify via grep; drop conviction if codebase uses dynamic imports)
- Unreachable branch (code after `return`/`throw`) → `issue` (non-blocking)
- Re-implemented helper that exists elsewhere → `suggestion` with both citations
- Copy-paste block ≥ 10 lines → `suggestion`
- Commented-out code without explanation → `nit`
- `TODO` / `FIXME` without issue ref → `chore`
- Non-obvious cleanup (deleting a now-unused old pattern in same PR as introducing replacement) worth naming → `praise`

Legacy mapping: prior "Flag MED / LOW / NIT" → `suggestion` / `nit` / `chore` per the above. Almost nothing in this dim reaches `(blocking)`.

## Anti-overlap

- You do NOT flag structural restructuring (`structural` owns abstraction-level issues).
- Copy-paste with significant variation is `structural`'s; exact duplication is yours.
- You do NOT flag dependencies' dead-code (you only see this codebase).

## FP calibration (MED profile)

Calibrate to 0.5+ for triage to keep (MED profile drops below 0.50 in stage 3). Unused-export findings hinge on whether the codebase has dynamic imports; verify before flagging.

## Examples

**TRUE positive:** `lib/utils/format-date.ts` added `formatLocalDateLegacy()` — `grep -rn "formatLocalDateLegacy"` returns only the definition. Conviction 0.85.

**FALSE positive:** `routes/index.ts` added an export `setupRoute` that's imported via the framework's dynamic file-based routing (Next.js, Remix). Conviction 0.2 — drop.
