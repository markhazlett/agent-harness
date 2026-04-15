# Harness Health Check

Verify all quality harness components are working correctly.

## Checks to Run

### 1. Hook Scripts

Verify each hook script exists and is executable:

```bash
for hook in bash-guard.sh protected-files.sh init.sh context-reinject.sh post-edit.sh stop.sh failure-log.sh pre-compact.sh config-audit.sh harness.config.sh; do
  if [ -x ".claude/hooks/$hook" ]; then
    echo "PASS $hook"
  else
    echo "FAIL $hook (missing or not executable)"
  fi
done
```

### 2. Format Check

Read `.claude/hooks/harness.config.sh` for `HARNESS_FORMAT_CMD` and run the format check.

### 3. Lint

Read `.claude/hooks/harness.config.sh` for `HARNESS_LINT_CMD` and run it.

### 4. Tests

Read `.claude/hooks/harness.config.sh` for `HARNESS_TEST_CMD` and run it.

### 5. Settings Wiring

Verify `.claude/settings.json` has all hooks wired:
- `SessionStart` → `init.sh` (startup) and `context-reinject.sh` (resume|compact)
- `PreToolUse` → `bash-guard.sh` (Bash) and `protected-files.sh` (Edit|Write|MultiEdit)
- `PostToolUse` → `post-edit.sh` (Edit|Write|MultiEdit)
- `PostToolUseFailure` → `failure-log.sh`
- `PreCompact` → `pre-compact.sh`
- `Stop` → `stop.sh`

### 6. Agent Files

Verify each agent file exists:
- `.claude/agents/builder.md`
- `.claude/agents/validator.md`
- `.claude/agents/e2e-tester.md`
- `.claude/agents/migration-validator.md`

### 7. Config Populated

Read `.claude/hooks/harness.config.sh` and verify key values are set:
- `HARNESS_PKG_MGR` is set
- `HARNESS_SRC_DIRS` is set
- `HARNESS_TEST_CMD` is set
- `HARNESS_APP_NAME` is not still "My Project" (suggests setup.sh was run)

## Output Format

```
## Harness Health — [date]

| Component | Status | Notes |
|-----------|--------|-------|
| bash-guard.sh | PASS/FAIL | |
| protected-files.sh | PASS/FAIL | |
| init.sh | PASS/FAIL | |
| ... | | |
| Format | PASS/FAIL | |
| Lint | PASS/FAIL | |
| Tests | PASS/FAIL | |
| Settings wiring | PASS/FAIL | |
| Config populated | PASS/WARN | |

### Verdict: HEALTHY / NEEDS ATTENTION
```
