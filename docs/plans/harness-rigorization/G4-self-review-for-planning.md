# G4 — Mechanical Self-Review for `/plan-sprint` and `/deep-plan`

**Workstream:** harness-rigorization
**Wave:** 1 (no dependencies)
**Effort:** 1 pt
**Type:** Extend

## Goal

Add a checklist-based Self-Review phase to `/plan-sprint` and `/deep-plan`, addressing principle §31 (self-review must be mechanical, not vibe-based).

Today, both skills produce plans and stop. There's no built-in pass that catches the specific failure modes of the agent that wrote the plan — placeholders left in, scope creep, type/name inconsistency across tasks, ambiguous phrasing.

## Dependencies

None.

## Key Decisions (already made)

- Self-Review is a phase added to the SKILL.md body, not a separate skill. It runs inline before the user-review gate.
- The checklist is mechanical — every item is verifiable by re-reading the produced doc. No "look it over."
- Specific failure modes covered: placeholder scan, internal consistency, scope check, type/name consistency, ambiguity.

## File footprint

**Creates:**
- None.

**Modifies:**
- `.claude/skills/plan-sprint/SKILL.md` — add "Phase 4: Self-Review" before the existing user-review handoff.
- `.claude/skills/deep-plan/SKILL.md` — add a "Phase 6.5: Self-Review" before "Phase 7: Integrate with Sprint."

**Reads (context only):**
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/test-driven-development/SKILL.md` lines 327–340 (Verification Checklist template).
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/writing-plans/SKILL.md` if available — extract any "spec self-review" pattern.

## Implementation steps

1. **Read the superpowers Self-Review checklist.** Path: `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/test-driven-development/SKILL.md` lines 327–340. Note the structure: "Before marking work complete: [ ] item, [ ] item… Can't check all boxes? Start over."

2. **Draft the Self-Review checklist for plans.** Six items:
   - **Placeholder scan** — search the doc for "TBD", "implement later", "appropriate", "as needed", "etc.", `XXX`, `???`. Every match must either be removed or replaced with concrete content. Cite the section.
   - **File footprint completeness** — every Implementation Step that creates/modifies a file must have that file listed in the File Footprint section. Diff the two; report mismatches.
   - **Type/name consistency** — extract every type name, function name, and config key referenced in the doc. Confirm they're spelled and cased identically across sections (e.g., `userId` vs `user_id` vs `UserID` mixed in one plan = inconsistency).
   - **Scope check** — re-read the goal statement at the top. List every step. For each step, can you state in one sentence why it serves the goal? If not, the step is scope creep — flag it.
   - **Ambiguity check** — for each step, is the action unambiguous? "Set up logging" is ambiguous. "Add `pino` with daily rotation, level=info, output to `logs/app.log`" is not. Flag every ambiguous step.
   - **Done criteria reachability** — every item in the Done Criteria checklist must be testable by an Implementation Step. If a Done item has no corresponding Step, either add the Step or drop the Done item.

3. **Add "Phase 4: Self-Review" to `/plan-sprint/SKILL.md`.** Insert after the current "Phase 3.5: Parallelization" (or wherever the doc-writing finishes) and before the user-review handoff. Content:
   - One-paragraph intro: "Before handing the plan to the user, run this checklist against the produced doc(s). Every item must pass. If any fails, fix the doc and re-run."
   - The 6 checklist items (verbatim from step 2 above).
   - Closing line: "Cannot check all boxes? Edit the plan and re-run Phase 4. Do not hand it to the user with known gaps."

4. **Add "Phase 6.5: Self-Review" to `/deep-plan/SKILL.md`.** Same checklist, applied to BOTH the entry-point doc (`00-architecture-analysis.md`) AND each sub-plan. Insert between Phase 6 ("Write the Plan Folder") and Phase 7 ("Integrate with Sprint"). Note: for deep-plan, the scope-check is across the full workstream — does every sub-plan trace back to the architecture analysis? Are there sub-plans that don't serve the workstream goal?

5. **Write a small validator script `bin/test-plan-self-review`** that takes a plan file path and runs the placeholder scan automatically (`grep -E '(TBD|XXX|\\?\\?\\?|implement later|as needed|appropriate)'`). Exit 1 if matches found, 0 otherwise. Used by `/harness-health` if a sprint folder exists.

## Test plan

### Unit
- `bin/test-plan-self-review docs/plans/harness-rigorization/00-architecture-analysis.md` — exit 0 (no placeholders).
- `bin/test-plan-self-review` against a hand-crafted file containing "TBD" — exit 1.

### E2E
- Run `/plan-sprint` on a fake goals doc, observe that Phase 4 fires, that the checklist is followed item-by-item, and that the user-review handoff doesn't happen until all items pass.
- Run `/deep-plan` on a small fake feature, observe Phase 6.5 fires across the entry-point + each sub-plan.

### Manual verification
- Read modified `/plan-sprint/SKILL.md`. Confirm Phase 4 is present, has 6 items, and explicitly forbids handoff with unchecked items.
- Read modified `/deep-plan/SKILL.md`. Confirm Phase 6.5 applies the checklist to BOTH the entry doc and sub-plans.

## Done criteria

- [ ] `/plan-sprint/SKILL.md` has a "Phase 4: Self-Review" section with the 6-item mechanical checklist.
- [ ] `/deep-plan/SKILL.md` has a "Phase 6.5: Self-Review" section that applies to entry doc + sub-plans.
- [ ] Both phases explicitly forbid user-handoff while items are unchecked.
- [ ] `bin/test-plan-self-review` exists, exit codes documented.
- [ ] `/harness-health` invokes the validator if `docs/plans/` is non-empty.

## Skills

- `/tdd` (for the validator script)
- `/plan-sprint` (validation pass)
- `/deep-plan` (validation pass)

## Notes for the executor

- Resist adding a 7th item. Six is enough; bloat hurts.
- The validator script does only the placeholder scan. The other 5 items require human/agent judgment and stay manual.
- Item phrasing matters. Each item should be a single check the agent can mechanically perform — not a vague directive.
