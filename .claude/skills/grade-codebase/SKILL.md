---
name: grade-codebase
description: Use when the user says "/grade-codebase", "grade this codebase", "how agent-friendly is this repo", "score the codebase", or wants a longitudinal measure of how well an LLM coding agent can work in this codebase.
user-invocable: true
tier: flexible
kind: process
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Run `/harness-update` to pull it in." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Grade Codebase

> _Override: see `CLAUDE.md` § Instruction precedence. User is principal; this skill is advisory._

Score this repo against the agent-friendliness rubric and produce a dated report. Re-run monthly to track drift; other agents read the report for cleanup tasks.

<input_document> #$ARGUMENTS </input_document>

## Output

Report at `docs/agent-grade/<YYYY-MM-DD>.md` + copy at `latest.md`. Modes:

- **quick** (default) — overall + per-dimension grades + top 3 issues, ~1 page.
- **full** — quick **plus** prioritised backlog and diff vs prior report.

`$ARGUMENTS` empty or `quick` → quick; `full` → full; anything else → ask.

## Rubric

**Read `.claude/docs/agent-friendliness-rubric.md` first.** It defines dimensions, weights, signals, grading scale, anti-patterns. This skill executes it; doesn't duplicate it. Missing rubric → stop and tell the user.

## Workflow

### 1. Confirm mode and prior report

Parse `$ARGUMENTS`. `ls docs/agent-grade/` for the most recent prior report (for the diff in full mode).

### 2. Discover the toolchain — **before any signals run**

**REQUIRED SUB-FILE:** Read `discovery.md`. Detect forge, CI host, task runner, branch-protection source, containerisation, lockfiles, and secret scanners *from this repo's files* — do not assume GitHub Actions, npm, or any specific stack. Emit a "Discovery preamble" block that the report renders verbatim.

If a category comes back empty (e.g. no CI host detected), that is itself a finding for the relevant dimension — record `none detected`, never substitute a default. If the stack is outside web/services (embedded, ML-training, IaC-only, game engine), flag it up front per rubric §8.

### 3. Run mechanical signals against the discovered toolchain

For each rubric dimension, run measurement commands **against the toolchain from step 2, not against hardcoded paths**:

- D2's "one-command test" → the discovered runner's test target.
- D4's "CI runs the agent's local commands" → the discovered CI config (whichever forge/host was found).
- D7's "branch protection" → the forge-appropriate CLI (`gh`/`glab`/`tea`); "not measured" if unavailable — never penalise unmeasurability.

Batch independent calls into one tool message. Capture exit codes and wall times. No destructive commands; no dependency installs without user OK.

### 4. Apply judgment signals

Sample real files; cite the path. Judgment caps at 50% of a dimension's score (rubric §5).

### 5. Anti-patterns

If any rubric §6 anti-pattern fires, the overall grade caps at C. Surface which and where.

### 6. Score and roll up

Per-dimension letter from rubric §4. Letters → midpoints (A=95, B=82, C=67, D=52, F=30), weighted-average, map back. Apply the C-cap if triggered.

### 7. Write the per-dimension narrative

**REQUIRED SUB-FILE:** Read `narrative-spec.md`. Four moves per dimension: translate the rubric's Plain-English case into this repo, cite specific evidence, quantify cost honestly, acknowledge the most likely objection. 100–200 words per dimension.

### 8. Generate the backlog (full mode only)

**REQUIRED SUB-FILE:** Read `backlog-spec.md`. Same persuasion shape, ordered by `weight × gap × inverse-effort`. Top 3 surfaced as "highest-leverage". Backlog items must reference the discovered toolchain, not the rubric's example tools.

### 9. Write the report

Use `report-template.md`. Include header (date, commit SHA, branch, mode), the Discovery preamble from step 2, the overall grade and verdict, per-dimension table + narrative, anti-pattern flags. Full mode also includes the backlog and the diff vs prior report.

Write to `docs/agent-grade/<YYYY-MM-DD>.md`, then copy to `latest.md`. Create the directory if missing.

### 10. Report back

One paragraph: overall grade, the dimension that moved most vs prior, the single highest-leverage fix. Point at the report file. Don't commit — the user decides.

## Honesty rules

- Unmeasurable → "not measured", never a defaulted score.
- The discovery preamble drives grading; `none detected` surfaces in the report, not an assumed substitute.
- Judgment scores cite the sampled file.
- Narrative numbers come from this run, or the narrative names the failure mode instead.
- Rubric contradictions go in the methodology footer, not silent fudges.

## Not in scope

No code changes, no commits, no network calls beyond forge CLIs against the discovered remote, no grading of other repos. Grades the substrate, not the agent (rubric §8).
