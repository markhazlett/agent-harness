# /deep-review smoke-test protocol

Manual end-to-end check that the `/deep-review` pipeline works against a known-bad branch. Used to validate the FIXED-IN-COMMIT revalidator path after non-trivial changes to `pipeline.md`, the dimension prompts, or the SCAN/VALIDATE helpers.

This is **not** a CI test. CI exercises `bin/deep-review-scan` and `bin/deep-review-validate` in isolation (see `bin/tests/deep-review-*.test.sh`). What CI cannot exercise — the parallel subagent fan-out, triage, revalidate, and end-to-end report assembly — is what this protocol covers.

## When to run

- Before merging a PR that changes `skills/deep-review/pipeline.md`, any file under `skills/deep-review/dimensions/`, `bin/deep-review-scan`, or `bin/deep-review-validate`.
- After upgrading the model tier in any of the four agent definitions (`skills/deep-review/agents/`).
- When debugging a real-session report that looks wrong.

Roughly once per non-trivial change. Costs real tokens (~1 dispatched skill run with 15 subagents); don't gate every commit on it.

## Step 1 — Generate the fixture

From the agent-harness repo root:

```bash
bin/deep-review-fixture --out /tmp/dr-smoke
```

This creates a self-contained git repo at `/tmp/dr-smoke` with two branches:

- `main` — one clean baseline commit.
- `feature` — two commits on top of main:
  1. `feat: charge API + legacy shim` — introduces six planted findings across six dimensions.
  2. `chore: remove legacy-shim-xyz` — removes the `legacy-shim-xyz` dependency. **This is the FIXED-IN-COMMIT setup**: the dependencies dim should flag the bad dep when reading commit 1, then the revalidator should mark it FIXED-IN-COMMIT after seeing it absent at tip.

The fixture also drops `.claude/hooks/config.sh` so `HARNESS_DB_MIGRATIONS_DIR` is exported — without this the schema/migrations dim isn't gated active.

## Step 2 — Plant matrix (what `/deep-review` should find)

These are the six findings planted in commit 1. Severity here is the *expected verdict from a correctly functioning pipeline* — if a real run produces materially different verdicts, that's a finding for the orchestrator's anchoring or for the dimension prompt itself.

| # | Dim | Severity | Where | What |
|---|-----|----------|-------|------|
| 1 | `schema/migrations` | FAIL / CRITICAL | `db/migrations/0001_drop_legacy_email.sql` | `DROP COLUMN email_legacy;` with a `TODO` backfill (never written). Drop-column-without-backfill is the textbook destructive-migration finding. |
| 2 | `dependencies` | HIGH | `package.json` (commit 1 only) | `legacy-shim-xyz@^0.3.1` — 0.x caret range, name signals legacy/abandonware. **This is the FIXED-IN-COMMIT plant** — gone at tip. |
| 3 | `security` | FAIL / CRITICAL | `src/config.ts` | `STRIPE_API_KEY = "sk_live_PLANTED_FIXTURE_DO_NOT_USE_xxxx"` — hardcoded production-shape API key literal (entropy-poor sentinel so secret scanners don't flag the fixture; the security dim should still pattern-match `sk_live_*`). |
| 4 | `error-handling` | MED / WARN | `src/charge.ts` | Empty `catch (e) { /* ignore */ }` swallowing Stripe errors. |
| 5 | `tests` | MED / WARN | `src/charge.ts` (no test file) | New exported `chargeCard` function with no corresponding test file. |
| 6 | `magic-values` | LOW | `src/config.ts` | `PRICING_TIER_CENTS = 2999` — bare numeric pricing literal with no comment. |

Note finding #5 is dual-purpose: `error-handling` flags the empty catch; `tests` flags the missing test file. Both should fire, on the same file, on different lines.

## Step 3 — Run `/deep-review`

```bash
cd /tmp/dr-smoke
git checkout feature
claude    # or: open this dir in your existing Claude Code session
```

In the Claude Code session running in `/tmp/dr-smoke`, invoke:

```
/deep-review
```

The skill will run its 5-stage pipeline:

1. **SCAN** — `bin/deep-review-scan main` should output `gates.db: true` and 3 files in the diff.
2. **DISPATCH(15)** — 15 dim-investigator subagents in parallel against the 3 files.
3. **TRIAGE** — haiku subagent rolls up findings, drops conviction-below-threshold.
4. **REVALIDATE** — opus subagent re-checks HIGH-FP findings. **This is where the FIXED-IN-COMMIT path runs**: the dependencies finding was real in HEAD~1 but absent at HEAD, so revalidator should mark it FIXED-IN-COMMIT.
5. **SYNTHESIZE** — writes report to `.deep-review/<branch>-<timestamp>.md`; runs `bin/deep-review-validate` against it.

## Step 4 — What success looks like

The on-disk report at `.deep-review/feature-*.md` should include:

- A verdict matrix with 15 rows (one per dimension; some may be N/A with one-line justification).
- For the four CRITICAL/HIGH findings (#1, #3, #2-as-FIXED, plus revalidator notes): file:line evidence quoted verbatim from the planted files.
- A FIXED-IN-COMMIT row for the `dependencies` finding referencing both commit SHAs (the introducing commit and the fixing commit).
- `bin/deep-review-validate` exits 0 against the report.

Specifically, the dependencies finding should NOT appear in the final "blocking" list — it was fixed before the user pressed go. If it does appear as blocking, the revalidator missed the FIXED-IN-COMMIT path and that's a bug to investigate.

## Step 5 — Expected failure modes (what's worth flagging)

- **`gates.db: false`**: SCAN didn't pick up `.claude/hooks/config.sh`. Likely an env-loading regression in `bin/deep-review-scan`.
- **Fewer than 15 dim verdicts in the report**: the orchestrator skipped dimensions silently. The Iron Law is broken; this is the highest-priority bug to fix.
- **`legacy-shim-xyz` flagged as currently blocking**: the revalidator's FIXED-IN-COMMIT path isn't seeing the second commit. Check `revalidator` agent prompt + how it reads commit history.
- **`STRIPE_API_KEY` flagged below CRITICAL**: the security dim's hardcoded-secret detection regressed.
- **`PRICING_TIER_CENTS = 2999` flagged above LOW**: the magic-values dim is over-flagging — calibrate.
- **Empty catch flagged as PASS**: error-handling dim regressed on the catch-and-ignore pattern.

## Step 6 — Cleanup

```bash
rm -rf /tmp/dr-smoke
```

Or leave it; `bin/deep-review-fixture --out <path>` refuses to overwrite a non-empty directory, so you'll need to clear it before re-running anyway.

## Why this lives in `docs/skill-baselines/`

It's not a regression test in the unit-test sense — it's a documented manual procedure that produces an artifact comparable to the RED/GREEN baselines under this directory (each run produces a real `/deep-review` transcript that can be inspected). The output of a smoke run can be saved alongside the baselines as a forensic record if needed:

```bash
cp /tmp/dr-smoke/.deep-review/feature-*.md docs/skill-baselines/deep-review-smoke-$(date +%Y-%m-%d).md
```
