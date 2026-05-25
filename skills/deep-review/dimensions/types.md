# Dimension: Type Safety

## Charter

Audit this branch diff for **type-safety regressions**: `any` usage, missing annotations on public surfaces, unsafe casts, optionality abuse, and inference holes that hide bugs.

## What you flag

1. **`any` introduced.** Any new `: any` on a function parameter, return type, or variable declaration. Flag MED unless the codebase has an established escape-hatch comment pattern.
2. **Missing annotations on public surfaces.** Exported functions/methods without explicit return types; exported classes without annotated public methods. Inference is fine internally; public types are the contract.
3. **Unsafe casts.** `as unknown as T`, `<T><unknown>x`, `// @ts-ignore`, `// @ts-expect-error` without a reason comment. Flag MED.
4. **Optionality abuse.** Optional chaining where a non-null assertion would expose a real bug (`a?.b?.c?.d` masking a missing required field). Flag LOW.
5. **`Object`/`Function`/`{}` as types.** Same posture as `any` — flag MED.
6. **Generic constraints missing.** `function f<T>(x: T)` accepting any shape when it actually requires structural properties — flag LOW.

## Blocking-ness rubric

`issue (blocking)` is rare for this dim. Reserve for:
- `@ts-ignore` / `@ts-expect-error` on a line with documented type-checker-caught bugs in the codebase (i.e., suppressing a known correctness issue)
- `any` introduced on a public exported API surface AND that public surface is consumed cross-package (load-bearing contract)

Everything else from this dim:
- `any` in implementation, unsafe cast in business logic → `issue` (non-blocking)
- Missing return type on exported function → `suggestion`
- Optionality chain masking required field → `question` (often a sign of unclear intent)
- Over-permissive generic → `suggestion`
- Local inference that could be explicit → `nit`
- Non-obvious good typing (well-placed discriminated union, narrow type guard) worth naming → `praise`

Legacy mapping: prior "Flag HIGH" rarely reaches `(blocking)` — only when the suppression hides a known bug. Everything else → non-blocking.

## Anti-overlap

- You do NOT flag missing docstrings on public types (`docs` owns documentation).
- You do NOT flag missing tests for type-correct code (`tests` owns coverage).
- You do NOT flag structural problems with the type's shape (`structural` owns abstractions).

## Pattern divergence

If you see ≥2 competing typing styles in the diff (or in the exemplars) and CONVENTIONS is silent, emit a single `kind: question` with `divergence:` populated. See `agents/dim-investigator-deep.md` § "Pattern divergence" for the contract. Common domains for this dim:

- **`null / optional convention`** — `T | undefined` vs `T | null` vs `Maybe<T>` vs throwing on absence.
- **`branded / nominal types`** — bare `string` IDs vs branded types (`UserId = string & { __brand }`) vs class wrappers.
- **`exported-API typing`** — explicit return annotations on every export vs inference-trusted vs interfaces vs type aliases.

Emit ONE finding per domain. List each competing pattern as a `divergence.options[]` entry with file:line evidence per option.

## FP calibration (LOW profile)

Calibrate to 0.6+ for triage to keep (LOW profile drops below 0.60 in stage 3). Types are binary-ish, so most findings start at 0.7+. Only drop if there's an obvious escape-hatch comment or established pattern.

## Examples

**TRUE positive:** `api/handlers/webhook.ts:14` exports `function handle(payload: any)` — public surface, no escape-hatch comment. Conviction 0.9.

**FALSE positive:** `tests/fixtures/builder.ts:3` has `let result: any = ...` in a test fixture builder where the codebase consistently uses `any` in fixtures (verified by 10+ similar patterns). Conviction 0.4 — drop.
