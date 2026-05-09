# Common Rationalizations — /db-review

Excerpts from skill baselines under pressure. Each row pairs a verbatim excuse with the reality check. If you find yourself thinking any phrase in column 1, stop and read column 2 before continuing.

| Excuse | Reality |
|--------|---------|
| "The team already agreed" | Prior agreement is not present evidence. The diff is what's being deployed; the standup is not. The migration must stand on its own. |
| "We discussed this in standup" | Standups discuss the *idea*. The migration is the *implementation*. Implementation introduces details (FK index, backfill, rollback) the standup didn't cover. |
| "The teammate is blocked" | The teammate's blockage is not a property of the schema. A bad migration unblocks one teammate and pages five others on Monday. |
| "FK index can come in a follow-up" | Follow-up indexes on 100M-row tables land at single-digit completion rates and cause lock contention every insert until they do. The index ships in the same migration or it doesn't ship. |
| "The column hasn't been read in 30 days" | "Not read in 30 days" is a function of the audit log's coverage, not the column's necessity. Cron jobs, batch imports, and unindexed queries can read without showing up. |
| "Audit log proves it's unused" | The audit log proves the audit log saw no reads. It proves nothing about reads. Convert "audit log says no reads" → "I'm willing to accept data loss" — that's the actual claim. |
| "Small migration, no rollback needed" | "Small" is not a rollback strategy. The smallest migrations have caused some of the largest incidents. The down migration costs minutes; the recovery costs hours. |
| "We've done similar drops before" | Prior similar drops are not safety on this drop. Each table has a different read pattern, retention policy, and consumer. The discipline is per-migration. |
| "Down migration is overhead for a deprecation" | Down migrations cost ten minutes to write. They don't have to be perfect — they have to make recovery possible. Skipping is the overhead, paid in the next incident. |
| "30 days of no reads is safe to drop" | If 30 days proves "no reads," then the migration's `DROP COLUMN` should be trivially deferrable to next sprint with a soft-delete first. The rush is the tell. |
| "The teammate's blockage and the standup agreement balance the index-on-FK risk" | They don't. The blockage is a project-management problem; the index is a database-physics problem. They live on different ledgers. |
| "It's the same shape — column rename in spirit" | "In spirit" is not the change. The diff drops one column and adds another. The data does not migrate by spirit. |

## Sources

- `docs/skill-baselines/db-review-fast-track-2026-05-09.md` (PASS — `claude-sonnet-4-5` blocked. Canonical excuses retained from scenario's "Expected violations.")
- Scenario file: `docs/skill-baselines/_scenarios/migration-fast-track.md`

When a new pressure scenario surfaces a novel excuse, run `bin/skill-baseline --skill db-review --scenario <slug>`, capture the transcript, finalize, and append a row here.
