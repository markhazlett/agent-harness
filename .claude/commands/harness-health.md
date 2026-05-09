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

### 5. Learn Helper

Verify `bin/learn` exists and is executable, then run its test suites:

```bash
test -x bin/learn && echo "PASS bin/learn" || echo "FAIL bin/learn (missing or not executable)"
bash bin/tests/learn.test.sh >/dev/null 2>&1 && echo "PASS learn tests" || echo "FAIL learn tests"
test -x bin/test-learn-anti-list && echo "PASS bin/test-learn-anti-list" || echo "FAIL bin/test-learn-anti-list (missing or not executable)"
bash bin/test-learn-anti-list >/dev/null 2>&1 && echo "PASS learn anti-list tests" || echo "FAIL learn anti-list tests"
```

### 6. Settings Wiring

Verify `.claude/settings.json` has all hooks wired:
- `SessionStart` → `init.sh` (startup) and `context-reinject.sh` (resume|compact)
- `PreToolUse` → `bash-guard.sh` (Bash) and `protected-files.sh` (Edit|Write|MultiEdit)
- `PostToolUse` → `post-edit.sh` (Edit|Write|MultiEdit)
- `PostToolUseFailure` → `failure-log.sh`
- `PreCompact` → `pre-compact.sh`
- `Stop` → `stop.sh`

### 7. Agent Files

Verify each agent file exists:
- `.claude/agents/builder.md`
- `.claude/agents/validator.md`
- `.claude/agents/e2e-tester.md`
- `.claude/agents/migration-validator.md`

### 8. Config Populated

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

## Conductor integration checks

First, read `HARNESS_HOST` from `.claude/hooks/harness.config.sh`:

```bash
HARNESS_HOST=$(grep -E '^HARNESS_HOST=' .claude/hooks/harness.config.sh 2>/dev/null | head -1 | sed -E 's/^HARNESS_HOST="?([^"]*)"?$/\1/')
HARNESS_HOST="${HARNESS_HOST:-conductor}"   # unset = conductor (backward compat)
```

If `HARNESS_HOST="claude-code"`, print one line per probe:

```
SKIP: conductor-status (host = claude-code)
SKIP: conductor-dispatch (host = claude-code)
SKIP: conductor-context hook (host = claude-code)
SKIP: conductor-context hook wired in settings.json (host = claude-code)
SKIP: conductor.json (host = claude-code)
SKIP: conductor-status tests (host = claude-code)
SKIP: conductor-dispatch tests (host = claude-code)
SKIP: conductor-context tests (host = claude-code)
```

No probes run. `SKIP` is not a failure — this is expected health for a Claude Code install.

If `HARNESS_HOST="conductor"` (or unset, for backward-compat installs), run:

```bash
test -x bin/conductor-status && echo "OK: conductor-status executable" || echo "FAIL: bin/conductor-status missing or not executable"
test -x bin/conductor-dispatch && echo "OK: conductor-dispatch executable" || echo "FAIL: bin/conductor-dispatch missing or not executable"
test -x .claude/hooks/conductor-context.sh && echo "OK: conductor-context hook executable" || echo "FAIL: conductor-context hook missing or not executable"
jq -e '.hooks.SessionStart[] | select(.matcher=="startup") | .hooks[] | select(.command=="'.claude/hooks/conductor-context.sh'")' .claude/settings.json >/dev/null && echo "OK: conductor-context hook wired in settings.json" || echo "FAIL: conductor-context hook not wired"
test -f conductor.json && echo "OK: conductor.json exists" || echo "WARN: conductor.json not present (run setup.sh to generate)"
bash bin/tests/conductor-status.test.sh >/dev/null 2>&1 && echo "OK: conductor-status tests pass" || echo "FAIL: conductor-status tests failing"
bash bin/tests/conductor-dispatch.test.sh >/dev/null 2>&1 && echo "OK: conductor-dispatch tests pass" || echo "FAIL: conductor-dispatch tests failing"
bash bin/tests/conductor-context.test.sh >/dev/null 2>&1 && echo "OK: conductor-context tests pass" || echo "FAIL: conductor-context tests failing"
```

**Conductor mode expected output:** all four `OK:` lines for the helpers + hook wiring. `WARN: conductor.json not present` is acceptable in the harness repo itself (we don't ship one). `FAIL` for any test invocation typically indicates a regression, but on a fresh clone where `bin/conductor-*` helpers are missing, probes 6–8 will also FAIL — the first three `FAIL:` lines from the existence checks are the authoritative signal in that case.

**Claude Code mode expected output:** eight `SKIP:` lines. No `FAIL:`, no `WARN:`.
