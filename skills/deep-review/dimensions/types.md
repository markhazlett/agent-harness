# Dimension: Type Safety

## Charter

Audit this branch diff for **type-safety regressions**: `any` usage, missing annotations on public surfaces, unsafe casts, optionality abuse, and inference holes that hide bugs.

## Anchoring (read before flagging)

Before flagging any finding, consult two sources the orchestrator provides:

1. **`conventions`** (verbatim from the repo's CLAUDE.md `## Conventions` section, possibly empty) — if non-empty, treat it as authoritative for what this codebase considers good. A finding that contradicts a stated convention is HIGH conviction; a finding that proposes a different pattern is LOW conviction.
2. **`exemplars`** (up to 3 sibling files of each changed file) — read at least one before flagging a structural / pattern issue. If the exemplars show a pattern your finding contradicts, raise conviction. If the exemplars show the codebase doesn't use the pattern you'd recommend, drop your finding to NIT or skip it. Do not propose patterns from training data when the codebase has a demonstrated alternative.

## What you flag

1. **`any` introduced.** Any new `: any` on a function parameter, return type, or variable declaration. Flag MED unless the codebase has an established escape-hatch comment pattern.
2. **Missing annotations on public surfaces.** Exported functions/methods without explicit return types; exported classes without annotated public methods. Inference is fine internally; public types are the contract.
3. **Unsafe casts.** `as unknown as T`, `<T><unknown>x`, `// @ts-ignore`, `// @ts-expect-error` without a reason comment. Flag MED.
4. **Optionality abuse.** Optional chaining where a non-null assertion would expose a real bug (`a?.b?.c?.d` masking a missing required field). Flag LOW.
5. **`Object`/`Function`/`{}` as types.** Same posture as `any` — flag MED.
6. **Generic constraints missing.** `function f<T>(x: T)` accepting any shape when it actually requires structural properties — flag LOW.

## Severity rubric

- **HIGH** — `any` on a public exported API surface; `@ts-ignore` on a known-buggy line.
- **MED** — `any` in implementation; unsafe casts in business logic; missing public return types.
- **LOW** — optionality chains masking missing fields; over-permissive generics.
- **NIT** — local inference that could be explicit but isn't strictly wrong.

## Anti-overlap

- You do NOT flag missing docstrings on public types (`docs` owns documentation).
- You do NOT flag missing tests for type-correct code (`tests` owns coverage).
- You do NOT flag structural problems with the type's shape (`structural` owns abstractions).

## FP calibration (LOW profile)

Calibrate to 0.6+ for triage to keep (LOW profile drops below 0.60 in stage 3). Types are binary-ish, so most findings start at 0.7+. Only drop if there's an obvious escape-hatch comment or established pattern.

## Examples

**TRUE positive:** `api/handlers/webhook.ts:14` exports `function handle(payload: any)` — public surface, no escape-hatch comment. Conviction 0.9.

**FALSE positive:** `tests/fixtures/builder.ts:3` has `let result: any = ...` in a test fixture builder where the codebase consistently uses `any` in fixtures (verified by 10+ similar patterns). Conviction 0.4 — drop.
