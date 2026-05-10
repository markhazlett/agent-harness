---
name: tdd
description: Use when implementing any feature or bugfix, before writing implementation code, or when the user says "write tests first", "TDD", or "test-drive this".
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

# TDD Workflow

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

Test-driven development for every new function, bugfix, refactor, or behavior change. The order is the proof.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Wrote code before the test? Delete it. Start over. Don't keep it as reference, don't adapt it, don't look at it. Implement fresh from the test.

## Cycle: Red → Green → Refactor

1. **RED.** Write one failing test. Clear name, one behavior, real code (no mocks unless unavoidable). State what *should* happen.
2. **Verify RED.** Run it. Confirm it fails (not errors), and fails for the right reason (feature missing, not typo). Test passes immediately? You're testing existing behavior — fix the test.
3. **GREEN.** Minimal code to pass. No extra features, no abstractions, no improvements beyond the test.
4. **Verify GREEN.** Run it. Confirm pass, other tests still pass, clean output.
5. **REFACTOR.** Remove duplication, improve names, extract helpers. Keep tests green. Don't add behavior. Next failing test.

Project mock patterns (Vitest `vi.hoisted()`, Jest) live in `mock-patterns.md`.

## Red Flags — STOP and Start Over

- Code before test, or test after implementation.
- Test passes immediately on first run.
- Can't explain why the test failed.
- "I'll add the test in a follow-up PR."
- "I already manually tested it."
- "Tests after achieve the same purpose."
- "It's about spirit, not ritual."
- "Keep as reference" or "adapt existing code."
- "Already spent X hours, deleting is wasteful."
- "TDD is dogmatic, I'm being pragmatic."
- "This is different because…"

**All of these mean: stop. Delete the code. Start over with a failing test.**

## Common Rationalizations

**REQUIRED SUB-FILE:** Read `rationalizations.md` if you find yourself making excuses. The verbatim-excuse-to-reality table is harvested from real subagent baselines under pressure.

## Self-Review Checklist

- [ ] Every new function/method has a test.
- [ ] You watched each test *fail* before implementing.
- [ ] Each failure was for the expected reason (feature missing, not typo).
- [ ] You wrote the minimal code to pass each test.
- [ ] All tests pass; output is clean.
- [ ] Tests use real code — mocks only where unavoidable (`mock-patterns.md`).
- [ ] Edge cases and error paths are covered.

Cannot check all boxes? You skipped TDD. Delete and start over.

## What this skill does NOT cover

Throwaway prototypes (with explicit user permission), generated code, configuration files, and documentation changes. For exemptions outside this list, name them in `CLAUDE.md` § Instruction precedence — not as a per-task rationalization.

## Terminal State

After the cycle passes:

- **Invoked from `/build`?** Return to the `/build` execution loop. Terminal state = next Implementation Step.
- **Standalone AND your edits touched UI surfaces** (extensions `.tsx` / `.jsx` / `.vue` / `.svelte`, paths under `src/components/` or `apps/web/`)? **Terminal state is `/e2e-verify`.** Do NOT mark complete without browser evidence.
- **Standalone AND no UI changes**? Terminal state. Done.

Do NOT invoke `/ship`, `/pre-deploy`, or other downstream skills directly from `/tdd` — let the caller (`/build` or the user) drive the next gate, or hand off to `/e2e-verify` per the rule above. The user can override per `CLAUDE.md` § Instruction precedence.
