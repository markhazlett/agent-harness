---
name: ship
description: Use when the user says "/ship", "ship it", "let's ship", or "push this up" and the branch is ready to leave the workstation — runs the full shipping pipeline (tests, lint, e2e, commit, push, PR).
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

# Ship

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

Run the full shipping pipeline: risk-check → tests → lint → E2E verify (if UI) → commit → push → create PR.

## The Iron Law

```
NO PUSH WITHOUT GREEN PIPELINE AND A REAL PR DESCRIPTION
```

Every push reflects a green test run, clean lint, a conventional commit, and a PR with a Summary + Test plan that a reviewer can read without Slack context. Flaky tests aren't green — fix them. One-line PR descriptions aren't descriptions. "I'll amend later" isn't a workflow.

## Pipeline

Read `.claude/hooks/harness.config.sh` for commands. Stop on any failure.

### 0. Risk-Check (pre-pipeline)

Scan the diff for risk surfaces (auth/session, schema/migrations, deploy config, hooks — full list in `risk-surfaces.md`). If any match, ask once: *"Did you run `/pre-deploy`? This diff touches `<surface>` — recommend running it before push."* Don't auto-fire `/pre-deploy`; just ask. Continue when the user responds.

### 1–6. The Pipeline

1. **Tests** — `HARNESS_TEST_CMD`. Stop on failure; investigate, don't retry.
2. **Lint** — `HARNESS_LINT_CMD`. Stop on errors; warnings noted.
3. **E2E** — if UI changed, fire `/e2e-verify` against the dev server.
4. **Commit** — stage specific files, conventional message `<type>(<scope>): <subject>`, append `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`.
5. **Push** — `git push -u origin <branch>`. Never to `main`/`master` (bash-guard blocks it).
6. **PR** — `gh pr create` with title <70 chars, body has `## Summary` + `## Test plan` + Claude Code attribution. Use heredoc.

### Flags

- `--no-e2e` — skip browser verify (only when no UI changed).
- `--no-pr` — push without PR (rare; stacking).
- `--amend` — amend previous commit (only when user explicitly requests).

## Red Flags — STOP

- "The fix is one line, the lint pass is overhead."
- "Tests are flaky anyway, retry passing is fine."
- "PR description can be one line, real description in a follow-up."
- "Skip lint, the formatter ran on save."
- "Push now, open the PR after the demo."
- "I'll amend later."
- Pushing without a PR.
- Skipping risk-check on auth/schema/deploy diffs.

**All of these mean: stop. Run the full pipeline against the current branch before pushing.**

## Common Rationalizations

**REQUIRED SUB-FILE:** Read `rationalizations.md` if you find yourself making excuses. The verbatim-excuse-to-reality table is anchored in real time-pressure baselines.

## Self-Review Checklist

- [ ] Risk-check fired on auth/schema/deploy/hook diffs (and user answered).
- [ ] Tests fresh against current HEAD; green.
- [ ] Lint fresh; no errors.
- [ ] UI changed → `/e2e-verify` ran and passed.
- [ ] Commit is conventional, scoped, with co-author attribution.
- [ ] PR title <70 chars; body has Summary + Test plan.
- [ ] `git status` clean post-push.

Cannot check all boxes? Don't claim the ship. Fix and re-run.

## What this skill does NOT cover

`/pre-deploy` (the full gate; risk-check above only *asks*), production runtime systems, and syncing with main (use `/sync` first if behind).
