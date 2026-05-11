---
name: debug
description: Use when encountering a bug, test failure, or unexpected behavior — runs staged investigation before implementing any fix.
user-invocable: true
tier: rigid
kind: process
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Run `/harness-update` to pull it in." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# /debug

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

Staged debugging: root cause → pattern analysis → hypothesis + minimal test → handoff. `/debug` doesn't write the fix; it hands off to `/tdd` after Phase 3 confirms the hypothesis.

## The Iron Law

```
NO FIX WITHOUT ROOT CAUSE NAMED AND HYPOTHESIS VALIDATED
```

A fix without evidence is a guess. "Let me try one more thing" means you've been guessing. After 3 failed implementations, stop and question the architecture.

## The Four Phases (strict order; each has a gate)

Track attempts via TodoWrite — every fix attempt is one todo, completed on verify/revert.

1. **Root cause.** Read the *actual* error output (not just the FAIL line). Reproduce locally. Check recent changes (`git log --since=...`, `git diff main...HEAD`). Log inputs/outputs at component boundaries until you see the value go wrong. **Gate:** one-sentence hypothesis with file:line evidence, or stop and ask the user.
2. **Pattern analysis.** Find a working example of the same code path — elsewhere in this repo, in a sibling test, in OSS. Name the differences. **Gate:** differences listed in writing.
3. **Hypothesis + minimal test.** Pick the smallest change that would *prove* the hypothesis (a `console.log`, an isolated unit test, a one-line expression). Change ONE variable at a time, run in isolation. **Gate:** hypothesis confirmed by evidence, or a new (narrower) hypothesis stated.
4. **Implementation handoff.** Hand off to `/tdd`: *"Root cause: `<one sentence>`. Confirmed by `<evidence>`. Failing test captures `<assertion>`."* `/debug` ends here. Do NOT write the fix; do NOT invoke other implementation skills.

## Attempt counter — architecture escalation at 3

After **3 failed implementations**, stop. Don't try a 4th fix. Write down each attempt + why it failed; explicitly ask: *Is the bug here, or is the design wrong?* Read adjacent code with that lens; ask the user before continuing.

Three failures = the bug is not where you're looking.

## Red Flags — STOP

**REQUIRED SUB-FILE:** Read `red-flags.md` for the full list (evidence-skipping, guess-as-fix, test-blame, phase-skipping, sunk-cost, authority pressure). The most common: *"Must be flaky," "Let me try one more thing," "Just retry the test," "Mark it `.skip()`."* All mean: stop. Read the actual error. Name the root cause before any next step.

## Common Rationalizations

**REQUIRED SUB-FILE:** Read `rationalizations.md` if you find yourself making excuses. The verbatim-excuse-to-reality table is anchored in the `debug-thrash` baseline (where the load-bearing distinction is *guessing vs debugging* — a fix without evidence is a guess).

## Self-Review Checklist

- [ ] Phase 1 root cause is one sentence with file:line evidence.
- [ ] Phase 2 named at least one working example.
- [ ] Phase 3 changed exactly one variable per test.
- [ ] Hand-off to `/tdd` only after hypothesis confirmed.
- [ ] Attempt count tracked via TodoWrite.
- [ ] If attempts > 3, architecture-escalation ran and user was asked.

Cannot check all boxes? You skipped a phase. Restart from the unmet gate.

## What this skill does NOT cover

Writing the fix (use `/tdd`), production incident triage (use `/incident`, which hands off to `/debug` after root cause), and architectural redesign (propose as a separate workstream after the 3-attempt escalation).
