---
name: deep-review
description: Use when the user says "/deep-review", "deep review", "thorough review", or wants the deepest possible code review before pushing a branch.
user-invocable: true
tier: rigid
kind: verification
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Run `/harness-update` to pull it in." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Deep Review

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

_Body deferred to Task 11 — written after baselines._
