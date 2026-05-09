---
name: pre-deploy
description: Use when the user says "pre-deploy", "ready to deploy?", "deploy check", "go/no-go", or before pushing to a production branch — runs the full pre-deployment quality gate.
user-invocable: true
tier: rigid
kind: verification
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Pre-Deploy

Run the full pre-deployment quality gate. Aggregates all checks into a single go/no-go verdict. Use before every push to production.

Trigger: when the user says "pre-deploy", "ready to deploy?", "deploy check", "go/no-go", or before pushing to a production branch.

## Configuration

Read `.claude/hooks/harness.config.sh` for commands. Key vars:
- `HARNESS_TYPECHECK_CMD` — typecheck command
- `HARNESS_LINT_CMD` — lint command
- `HARNESS_TEST_CMD` — test command
- `HARNESS_BUILD_CMD` — build command
- `HARNESS_DB_SCHEMA_PATH` — schema file (for migration check)
- `HARNESS_DB_MIGRATIONS_DIR` — migrations directory
- `HARNESS_REQUIRED_ENV_VARS` — required env var names (space-separated)

## Pipeline

Run checks in this order. Stop on any FAIL unless `--force` is passed.

### 1. Git State

- Confirm on a feature branch (not `main` or `production`)
- Confirm working tree is clean (no uncommitted changes)
- Confirm branch is up to date with remote

### 2. Type Check

Run `HARNESS_TYPECHECK_CMD`. FAIL on any type errors.

### 3. Lint

Run `HARNESS_LINT_CMD`. FAIL on errors. WARN on warnings (report count).

### 4. Tests

Run `HARNESS_TEST_CMD`. FAIL if any test fails. Report total pass/fail/skip counts.

### 5. Build

Run `HARNESS_BUILD_CMD`. FAIL if build fails. This catches issues that type-check and lint miss.

### 6. Migration Check

If `HARNESS_DB_SCHEMA_PATH` is configured:
- Check if the schema file has uncommitted changes
- If schema changed, verify a corresponding migration exists in `HARNESS_DB_MIGRATIONS_DIR`
- WARN if schema changed but no migration is committed

### 7. Environment Audit

- Verify `.env.example` or `.env.template` exists
- Cross-reference env vars used in code (`process.env.VARIABLE`) against the template
- WARN if any env var is referenced in code but missing from the template
- If `HARNESS_REQUIRED_ENV_VARS` is set, FAIL if any required var is missing from the template

### 8. Console Cleanup

- Grep for `console.log` in source files (excluding test files)
- WARN on any found (with file:line list) — debug logs in production may leak info
- Ignore `console.error` and `console.warn` — those are intentional

### 9. Bundle Analysis (Optional)

If `--bundle` flag passed, run the project's bundle analyzer if available. Report any pages exceeding 200KB first-load JS.

## Verdict

```
## Pre-Deploy Check — [date] [branch]

### Verdict: GO / NO-GO

| Check | Status | Detail |
|-------|--------|--------|
| Git state | PASS | feat/my-feature, clean, up-to-date |
| Type check | PASS | 0 errors |
| Lint | PASS | 0 errors, 3 warnings |
| Tests | PASS | 42 passed, 0 failed |
| Build | PASS | Built successfully |
| Migrations | PASS | No schema changes |
| Env vars | PASS | All documented |
| Console cleanup | WARN | 2 console.logs found |

### Action Items (if NO-GO)
1. [what to fix]
```

## Rules

- Every check must produce PASS, WARN, or FAIL
- Any single FAIL = NO-GO verdict
- WARNs are reported but don't block
- Run all checks even if one fails (developer needs the full picture)
- After fixes, re-run the full pipeline — don't skip "passing" checks
