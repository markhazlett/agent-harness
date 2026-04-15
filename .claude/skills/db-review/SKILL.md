# DB Review

Review pending database migrations and schema changes for safety before deploying to production. Catches destructive operations, missing indexes, and irreversible changes.

Trigger: when the user says "review migrations", "db review", "check schema changes", "safe to migrate?", or before deploying schema changes to production.

## Configuration

Read `.claude/hooks/harness.config.sh` for:
- `HARNESS_DB_SCHEMA_PATH` — path to the schema file
- `HARNESS_DB_MIGRATIONS_DIR` — path to migrations directory
- `HARNESS_DB_GENERATE_CMD` — command to generate/check migrations

If `HARNESS_DB_SCHEMA_PATH` is not configured, report that DB review is not configured and exit.

## Review Process

### 1. Identify Changes

```bash
# Find uncommitted schema changes
git diff -- $HARNESS_DB_SCHEMA_PATH

# Find pending migrations
ls -la $HARNESS_DB_MIGRATIONS_DIR
```

Read the current schema file and any new/modified migration files.

### 2. Destructive Operation Scan

For each pending migration SQL file, check for:

| Operation | Risk | Action |
|-----------|------|--------|
| `DROP TABLE` | DATA LOSS | FAIL — requires explicit user approval and backup plan |
| `DROP COLUMN` | DATA LOSS | FAIL — data is permanently deleted |
| `ALTER COLUMN ... TYPE` | POSSIBLE DATA LOSS | WARN — type coercion may truncate/fail |
| `DELETE FROM` without `WHERE` | DATA LOSS | FAIL — full table wipe |
| `TRUNCATE` | DATA LOSS | FAIL — full table wipe |
| `DROP INDEX` | PERFORMANCE | WARN — may degrade query performance |
| `ALTER TABLE ... RENAME` | BREAKING | WARN — application code must be updated simultaneously |
| `NOT NULL` constraint on existing column | POSSIBLE FAILURE | WARN — will fail if existing rows have NULLs |

### 3. Index Review

For any new table or new foreign key column:

- Check if an index exists for the FK column (missing FK indexes cause slow JOINs at scale)
- Check if composite indexes match common query patterns
- For vector columns (pgvector): verify HNSW or IVFFlat index is created with appropriate parameters

```sql
-- Pattern to look for in vector migrations:
CREATE INDEX ... ON table USING hnsw (column vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);
```

### 4. Rollback Assessment

For each migration, assess:

- **Reversible?** Can this be undone without data loss?
  - Adding a column: YES (drop it)
  - Adding a table: YES (drop it)
  - Adding an index: YES (drop it)
  - Dropping a column: NO (data gone)
  - Changing column type: MAYBE (depends on type compatibility)
- **Requires downtime?** Will this lock tables during execution?
  - Adding a column with DEFAULT on large tables: may lock (Postgres 11+ handles this well, but flag for awareness)
  - Creating an index: `CREATE INDEX CONCURRENTLY` avoids locks, but plain `CREATE INDEX` will lock writes
  - Altering column type: locks the table

### 5. Schema Consistency

- Verify ORM schema matches the migration SQL
- Run the generate command and check if it produces additional migrations (schema drift)
- Verify enum types used in TypeScript/code match database enum definitions

### 6. Data Migration Needs

If the schema change requires existing data to be transformed:

- Is there a data migration script? (Not just a schema migration)
- What happens to existing rows? (NULLs, defaults, constraint violations)
- Estimate execution time on current data volume

## Output Format

```
## DB Review — [date]

### Migrations Under Review
1. `<migration-file>` — [summary of changes]

### Risk Assessment

| Migration | Destructive? | Reversible? | Locks Tables? | Verdict |
|-----------|-------------|-------------|---------------|---------|
| <file> | No | Yes | No | SAFE |

### Findings

#### FAIL (Block Deploy)
- [finding with specific SQL line reference]

#### WARN (Deploy with Caution)
- [finding]

#### Recommendations
- [suggested improvements — concurrent indexes, data backfill scripts, etc.]

### Verdict: SAFE TO DEPLOY / NEEDS FIXES / NEEDS DISCUSSION
```

## Rules

- Read EVERY pending migration file — don't skip any
- Always check for `DROP` operations — these are the most dangerous
- If a migration is irreversible, require explicit user acknowledgment before approving
- Recommend `CREATE INDEX CONCURRENTLY` for any index on tables with existing data
- Never approve a migration that drops vector extension or critical indexes without explicit user approval
