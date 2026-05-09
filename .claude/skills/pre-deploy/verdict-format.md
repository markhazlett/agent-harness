# Verdict Format — /pre-deploy

Print the verdict in this shape so the user (and downstream tooling) can scan it consistently. Loaded on demand from `SKILL.md`.

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

Status values: `PASS`, `WARN`, `FAIL`. Any single `FAIL` = NO-GO. WARNs are reported but don't block. The Action Items section is omitted on a clean GO.
