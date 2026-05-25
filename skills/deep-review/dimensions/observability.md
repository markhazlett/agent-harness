# Dimension: Observability

## Charter

Audit this branch diff for **observability gaps and harms**: missing logs at decision boundaries, missing metrics on user-impact code paths, missing trace propagation, log content that exposes PII or secrets, and log levels misused.

## What you flag

1. **Decision boundary with no log.** A function that branches on an external signal (user role, feature flag, A/B bucket, payment outcome) with no log of the decision. Flag MED for revenue-relevant decisions, LOW elsewhere.
2. **State mutation with no audit log.** Writes to a critical entity (user, org, payment, subscription) without a structured log line. Flag MED.
3. **Metrics gap on user-impact code.** New endpoint or background job with no counter, histogram, or success/failure metric. Flag MED.
4. **Trace propagation broken.** Spawning a child operation without forwarding trace context — flag MED if the codebase has a propagation pattern.
5. **PII / secrets in logs.** Logging an object that contains email, phone, address, or auth token. Quote the structure being logged. Flag HIGH.
6. **Wrong log level.** `console.error` on expected branches (e.g., 404 in a lookup); `console.log` on actual failure. Flag LOW.
7. **Excessive logging.** High-frequency code path with verbose `console.log` — log spam. Flag LOW unless clearly egregious.

## Blocking-ness rubric

`issue (blocking)` reserved for observability harms that ship a privacy or security regression:
- Secret (API key, password, raw token) in logs — quote the structure being logged
- PII (email, phone, address, government-ID) in logs without obvious masking

Everything else from this dim:
- Missing log on decision boundary or critical-entity mutation → `suggestion`
- Missing metric on user-impact path → `suggestion`
- Broken trace propagation in a codebase with an established propagation pattern → `issue` (non-blocking)
- Wrong log level (`console.error` on expected branch) → `nit`
- Log spam in hot path → `suggestion`
- Non-obvious good observability call (well-placed structured log with redaction) worth naming → `praise`

Legacy mapping: prior "Flag CRITICAL / HIGH" (secrets / PII in logs) → `issue (blocking)`. Everything else → non-blocking forms.

## Anti-overlap

- You do NOT flag what to log INSIDE an error handler — but you DO flag a missing log around the decision that triggered the error.
- You do NOT flag accessibility of logs / dashboards (out of scope).
- You do NOT flag the security of log infrastructure (`security` owns transport security of log shipping).

## Pattern divergence

If you see ≥2 competing logging / metrics / tracing patterns in the diff (or in the exemplars) and CONVENTIONS is silent, emit a single `kind: question` with `divergence:` populated. See `agents/dim-investigator-deep.md` § "Pattern divergence" for the contract. Common domains for this dim:

- **`logging format`** — `console.log` strings vs structured JSON via a logger (pino, winston, bunyan) vs platform-native (`@logtail/node`, OTel).
- **`metric naming convention`** — `snake_case` vs `dot.separated` vs `camelCase` for metric keys.
- **`trace context propagation`** — header-based (`traceparent`), AsyncLocalStorage, explicit context arg threading.

Emit ONE finding per domain. List each competing pattern as a `divergence.options[]` entry with file:line evidence per option.

## FP calibration (LOW profile)

Calibrate to 0.6+ for triage to keep (LOW profile drops below 0.60 in stage 3). Patterns are mostly grepable, so confidence is usually high. Drop only when you can show the codebase has explicit no-log conventions for similar paths.

## Examples

**TRUE positive:** `auth/login.ts:42` logs `{ email: user.email, password: req.body.password }` on failed login. Conviction 1.0.

**FALSE positive:** `lib/internal-trace.ts` has logging calls that look spammy — but the file is dev-only and is excluded from the prod bundle. Conviction 0.3 — drop.
