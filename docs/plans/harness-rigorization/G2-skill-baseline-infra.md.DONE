# G2 — Skill-baseline infrastructure

**Workstream:** harness-rigorization
**Wave:** 1 (no dependencies)
**Effort:** 3 pts
**Type:** Build

## Goal

Build the tooling that makes principle §11 ("Skills are TDD'd") executable in this harness. Two artifacts:

1. `bin/skill-baseline` — shell helper that runs a subagent under a designed pressure scenario WITHOUT a target skill loaded, captures verbatim output, and writes the rationalizations to `docs/skill-baselines/<skill>-<date>.md`.
2. `.claude/skills/skill-baseline/SKILL.md` — process skill that walks a contributor through the RED → GREEN → REFACTOR cycle for skills, using the helper.

Without this, G6 and G7 would write rationalization tables from imagination. With this, they write tables from real observed cheating.

## Dependencies

None. Lands in wave 1 alongside G1.

## Key Decisions (already made)

- Baselines are committed under `docs/skill-baselines/` (forensic value when a skill regresses).
- Each baseline file is `<skill>-<YYYY-MM-DD>.md` with the scenario, model used, verbatim agent output, and the rationalizations extracted from it.
- The pressure-scenario library is committed under `docs/skill-baselines/_scenarios/` so future contributors don't reinvent.
- The helper uses Claude Code's `Agent` tool (specifically the `general-purpose` subagent) — no separate API integration needed.

## File footprint

**Creates:**
- `bin/skill-baseline` — shell script (executable) that takes `--skill <name>` and `--scenario <slug>`, dispatches a subagent, captures output, writes a baseline file.
- `.claude/skills/skill-baseline/SKILL.md` — process skill walking RED/GREEN/REFACTOR for skills.
- `.claude/skills/skill-baseline/rationalizations.md` — sibling file with worked example.
- `docs/skill-baselines/README.md` — explains the folder, what baselines are for, how to read them.
- `docs/skill-baselines/_scenarios/README.md` — index of available pressure scenarios.
- `docs/skill-baselines/_scenarios/time-pressure-quick-fix.md` — first scenario (used to baseline `/tdd`, `/ship`).
- `docs/skill-baselines/_scenarios/sunk-cost-rewrite.md` — second scenario (used to baseline `/tdd`).
- `docs/skill-baselines/_scenarios/authority-deadline.md` — third scenario (used to baseline `/pre-deploy`, `/ship`).
- `docs/skill-baselines/_scenarios/exhaustion-near-end.md` — fourth scenario (used to baseline verification skills).

**Modifies:**
- `.claude/settings.json` — add `bin/skill-baseline` to the permission allowlist.
- `.claude/commands/harness-health.md` — add a check that `bin/skill-baseline` is executable.

**Reads (context only):**
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/writing-skills/SKILL.md` lines 533–560 (RED/GREEN/REFACTOR pattern).
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/writing-skills/testing-skills-with-subagents.md` (full methodology — extract pressure-stacking patterns).
- `bin/learn`, `bin/conductor-status`, `bin/harness-update-check` (existing helper conventions for shell style).

## Implementation steps

### Phase 1: Pressure-scenario library

1. Read `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/writing-skills/testing-skills-with-subagents.md` end-to-end. Extract the four pressure types: time, sunk cost, authority, exhaustion.
2. Write `docs/skill-baselines/_scenarios/time-pressure-quick-fix.md` with the structure:
   - **Scenario name + slug** (e.g., `time-pressure-quick-fix`).
   - **Target skills** (which skills this scenario tests — e.g., `/tdd`, `/ship`).
   - **Pressure type(s)** (time).
   - **Setup prompt for the subagent** — verbatim text given to the subagent. Includes: a fake repo state ("you have 10 min before a demo"), a task ("fix this bug"), and an absent skill (the test deliberately doesn't load `/tdd`).
   - **Expected violations** (what we expect the subagent to do without the skill — write the fix without a test, claim done without running tests, etc.).
   - **Capture instructions** — what to extract from the subagent's response (verbatim rationalizations, decision points).
3. Write the other three scenarios (`sunk-cost-rewrite`, `authority-deadline`, `exhaustion-near-end`) using the same structure.
4. Write `docs/skill-baselines/_scenarios/README.md` indexing all four with a short selection guide ("use time-pressure-quick-fix to test verification skills; use sunk-cost-rewrite to test /tdd specifically").

### Phase 2: `bin/skill-baseline` helper

5. Write the shell script. Required interface:
   ```
   bin/skill-baseline --skill <name> --scenario <slug> [--out <path>]
   ```
   Behavior:
   - Looks up the scenario file at `docs/skill-baselines/_scenarios/<slug>.md`. Errors if missing.
   - Reads the scenario's setup prompt.
   - Invokes Claude Code in headless mode (or prints exact instructions for the contributor to paste, if headless isn't available — see step 7) to dispatch a subagent with that prompt.
   - Captures the subagent's stdout to a temp file.
   - Generates a baseline file at `docs/skill-baselines/<skill>-<YYYY-MM-DD>.md` (or `--out`) containing:
     - Header: skill name, scenario slug, date, model used.
     - Scenario setup verbatim.
     - Subagent transcript verbatim.
     - "Rationalizations extracted" section — initially empty; the contributor fills it in by reading the transcript.
   - Prints "Baseline captured at <path>. Open the file and extract rationalizations under '## Rationalizations extracted'."

6. Pattern after `bin/learn`: use `set -euo pipefail`, source `harness.config.sh`, exit codes 0/1/2 documented at the top.

7. **Headless caveat:** Claude Code does not yet have a stable headless mode that supports subagent dispatch from a shell script. Implementation: the script PREPARES the prompt and prints "Run the following in a Claude Code session: paste this prompt and capture the response. Then run `bin/skill-baseline --finalize <skill> <scenario> --transcript <file>`." This makes the workflow human-in-the-loop. Document this clearly in the helper's `--help` and the skill body.

8. Add `--finalize <skill> <scenario> --transcript <file>` mode that takes a captured transcript and writes the baseline file with the right header. This is what the contributor runs after pasting the subagent response.

### Phase 3: `/skill-baseline` skill

9. Write `.claude/skills/skill-baseline/SKILL.md`. Frontmatter:
   ```yaml
   ---
   name: skill-baseline
   description: Use when authoring or upgrading a rigid skill — runs subagent baselines under pressure to harvest real rationalizations before writing the Rationalization Table.
   user-invocable: true
   tier: flexible
   kind: process
   ---
   ```

10. Body sections:
    - **Why baseline?** One paragraph. Reference principle §11.
    - **The cycle (RED/GREEN/REFACTOR for skills).** Adapt verbatim from `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/writing-skills/SKILL.md` lines 533–560.
    - **Step 1: Pick a scenario.** Point at `docs/skill-baselines/_scenarios/`. Show how to choose.
    - **Step 2: Run the baseline.** `bin/skill-baseline --skill <name> --scenario <slug>`.
    - **Step 3: Extract rationalizations.** Open the baseline file. For each verbatim excuse the subagent made, record it as a row in the "Rationalizations extracted" section. Do NOT paraphrase — exact phrasing is what triggers recognition (principle §3).
    - **Step 4: Write the Rationalization Table sibling file.** Copy each extracted excuse into the skill's `rationalizations.md`. Add a "Reality" column with the counter.
    - **Step 5: Re-baseline.** After the skill is upgraded, re-run the same scenario WITH the skill loaded. Confirm the subagent now complies. If it finds new rationalizations, add them and iterate (REFACTOR).
    - **Pressure stacking.** Reference principle §11 — real failures occur under combined pressure. Document how to combine scenarios (run two in sequence with shared context).

11. Write `.claude/skills/skill-baseline/rationalizations.md` with one worked example: take the `time-pressure-quick-fix` scenario, show what a baseline run might look like, show extracted rationalizations, show the resulting Rationalization Table row.

### Phase 4: Wiring

12. Add `bin/skill-baseline` to `.claude/settings.json` permissions allowlist (so it doesn't prompt every run).
13. Update `.claude/commands/harness-health.md` to verify `bin/skill-baseline` is executable (`test -x bin/skill-baseline`).
14. Write `docs/skill-baselines/README.md` explaining the folder, the scenario library, what's in each baseline file, and when to re-baseline (skill content changes, rationalization seems incomplete, agent regresses).

## Test plan

### Unit
- Run `bin/skill-baseline --help` — confirm the help text describes the two modes and the human-in-the-loop step.
- Run `bin/skill-baseline --skill tdd --scenario time-pressure-quick-fix` — confirm it prints the prompt-to-paste and exits cleanly.
- Run `bin/skill-baseline --finalize tdd time-pressure-quick-fix --transcript /tmp/fake-transcript.md` with a hand-written fake transcript — confirm it writes a baseline file with the correct header and structure.

### E2E
- End-to-end test of the `/skill-baseline` skill: invoke it, follow its instructions, dispatch a real subagent (using the `Agent` tool with subagent_type=general-purpose), capture transcript, finalize. Confirm the baseline file is well-formed.

### Manual verification
- `ls docs/skill-baselines/_scenarios/` — should contain 4 scenario files + README.md.
- `bin/skill-baseline --help` exits 0.
- `/harness-health` reports the helper executable.

## Done criteria

- [ ] `bin/skill-baseline` exists, is executable, has `--help`, supports both `--skill/--scenario` and `--finalize` modes.
- [ ] 4 pressure scenarios exist under `docs/skill-baselines/_scenarios/`.
- [ ] `.claude/skills/skill-baseline/SKILL.md` exists with valid frontmatter (per G1 contract).
- [ ] `.claude/skills/skill-baseline/rationalizations.md` exists with one worked example.
- [ ] `docs/skill-baselines/README.md` documents the folder.
- [ ] `.claude/commands/harness-health.md` verifies `bin/skill-baseline` is executable.
- [ ] Permission allowlist updated.
- [ ] One end-to-end dry run completed: dispatch a subagent against `time-pressure-quick-fix`, capture transcript, finalize a baseline file. Commit the dry-run baseline as `docs/skill-baselines/dry-run-tdd-2026-05-09.md` (or similar) so future contributors have a reference.

## Skills

- `/tdd` (for the script)
- `/skill-baseline` (the new skill, after it exists — used for the dry run)

## Notes for the executor

- The shell script's biggest design constraint is that Claude Code does not have stable headless subagent dispatch. Don't over-engineer around this — the human-in-the-loop pattern (`--finalize` mode) is fine.
- Keep scenarios SHORT and FOCUSED. Each scenario tests ONE pressure. Pressure-stacking is composition, not a single mega-scenario.
- The dry-run baseline file is meant to be a teaching artifact. Make it a clean example contributors can read and immediately understand the workflow.
