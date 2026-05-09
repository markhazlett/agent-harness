# G8 — New `/debug` rigid skill (staged debugging)

**Workstream:** harness-rigorization
**Wave:** 3 (depends on G2 + G6)
**Effort:** 2 pts
**Type:** Build

## Goal

Add a new rigid skill `/debug` implementing staged debugging per principle §34. Today this harness has no debugging skill — debugging is improvised, which is exactly the principle's named failure mode.

The skill defines four phases that must run in order, an attempt counter, and an architectural-escalation rule after 3 failed fixes.

## Dependencies

- **G2** — `bin/skill-baseline` must exist.
- **G6** — rigid template must exist and be proven.
- **G1** — frontmatter contract.

## Key Decisions (already made)

- Phases (in order): root-cause investigation → pattern analysis → hypothesis + minimal testing → implementation. Single fix at a time. Verify after.
- Attempt counter: track via TodoWrite. After 3 failed fixes, the skill forces a stop-and-question-the-architecture step.
- Hand-off to `/tdd` after a hypothesis is validated and a fix is identified — `/debug` doesn't write the fix; it hands off to `/tdd` to write a failing test that captures the bug, then implement.
- `/debug` is `tier: rigid, kind: process` (it's a process skill that runs before implementation, per §15).

## File footprint

**Creates:**
- `.claude/skills/debug/SKILL.md`
- `.claude/skills/debug/rationalizations.md`
- `.claude/skills/debug/red-flags.md`
- `docs/skill-baselines/debug-thrash-2026-05-09.md` (or whenever executed)
- `docs/skill-baselines/_scenarios/debug-thrash.md` — new scenario.

**Modifies:**
- `.claude/skills/CONVENTIONS.md` — list `/debug` in the rigid-skill index.
- `README.md` — add `/debug` to the "All skills > Quality" table.
- `.claude/skills/incident/SKILL.md` — at the end, add handoff: "After root cause is named (per `/incident` Phase 2), hand off to `/debug` for the fix process. Do not invoke `/tdd` directly — `/debug` will hand off to `/tdd` after Phase 3 validates the hypothesis."

**Reads (context only):**
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/systematic-debugging/SKILL.md` (canonical reference for staged debugging).
- `Harness Principles.md` §34.
- The G6 rigid template.

## Implementation steps

### Phase 1: New pressure scenario

1. **Write `docs/skill-baselines/_scenarios/debug-thrash.md`.** Pressure type: exhaustion + sunk cost. Setup: "test failing, you've tried 3 fixes, none worked, it's late, the team needs the build green." Expected violations: trying a 4th random fix without questioning the architecture, declaring the test "flaky" without evidence, reverting without root cause, blaming an unrelated commit.

### Phase 2: Run baseline

2. **Run baseline for `/debug`** WITHOUT the skill (because it doesn't exist yet). The subagent should attempt the debug-thrash scenario unstructured. Capture the rationalizations: "must be flaky," "let me try downgrading the dep," "did this work yesterday?", "the test is wrong."

3. **Write `docs/skill-baselines/debug-thrash-<DATE>.md`** with extracted rationalizations.

### Phase 3: Write the skill

4. **Create `.claude/skills/debug/SKILL.md`.** Use the G6 rigid template. Specifics:

   **Frontmatter:**
   ```yaml
   ---
   name: debug
   description: Use when encountering a bug, test failure, or unexpected behavior — runs staged investigation before implementing any fix.
   user-invocable: true
   tier: rigid
   kind: process
   ---
   ```

   **Body sections:**
   - Override preamble.
   - **Iron Law:** `NO FIX WITHOUT ROOT CAUSE NAMED AND HYPOTHESIS VALIDATED`.
   - **The four phases** (in order, each with a gate):
     - **Phase 1: Root cause investigation.** Read errors, reproduce locally, check recent changes (git log + git diff), gather evidence at component boundaries (log inputs/outputs at each layer). Gate: produce a one-sentence root-cause hypothesis or stop and ask for help.
     - **Phase 2: Pattern analysis.** Find a working example of the same code path or pattern (in this repo or in similar OSS code). Identify the differences. Gate: list the differences.
     - **Phase 3: Hypothesis + minimal testing.** Pick the smallest change that would prove the hypothesis. Test that change in isolation (a script, a unit test, a console expression). Change ONE variable at a time. Gate: hypothesis confirmed or new hypothesis stated.
     - **Phase 4: Implementation.** Hand off to `/tdd` to write a failing test capturing the bug, then implement the minimal fix, then verify. Do NOT write the fix in `/debug` — `/debug` ends after Phase 3 with a handoff.
   - **Attempt counter.** Use TodoWrite. Each fix attempt increments. After 3 failed implementations, force escalation: stop, write down what you've tried, explicitly question the architecture (is the bug here, or is the design wrong?), and ask the user.
   - **Red Flags** (sibling `red-flags.md` if long, or inline if short):
     - "Must be flaky."
     - "Let me try a different fix."
     - "Did this work yesterday? (without checking)"
     - "Just retry the test."
     - "Downgrade the dep."
     - "It's a race condition." (without evidence)
     - "The test is wrong."
   - **Common Rationalizations** — link to `rationalizations.md`.
   - **Self-Review checklist:**
     - [ ] Phase 1 root cause is one sentence and references concrete evidence.
     - [ ] Phase 2 named at least one working example to compare.
     - [ ] Phase 3 changed exactly one variable per test.
     - [ ] Hand-off to `/tdd` happened only after hypothesis was confirmed.
     - [ ] Attempt count was tracked.
     - [ ] If attempts > 3, architecture-escalation step ran.

5. **Create `.claude/skills/debug/rationalizations.md`** populated from the baseline (step 3).

6. **Create `.claude/skills/debug/red-flags.md`** if the list grows beyond 8 items; otherwise inline in SKILL.md.

### Phase 4: Wire into the harness

7. **Modify `/incident/SKILL.md`** to hand off to `/debug` (see file footprint).

8. **Update README.md.** Add `/debug` to the "Quality" skill table.

9. **Update `.claude/skills/CONVENTIONS.md`** to list `/debug` as a rigid skill.

### Phase 5: Re-baseline

10. Run `bin/skill-baseline --skill debug --scenario debug-thrash` again, this time WITH `/debug` loaded. Confirm the subagent now runs Phase 1 → 2 → 3, names a root cause before attempting a fix, and counts attempts.

11. If the subagent finds new rationalizations (e.g., "Phase 2 doesn't apply here, I'll skip"), add them and iterate.

## Test plan

### Unit
- `bin/test-frontmatter` passes against `/debug/SKILL.md`.
- `rationalizations.md` is a well-formed table.

### E2E
- Pre/post baselines committed.
- Manual: invoke `/debug` on a real bug in this repo (pick something small — a misformatted skill description, a broken test). Confirm the skill walks all 4 phases and hands off to `/tdd` only after Phase 3 confirms.

### Manual verification
- Read `/debug/SKILL.md`. Confirm:
  - Phase order is enforced (no parallelism in phases — 1 → 2 → 3 → 4).
  - Attempt counter is wired to TodoWrite.
  - Architecture escalation triggers at 3 attempts.
  - Hand-off to `/tdd` is named and other implementation skills are forbidden.

## Done criteria

- [ ] `.claude/skills/debug/SKILL.md` exists, follows rigid template, valid frontmatter.
- [ ] `rationalizations.md` populated from baseline.
- [ ] `debug-thrash` scenario committed.
- [ ] Pre + post baselines committed.
- [ ] `/incident` hands off to `/debug` (per file footprint).
- [ ] `/debug` hands off to `/tdd` after Phase 3 — and explicitly forbids invoking other implementation skills.
- [ ] README and CONVENTIONS.md reference `/debug`.
- [ ] Attempt counter visible via TodoWrite.

## Skills

- `/skill-baseline`
- `/tdd` (where `/debug` hands off)
- `/learn` (capture any patterns surfaced)

## Notes for the executor

- The phase ordering is the rigidity. If you find yourself wanting to skip Phase 2 because "it's a small bug," you've found the rationalization that needs to be in the table.
- The attempt counter is the architectural-escalation forcing function. Without TodoWrite tracking, the principle is just text. Wire it concretely.
- Resist scope creep. `/debug` does NOT write the fix. It hands off. The handoff is the discipline.
