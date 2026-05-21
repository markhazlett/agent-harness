# DB Review — full checks reference

Loaded on demand from `SKILL.md`. Detailed destructive-op table, index review, rollback assessment, and the output format.

## Configuration

Read `.claude/hooks/config.sh` for:

- `HARNESS_DB_SCHEMA_PATH` — path to the schema file
- `HARNESS_DB_MIGRATIONS_DIR` — path to migrations directory
- `HARNESS_DB_GENERATE_CMD` — command to generate/check migrations

If `HARNESS_DB_SCHEMA_PATH` is not configured, report that DB review is not configured and exit.

## 1. Identify Changes

```bash
git diff -- $HARNESS_DB_SCHEMA_PATH
ls -la $HARNESS_DB_MIGRATIONS_DIR
```

Read the current schema file and any new/modified migration files.

## 2. Destructive Operation Scan

| Operation | Risk | Action |
|-----------|------|--------|
| `DROP TABLE` | DATA LOSS | FAIL — requires explicit user approval and backup plan |
| `DROP COLUMN` | DATA LOSS | FAIL — data is permanently deleted |
| `ALTER COLUMN ... TYPE` | POSSIBLE DATA LOSS | WARN — type coercion may truncate/fail |
| `DELETE FROM` without `WHERE` | DATA LOSS | FAIL — full table wipe |
| `TRUNCATE` | DATA LOSS | FAIL — full table wipe |
| `DROP INDEX` | PERFORMANCE | WARN — may degrade query performance |
| `ALTER TABLE ... RENAME` | BREAKING | WARN — application code must be updated simultaneously |
| `NOT NULL` constraint on existing column | POSSIBLE FAILURE | WARN — fails if existing rows have NULLs |

## 3. Index Review

For any new table or new foreign key column:

- Index exists for the FK column (missing FK indexes cause slow JOINs at scale).
- Composite indexes match common query patterns.
- Vector columns (pgvector): HNSW or IVFFlat index with appropriate parameters.

```sql
CREATE INDEX ... ON table USING hnsw (column vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);
```

## 4. Rollback Assessment

| Change | Reversible? |
|--------|-------------|
| Adding a column | YES (drop it) |
| Adding a table | YES (drop it) |
| Adding an index | YES (drop it) |
| Dropping a column | NO (data gone) |
| Changing column type | MAYBE (type compatibility) |

Locking behavior:

- Adding a column with DEFAULT on large tables: may lock (Postgres 11+ handles this well, but flag for awareness).
- `CREATE INDEX CONCURRENTLY` avoids locks; plain `CREATE INDEX` will lock writes.
- Altering column type: locks the table.

## 5. Schema Consistency

- ORM schema matches the migration SQL.
- Run the generate command and check for additional migrations (schema drift).
- Enum types in TypeScript/code match database enum definitions.

## 6. Data Migration Needs

If the schema change requires existing data to be transformed:

- Is there a data migration script (not just schema)?
- What happens to existing rows (NULLs, defaults, constraint violations)?
- Estimate execution time on current data volume.

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

## Execution Rules

- Read EVERY pending migration file — don't skip any.
- Always check for `DROP` operations — most dangerous.
- Irreversible migrations require explicit user acknowledgment before approval.
- Recommend `CREATE INDEX CONCURRENTLY` for any index on tables with existing data.
- Never approve a migration that drops a vector extension or critical indexes without explicit user approval.
