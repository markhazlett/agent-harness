---
name: db-review
description: Use when the user says "review migrations", "db review", "check schema changes", "safe to migrate?", or before deploying schema changes to production.
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

# DB Review

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

Review pending database migrations and schema changes for safety before deploying to production. Catches destructive operations, missing indexes, irreversible changes, and missing rollback plans.

## The Iron Law

```
NO MIGRATION APPROVAL WITHOUT ROLLBACK PLAN AND DATA-LOSS ANALYSIS
```

Every migration produces three written artifacts: destructive-op verdict, index review, and rollback plan. "We discussed it last week" is not a plan. "30 days of no reads" is not analysis.

## Gate Sequence

**REQUIRED SUB-FILE:** `checks.md` — destructive-op table, index patterns, rollback assessment, output format.

1. **Identify changes.** Read every migration in `HARNESS_DB_MIGRATIONS_DIR` and the diff on `HARNESS_DB_SCHEMA_PATH`.
2. **Destructive-op scan.** Verdict per DROP/ALTER/TRUNCATE/RENAME/NOT-NULL.
3. **Index review.** New tables and FK columns need indexes. Vector columns need HNSW/IVFFlat.
4. **Rollback.** Reversible? Locks? Down migration written? `CREATE INDEX CONCURRENTLY` on >10M rows.
5. **Schema consistency.** ORM matches SQL; no drift.
6. **Data migration.** Backfill exists, NULLs handled, time estimated.

Any FAIL = SAFE TO DEPLOY: NO.

## Red Flags — STOP

- "The team already agreed."
- "FK index can come in a follow-up."
- "The column hasn't been read in 30 days."
- "Audit log proves it's unused."
- "Small migration, no rollback needed."
- "Down migration is overhead for a deprecation."
- Approving a column drop without a written backfill.
- Approving an FK on a >10M-row table without a same-migration index.
- Approving without a down migration or written rollback runbook.

**All of these mean: stop. Block the migration until the missing artifact lands.**

## Common Rationalizations

**REQUIRED SUB-FILE:** Read `rationalizations.md` if you find yourself making excuses. The verbatim-excuse-to-reality table is anchored in the `migration-fast-track` baseline and is specifically tuned to convert prior team agreement back into present evidence.

## Self-Review Checklist

- [ ] Every migration file in the diff was read.
- [ ] Every DROP / ALTER COLUMN / TRUNCATE has a verdict.
- [ ] New FK columns on tables >10M rows have an index in the same migration.
- [ ] Down migration or written rollback runbook exists for every irreversible change.
- [ ] If a column with data is being dropped, a backfill is written and tested.
- [ ] `CREATE INDEX CONCURRENTLY` is used on any index against a non-empty table.

Cannot check all boxes? SAFE TO DEPLOY: NO. Block until addressed.

## What this skill does NOT cover

- **Application code changes** that match the schema (handled by code review or `/security-review`).
- **Data quality after migration** (run a separate validation pass post-deploy).
- **Performance regression testing** at scale (separate exercise; this skill checks indexes exist, not whether they're optimal).
