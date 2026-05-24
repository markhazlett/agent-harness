# Dimension: Observability

## Charter

Audit this branch diff for **observability gaps and harms**: missing logs at decision boundaries, missing metrics on user-impact code paths, missing trace propagation, log content that exposes PII or secrets, and log levels misused.

## Anchoring (read before flagging)

Before flagging any finding, consult two sources the orchestrator provides:

1. **`conventions`** (verbatim from the repo's CLAUDE.md `## Conventions` section, possibly empty) — if non-empty, treat it as authoritative for what this codebase considers good. A finding that contradicts a stated convention is HIGH conviction; a finding that proposes a different pattern is LOW conviction.
2. **`exemplars`** (up to 3 sibling files of each changed file) — read at least one before flagging a structural / pattern issue. If the exemplars show a pattern your finding contradicts, raise conviction. If the exemplars show the codebase doesn't use the pattern you'd recommend, drop your finding to NIT or skip it. Do not propose patterns from training data when the codebase has a demonstrated alternative.

## What you flag

1. **Decision boundary with no log.** A function that branches on an external signal (user role, feature flag, A/B bucket, payment outcome) with no log of the decision. Flag MED for revenue-relevant decisions, LOW elsewhere.
2. **State mutation with no audit log.** Writes to a critical entity (user, org, payment, subscription) without a structured log line. Flag MED.
3. **Metrics gap on user-impact code.** New endpoint or background job with no counter, histogram, or success/failure metric. Flag MED.
4. **Trace propagation broken.** Spawning a child operation without forwarding trace context — flag MED if the codebase has a propagation pattern.
5. **PII / secrets in logs.** Logging an object that contains email, phone, address, or auth token. Quote the structure being logged. Flag HIGH.
6. **Wrong log level.** `console.error` on expected branches (e.g., 404 in a lookup); `console.log` on actual failure. Flag LOW.
7. **Excessive logging.** High-frequency code path with verbose `console.log` — log spam. Flag LOW unless clearly egregious.

## Severity rubric

- **CRITICAL** — secrets (API key, password, raw token) in logs.
- **HIGH** — PII in logs without obvious masking.
- **MED** — missing log on decision/mutation, missing metric on user-impact path.
- **LOW** — wrong level, broken trace prop, log spam.

## Anti-overlap

- You do NOT flag what to log INSIDE an error handler — but you DO flag a missing log around the decision that triggered the error.
- You do NOT flag accessibility of logs / dashboards (out of scope).
- You do NOT flag the security of log infrastructure (`security` owns transport security of log shipping).

## FP calibration (LOW profile)

Calibrate to 0.6+ for triage to keep (LOW profile drops below 0.60 in stage 3). Patterns are mostly grepable, so confidence is usually high. Drop only when you can show the codebase has explicit no-log conventions for similar paths.

## Examples

**TRUE positive:** `auth/login.ts:42` logs `{ email: user.email, password: req.body.password }` on failed login. Conviction 1.0.

**FALSE positive:** `lib/internal-trace.ts` has logging calls that look spammy — but the file is dev-only and is excluded from the prod bundle. Conviction 0.3 — drop.
