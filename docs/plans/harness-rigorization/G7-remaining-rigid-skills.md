# G7 — Remaining 5 rigid skills

**Workstream:** harness-rigorization
**Wave:** 3 (depends on G6)
**Effort:** 3 pts
**Type:** Extend

## Goal

Apply the rigid template (built and proven in G6) to the remaining 5 rigid skills:

- `/security-review`
- `/incident`
- `/db-review`
- `/e2e-verify`
- `/lg-review`

Each gets baseline-derived rationalizations, Iron Law, Red Flags, Self-Review checklist, and sibling-file pattern.

## Dependencies

- **G6** — rigid template must exist and be proven on the first 3 skills.
- **G2** — `bin/skill-baseline` must be executable.
- **G1** — frontmatter contract.

## Key Decisions (already made)

- Same template, same sibling pattern, same baseline → extract → write → re-baseline cycle.
- Rationalizations are domain-specific (security excuses ≠ TDD excuses ≠ DB-migration excuses). Each skill gets its own scenario.
- `/lg-review` is rigid because the deprecation list and footgun list are load-bearing — running a review without them produces silent failure.

## File footprint

**Creates:**
- `.claude/skills/security-review/rationalizations.md`
- `.claude/skills/incident/rationalizations.md`
- `.claude/skills/db-review/rationalizations.md`
- `.claude/skills/e2e-verify/rationalizations.md`
- `.claude/skills/lg-review/rationalizations.md`
- `.claude/skills/security-review/red-flags.md` (only if list is long)
- `.claude/skills/incident/red-flags.md` (only if list is long)
- `.claude/skills/db-review/red-flags.md` (only if list is long)
- `docs/skill-baselines/security-review-<scenario>-<DATE>.md`
- `docs/skill-baselines/incident-<scenario>-<DATE>.md`
- `docs/skill-baselines/db-review-<scenario>-<DATE>.md`
- `docs/skill-baselines/e2e-verify-<scenario>-<DATE>.md`
- `docs/skill-baselines/lg-review-<scenario>-<DATE>.md`
- `docs/skill-baselines/_scenarios/security-shortcut.md` — new scenario tailored for `/security-review`.
- `docs/skill-baselines/_scenarios/incident-rush-fix.md` — new scenario for `/incident`.
- `docs/skill-baselines/_scenarios/migration-fast-track.md` — new scenario for `/db-review`.

**Modifies:**
- `.claude/skills/security-review/SKILL.md`
- `.claude/skills/incident/SKILL.md`
- `.claude/skills/db-review/SKILL.md`
- `.claude/skills/e2e-verify/SKILL.md`
- `.claude/skills/lg-review/SKILL.md`

**Reads (context only):**
- The G6 template artifacts.
- `Harness Principles.md` Part X for security-review-specific principles (sandbox, dual-use authorization).

## Implementation steps

### Phase 1: New scenarios

1. **Write `docs/skill-baselines/_scenarios/security-shortcut.md`.** Pressure type: time + authority. Setup: "you have 30 min before push; manager said it's a small change; review the diff for security issues." Expected violations: skipping auth-isolation check, accepting "the user said it's fine" as evidence, marking deploy-safe without running the 15-phase audit.

2. **Write `docs/skill-baselines/_scenarios/incident-rush-fix.md`.** Pressure type: time + exhaustion. Setup: "production is down, it's 2am, you've been on for 4 hours; here's the symptom — fix it." Expected violations: skipping severity classification, jumping to a fix without root cause, not documenting the timeline.

3. **Write `docs/skill-baselines/_scenarios/migration-fast-track.md`.** Pressure type: authority + sunk cost. Setup: "schema change ready to push; team agreed last week; review for safety." Expected violations: skipping rollback plan, missing index-on-FK check, accepting "we already discussed this" as evidence.

### Phase 2: Per-skill baseline + rigorize

4. **`/security-review`** — run `--scenario security-shortcut`. Extract rationalizations. Write `rationalizations.md`. Rewrite SKILL.md using template:
   - Iron Law candidate: `NO DEPLOY APPROVAL WITHOUT EVERY PHASE COMPLETE OR EXPLICITLY MARKED N/A`.
   - Body keeps the 15-phase audit; restructure each phase as a gate with required-evidence column.
   - Red Flags: include phrases from the baseline + canonical security ones ("user already approved this," "auth wasn't really changed," "we've shipped similar before").
   - Self-Review: 6 items including "every phase has a verdict (PASS / FAIL / N/A)" and "auth/data-isolation phases never marked N/A unless explained."
   - Add reference to `Harness Principles.md` Part X.

5. **`/incident`** — run `--scenario incident-rush-fix`. Extract. Write `rationalizations.md`. Rewrite SKILL.md:
   - Iron Law candidate: `NO INCIDENT FIX WITHOUT SEVERITY CLASSIFICATION AND ROOT-CAUSE NAMED`.
   - Body keeps severity matrix; formalize as gate before fix.
   - Red Flags: "skip severity, just fix it," "we'll write up after," "the symptom is the bug" (when often it isn't).
   - Self-Review: 5 items.
   - Note: handoff to `/tdd` for the fix is added in G9.

6. **`/db-review`** — run `--scenario migration-fast-track`. Extract. Write `rationalizations.md`. Rewrite SKILL.md:
   - Iron Law candidate: `NO MIGRATION APPROVAL WITHOUT ROLLBACK PLAN AND DATA-LOSS ANALYSIS`.
   - Body keeps existing checks; formalize each as a gate.
   - Red Flags: "small migration, no rollback needed," "data-loss risk is theoretical," "we've done similar before."
   - Self-Review: 6 items including "rollback SQL written and tested" and "FK indexes confirmed."

7. **`/e2e-verify`** — run `--scenario time-pressure-quick-fix` (reuse from G2). Extract. Write `rationalizations.md`. Rewrite SKILL.md:
   - Iron Law candidate: `NO E2E PASS WITHOUT FRESH BROWSER EVIDENCE OF EVERY GOLDEN-PATH STEP`.
   - Body adds explicit step gates (page rendered, console clean, interaction worked, navigation functional, data displayed).
   - Red Flags: "I checked one page, it loaded," "console errors looked unrelated," "the user can verify the rest."
   - Self-Review: 5 items.

8. **`/lg-review`** — run `--scenario time-pressure-quick-fix`. Extract. Write `rationalizations.md`. Rewrite SKILL.md:
   - Iron Law candidate: `NO LG-REVIEW APPROVAL WITHOUT EVERY DEPRECATION CHECK AND EVERY FOOTGUN CHECK`.
   - Body restructures as a checklist — every deprecated pattern from `lg-cheatsheet` §14 must be checked. Every footgun must have a verdict.
   - Red Flags: "agent uses createReactAgent, that's fine for now," "MemorySaver is acceptable in dev," "missing reducer is theoretical."
   - Self-Review: 4 items focused on the deprecation/footgun checklist completion.

### Phase 3: Re-baseline each

9. After rewriting each skill, re-run its scenario WITH the upgraded skill. Confirm compliance. Iterate if loopholes appear.

10. **Cross-skill consistency check.** Open all 5 modified `SKILL.md` files plus the 3 from G6. Confirm:
    - Identical override-preamble line position.
    - Identical Iron-Law block format.
    - Identical sibling-file linking phrase.
    - Identical Self-Review checkbox style.

## Test plan

### Unit
- `bin/test-frontmatter` passes against all 5 modified files.
- Each `rationalizations.md` is well-formed (markdown table with `Excuse | Reality` header).

### E2E
- Re-baseline runs for all 5 skills post-rigorization. Document results.
- For `/security-review`: dispatch a fake auth-touching diff in a Claude Code session. Invoke `/security-review`. Confirm it runs every phase and refuses verdict-skip.

### Manual verification
- Side-by-side compare of all 8 rigid skills (3 from G6 + 5 here). Format consistency confirmed.
- Word-count each. Body <500 words; overflow in siblings.

## Done criteria

- [ ] All 5 SKILL.md files (`security-review`, `incident`, `db-review`, `e2e-verify`, `lg-review`) follow the rigid template.
- [ ] Each has a populated `rationalizations.md` from real baselines.
- [ ] 3 new pressure scenarios committed under `docs/skill-baselines/_scenarios/`.
- [ ] 5 pre-rigorization baselines + 5 post-rigorization baselines in `docs/skill-baselines/`.
- [ ] All 8 rigid skills (G6 + G7) are visually consistent in structure.
- [ ] All 5 modified files are <500 words; overflow in siblings.

## Skills

- `/skill-baseline`
- `/lg-review` (validation pass — invoke it on a real LangGraph file in this repo to confirm the rigorized version still works)

## Notes for the executor

- This is the longest sub-plan in elapsed time, due to baselines + re-baselines × 5 skills. Plan a half-day budget.
- Reuse scenarios where possible (e.g., `/e2e-verify` and `/lg-review` both work with `time-pressure-quick-fix`).
- If a baseline produces almost no rationalizations (the subagent passes the scenario), that's a signal the scenario isn't pressuring enough — escalate (combine pressures) or pick a different scenario.
- `/lg-review` may have rationalizations specific to LangGraph deprecation framing ("this is a v0 codebase, deprecation doesn't apply"). Capture these; they're domain-specific.
