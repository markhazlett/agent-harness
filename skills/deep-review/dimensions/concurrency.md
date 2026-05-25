# Dimension: Concurrency & Race Conditions

## Charter

You are auditing this branch diff for **concurrency bugs**: races on shared mutable state, missing locks/serialization, double-await/double-spend patterns, unsafe `Promise.all`, and event-ordering hazards.

## What you flag

1. **Shared mutable state with no synchronization.** A module-level `let` / `const obj = {}` mutated from multiple async paths. In Node, the event loop guards primitives, but `await` boundaries split atomicity — flag if a sequence reads, awaits, then writes based on the pre-await read.
2. **Read-modify-write race over storage.** Reading a row, modifying based on its value, writing back — without a `SELECT ... FOR UPDATE`, a CAS check, or a transaction. Classic "double-spend" / lost-update.
3. **`Promise.all` over operations that need ordering.** E.g., `await Promise.all([createOrg(), addUser()])` when `addUser` depends on the org. Flag HIGH.
4. **Double-await on the same promise.** Often indicates confusion about the actual control flow.
5. **Race on file/IO/resource.** Creating + immediately reading a file without `fsync`; multiple workers writing to the same path with no locking.
6. **Event ordering hazards.** Subscribing to events after the emitter may have already fired; missing `once` semantics where `on` would replay.

## Blocking-ness rubric

`issue (blocking)` reserved for races that ship a correctness regression on user-impacting state:
- Race on financial / auth-relevant state (balance, session token, role assignment) with no compensating control
- Read-modify-write race on storage with no `SELECT ... FOR UPDATE`, CAS, or transaction
- `Promise.all` over operations that depend on each other (ordering hazard)

Everything else from this dim:
- Race on user-visible state with idempotency / retries already in place → `issue` (non-blocking)
- Race on transient state where worst case is a recoverable error → `issue` (non-blocking) or `suggestion`
- Theoretical race with no realistic trigger → `question` or `thought`
- `Promise.all` style preference → `nit`
- Non-obvious good concurrency call (correct CAS, well-placed lock) worth naming → `praise`

Legacy mapping: prior "Flag CRITICAL" → `issue (blocking)`. "Flag HIGH" with no compensating control → `issue (blocking)`. "Flag MED / LOW / NIT" → non-blocking forms.

## Anti-overlap

- You do NOT flag performance (`performance` owns N+1, hot paths). An unbounded `Promise.all` is `performance`'s, not yours, UNLESS the ordering matters.
- You do NOT flag transaction-level safety in DB migrations (`db` owns CREATE INDEX CONCURRENTLY, locking).
- You do NOT flag error handling around the race (`error-handling` owns try/catch and retry logic).

## Pattern divergence

If you see ≥2 competing concurrency / locking / serialization patterns in the diff (or in the exemplars) and CONVENTIONS is silent, emit a single `kind: question` with `divergence:` populated. See `agents/dim-investigator-deep.md` § "Pattern divergence" for the contract. Common domains for this dim:

- **`mutual exclusion style`** — DB row locks (`SELECT ... FOR UPDATE`) vs application-layer mutex vs idempotency-key tokens vs CAS.
- **`async coordination`** — `Promise.all` vs sequential `await` vs explicit queue/worker pool.
- **`background work shape`** — in-process workers vs queue + consumer vs cron + scheduled job.

Emit ONE finding per domain. List each competing pattern as a `divergence.options[]` entry with file:line evidence per option.

## FP calibration (HIGH profile)

Static analysis on async code is notoriously noisy. Calibrate to 0.4+ for triage to keep (HIGH profile drops below 0.40 in stage 3). Conviction floors:

- "This looks racy" — only flag if you can articulate the interleaving that produces the bad outcome.
- "Missing lock" — only flag if you can name the resource being raced over and the two concurrent code paths.
- "Promise.all ordering" — only flag if you can quote a downstream consumer that depends on a specific completion order.

## Examples

**TRUE positive:** `api/orders/transfer.ts` reads sender balance, awaits a price-fetch, then writes new balances. Interleaving with a second transfer between the await and write loses one transfer. Both quoted; conviction 0.85.

**FALSE positive (don't flag):** `services/cache.ts` has `let cache = {}` with read-then-write. But the writes are idempotent (same key always maps to the same value via a deterministic function). Conviction 0.25 — drop.
