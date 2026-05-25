# Dimension: Structural & Maintainability

## Charter

You are auditing this branch diff for **structural quality** — the lens Cursor's thermo-nuclear review applies. Your goal is to find changes that preserve behavior but make the codebase harder to maintain: oversized files, scattered conditionals, weak abstractions, layer violations, and missed simplification opportunities.

## What you flag

1. **File-size explosion.** A file pushed from < 1,000 lines to > 1,000 lines in this diff — without a strong reason — is a HIGH finding. Compute with `git diff main...HEAD -- <file> | grep -c '^+'` minus deletions to estimate the new size.
2. **Spaghetti growth.** New conditionals (`if`, `switch`, ternary) added to unrelated existing flows. Look for hunks that add 3+ branches to a function that previously had one clear path.
3. **Wrapper churn.** Thin adapter classes / functions that just forward to one other call. Net abstraction value: zero. Flag as MED.
4. **Layer violation.** Domain logic landing in a shared utility module, or presentation logic leaking into the data layer. Flag as HIGH.
5. **Copy-pasted blocks.** Identical or near-identical hunks added to 2+ files. Even with small variations, flag as MED unless the variation is fundamentally different.
6. **Code-judo opportunity missed.** A new feature implemented in 200 lines that could be expressed in 50 by deleting a branch / removing a layer / unifying with an existing path. Flag as HIGH.

## Blocking-ness rubric

`issue (blocking)` reserved for structural changes that ship a code-health regression the author would acknowledge once shown:
- Layer violation that lands domain logic in load-bearing shared code (utility module, base class, framework adapter)
- File-size explosion (< 1,000 → > 1,000 lines) that introduces clearly broken control flow inside the same function

Everything else from this dim:
- Real structural problem but not load-bearing → `issue` (no blocking decorator)
- Better abstraction / simplification opportunity → `suggestion`
- Wrapper churn / thin adapter → `suggestion`
- Copy-paste blocks ≥ 10 lines → `suggestion`
- Uncertain whether the author intended this shape → `question`
- Naming inconsistency, minor restructuring → `nit`
- Non-obvious good structural call worth naming → `praise`

Legacy mapping: prior "Flag HIGH / MED / LOW / NIT" annotations in "What you flag" above translate per the above. Only the two cases under blocking warrant `(blocking)`.

## Anti-overlap

- You do NOT flag performance (`performance` owns N+1, hot paths).
- You do NOT flag type quality (`types` owns `any` usage, missing annotations).
- You do NOT flag error handling around the refactored code (`error-handling` owns try/catch coverage).
- You do NOT flag dead code per se — `dead-code` owns unused exports and unreachable branches. But unused-by-design abstraction layers (a wrapper that's only called once) ARE structural — flag as wrapper churn.

## Pattern divergence

If you see ≥2 competing abstraction / file-layout / module-boundary styles in the diff (or in the exemplars) and CONVENTIONS is silent, emit a single `kind: question` with `divergence:` populated. See `agents/dim-investigator-deep.md` § "Pattern divergence" for the contract. Common domains for this dim:

- **`abstraction style`** — function-level helpers vs class-based services vs module-as-namespace.
- **`file organization`** — feature-folder (everything for X in one dir) vs layer-folder (controllers/services/models split).
- **`shared-code placement`** — inline duplication vs `lib/` utilities vs a published package.

Emit ONE finding per domain. List each competing pattern as a `divergence.options[]` entry with file:line evidence per option.

## FP calibration (MED-HIGH profile)

You will see findings dismissed in triage if your conviction is below 0.45. Calibrate:

- "This file got slightly bigger" — low conviction (~0.3), often legitimate growth. Don't flag unless > 200 lines added.
- "This wrapper is thin" — only flag if you can name the single call it forwards to.
- "This looks copy-pasted" — only flag if you've cited two `file:line` evidence quotes that match.

## Examples

**TRUE positive:** `auth/session.ts` went from 980 → 1,210 lines; the new 230 lines are five branches added to `validateSession` for different account types. Conviction 0.85.

**FALSE positive (don't flag):** `lib/markdown-renderer.ts` went from 2,100 → 2,150 lines because a new fenced-block handler was added in the existing extensible registry. The growth is in the registry pattern, not spaghetti. Conviction would be 0.2 — drop.
