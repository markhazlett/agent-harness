# Dimension: API Contract Drift

## Charter

Audit this branch diff for **breaking changes to public contracts**: exported function signatures, public types, REST/GraphQL endpoint shapes, DB schema columns referenced by external consumers, event payloads, and CLI flags. Anything an external caller depends on is a contract; changing it without versioning / migration is a break.

## What you flag

1. **Exported signature change.** A function/method whose parameter list or return type changed, and the symbol is exported. Flag HIGH if external consumers exist (cross-package, public npm publish, etc.), MED for internal cross-module.
2. **REST/GraphQL endpoint change.** Removed/renamed field in a response; changed required input; new required field with no migration. Flag HIGH.
3. **DB schema column drop or rename** referenced in app code (overlaps `db`). Flag MED here.
4. **Event payload schema change.** Renamed/dropped fields in events sent to queues, websockets, webhooks. Flag HIGH.
5. **CLI flag rename / removal** in a tool the user runs. Flag HIGH.
6. **Public type definition change.** Exported `interface` / `type` / `class` with a public member removed/renamed/retyped. Flag HIGH.

## Blocking-ness rubric

`issue (blocking)` reserved for contract changes that ship a breaking change without versioning or migration:
- Wire-format change to a public webhook / API with active external consumers
- Removed / renamed REST or GraphQL field; new required input without default
- Renamed / dropped fields in event payloads sent to queues, websockets, webhooks
- CLI flag renamed / removed in a tool users invoke
- Public type definition with member removed / renamed / retyped, and the type is imported cross-package

Everything else from this dim:
- Exported signature change consumed only within the package → `issue` (non-blocking)
- DB column drop where app code already migrated → `issue` (non-blocking)
- Additive change (new optional param) → `note` or `suggestion` (mention the docs update)
- Naming inconsistency in additive changes → `nit`
- Non-obvious good contract evolution (proper deprecation, dual-write window) worth naming → `praise`

Legacy mapping: prior "Flag CRITICAL / HIGH" with active-consumer evidence quoted → `issue (blocking)`. Everything else → non-blocking forms.

## Anti-overlap

- You do NOT flag migration safety (`db` owns backfill, locks, rollback).
- You do NOT flag the new code's quality (`structural`, `types`, `error-handling` own those).
- You do NOT flag test coverage of the contract change (`tests` owns this).

## FP calibration (LOW profile)

Calibrate to 0.6+ for triage to keep (LOW profile drops below 0.60 in stage 3). Heuristic: if you can quote the old signature AND the new signature AND name at least one consumer, conviction ≥ 0.8.

## Examples

**TRUE positive:** `lib/auth/index.ts` exports `verify(token: string): User` — changed to `verify(token: string, opts: VerifyOpts): User`. Used by 4 other packages in the monorepo. Conviction 0.95.

**FALSE positive:** `internal/utils/format.ts` (not exported from the package's `index.ts`, not imported cross-package) had a signature change. No external consumers. Conviction 0.3 — drop.
