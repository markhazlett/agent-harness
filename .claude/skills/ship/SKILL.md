<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Ship

Run the full shipping pipeline: tests, lint, E2E verify, commit, push, and create a PR. Use when the user says "/ship", "ship it", "let's ship", or "push this up".

## Prerequisites

- All changes are saved (no pending edits)
- On a feature branch (not main)
- Dev server is running for E2E verification

## Pipeline

### 1. Run Tests

Read `HARNESS_TEST_CMD` from `.claude/hooks/harness.config.sh` and run it.

If tests fail, stop and report. Do not continue.

### 2. Run Lint

Read `HARNESS_LINT_CMD` from `.claude/hooks/harness.config.sh` and run it.

Report warnings but continue. Stop only on errors.

### 3. E2E Verify (if UI changes)

If any UI files were changed:
- Use the `e2e-verify` skill to check the UI in the browser
- If critical issues found, stop and report

### 4. Commit

- Stage changed files (specific files, not `git add -A`)
- Write a conventional commit message based on the changes
- Include `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`

### 5. Push

```bash
git push -u origin <branch-name>
```

### 6. Create PR

Use `gh pr create` with:
- Short title (under 70 chars)
- Body with Summary (bullet points), Schema Changes (if any), and Test Plan
- End body with: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`

## Flags

- `/ship --no-e2e` — skip browser verification
- `/ship --no-pr` — push but don't create PR
- `/ship --amend` — amend previous commit instead of creating new one (only if user explicitly requests)

## Failure Handling

If any step fails:
1. Report exactly what failed and why
2. Suggest a fix
3. Do NOT continue the pipeline
4. Do NOT force-push or skip verification
