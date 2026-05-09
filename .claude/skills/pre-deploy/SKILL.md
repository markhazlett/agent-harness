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

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

The full pre-deployment quality gate. Aggregates lint, type-check, tests, build, migration check, env audit, and console cleanup into a single GO / NO-GO verdict.

## The Iron Law

```
NO DEPLOY APPROVAL WITHOUT FRESH GATE EVIDENCE
```

Every gate runs against the current diff, in this run, with green output. Stale evidence is no evidence. A subset run isn't the gate. Authority is ownership of risk, not safety. "Small change" is not an exemption.

## Gate Sequence

Run all gates against the current branch. Stop on any FAIL. Read `.claude/hooks/harness.config.sh` for commands.

1. **Git state.** Feature branch (not `main`/`production`), clean tree, up to date with remote.
2. **Type check.** `HARNESS_TYPECHECK_CMD` — FAIL on errors.
3. **Lint.** `HARNESS_LINT_CMD` — FAIL on errors; WARN on warnings (with count).
4. **Tests.** `HARNESS_TEST_CMD` — FAIL on any failure; report pass/fail/skip.
5. **Build.** `HARNESS_BUILD_CMD` — FAIL on build errors.
6. **Migration check.** If `HARNESS_DB_SCHEMA_PATH` is set and the schema changed, verify a corresponding migration exists in `HARNESS_DB_MIGRATIONS_DIR`. WARN if absent.
7. **Env audit.** Cross-reference `process.env.*` against `.env.example`/`.env.template`. WARN on undocumented; FAIL on missing required vars.
8. **Console cleanup.** Grep `console.log` in source (excl. tests). WARN with file:line. `console.error`/`console.warn` are intentional.

After fixes, re-run the **full** pipeline. Fixes can break previously-green gates.

## Verdict

Print the verdict in the format documented in `verdict-format.md`. Status values: `PASS`, `WARN`, `FAIL`. Any single FAIL = NO-GO. WARNs are reported but don't block.

## Red Flags — STOP

- "Tests passed last time, skip them this time."
- "Run lint and type-check only — the cheap checks."
- "The VP owns the risk."
- "It's a small change, the gate is overkill."
- "We can harden post-launch."
- "I'll file a follow-up ticket."
- Approving GO when a gate is WARN you didn't read.
- Treating a flaky-looking test as flaky without investigating.
- Skipping `/security-review` on an auth diff or `/db-review` on a schema diff.

**All of these mean: stop. Run the full gate against the current diff before any GO verdict.**

## Common Rationalizations

**REQUIRED SUB-FILE:** Read `rationalizations.md` if you find yourself making excuses. The verbatim-excuse-to-reality table is anchored in real authority/deadline pressure baselines.

## Self-Review Checklist

- [ ] Every gate ran against the current branch HEAD (not stale).
- [ ] Every gate output was read in full.
- [ ] No FAIL is being treated as a WARN.
- [ ] Auth/session diff → `/security-review` ran and passed.
- [ ] Schema/migration diff → `/db-review` ran and passed.
- [ ] WARNs are documented in the verdict, not hidden.
- [ ] You can name what each gate caught — or that it had nothing to catch.

Cannot check all boxes? NO-GO. Fix and re-run.

## What this skill does NOT cover

Code review (use `/security-review`, `/db-review`, or human review for risky diffs), production runtime monitoring (next layer), and rollback strategy (document in PR, not gated here).
