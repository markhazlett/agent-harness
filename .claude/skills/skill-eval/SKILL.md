---
name: skill-eval
description: Use when the user says "/skill-eval", "eval the skills", "run skill evals", "check /<skill> still works", or after editing a rigid skill's body — orchestrates the Phase 2 execution layer for `eval.yaml` files.
user-invocable: true
tier: flexible
kind: verification
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Run `/harness-update` to pull it in." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Skill Eval

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

Phase 2 executor for skill `eval.yaml` files. Dispatches a fresh Claude Code subagent per trajectory eval — the subagent loads the target skill, runs the scenario, self-reports its trajectory in a structured `<trajectory-report>` block, and this orchestrator diffs the report against `expected_sequence`, `must_cite`, and `must_recognize`. **The subagent IS Claude Code**, not a headless approximation — that's the fidelity win over a Python-based runner.

This skill is FLEXIBLE — adapts to which skills are in scope. Static schema checks remain owned by `bin/skill-eval --validate`. Full spec: `.claude/docs/skill-eval-spec.md`.

## When to run

- After editing a rigid skill's body, `rationalizations.md`, or `eval.yaml`.
- After a Claude Code or model version bump (suspected drift — see `future-monitoring.md`).
- Before merging a PR that touches `.claude/skills/`.
- On demand via `/harness-health` (quick mode = first trajectory per skill).

## Inputs

```
/skill-eval                       # all skills, first trajectory each (quick)
/skill-eval <skill>               # all trajectories for one skill
/skill-eval <skill> <eval-id>     # one specific trajectory
/skill-eval --report              # aggregate all skills, all trajectories
```

## The cycle

1. **Validate first.** Run `bin/skill-eval --validate`. Stop if it fails.
2. **Load the eval.** Read `.claude/skills/<skill>/eval.yaml`. Select trajectory_evals in scope.
3. **Load the scenario.** Open `<eval>.scenario` (a `docs/skill-baselines/_scenarios/*.md` file). Extract the "Setup prompt (paste verbatim to subagent)" section.
4. **Compose the dispatch prompt** using `subagent-prompt.md` (sibling template). Key requirement: the subagent must end its response with a `<trajectory-report>` JSON block listing every tool call it made. If `decision_evals[]` is non-empty, inject the "## Decision points" block (template in `subagent-prompt.md`) carrying only `id` + `given` — never the expected/forbidden choices.
5. **Dispatch** via the `Agent` tool, `subagent_type: general-purpose`, in a fresh context. Capture the full response.
6. **Parse the trajectory-report.** If missing or unparseable, FAIL immediately with a diagnostic.
7. **Assert** per `assertion-rules.md`: each expected_sequence step has a matching captured action in order; for steps with `expect_exit`, the matched Bash action's `result.exit_code` matches; `forbidden_actions` did not appear (or appeared only after their `before:` anchor); `decisions[]` answers match `decision_evals[].expected_choice` and avoid `forbidden_choices`; `must_cite` strings appear in free-text; `must_recognize` strings have a 3-word-window match. If `output_evals[]` is non-empty, after the dispatch glob the working tree against `artifact_path_pattern` and grade each matched file against `must_contain_sections` / `must_not_contain` / `must_match_regex`.
7a. **(Phase 4) Judge fuzzy matches.** For each "missing expected step" FAIL from Step 7 ONLY, dispatch the judge via `Agent` (subagent_type: general-purpose, prompt from `judge-prompt.md`). Verdict `equivalent` → PASS-with-judge-note; `not_equivalent` → original FAIL stands; `ambiguous` → FAIL-with-warning. Cap: 5 dispatches per run; `SKILL_EVAL_JUDGE=off` disables. Full rules + scope (judge does NOT see decisions/must_cite/output_evals) in `assertion-rules.md`. Touching `judge-prompt.md` requires running `anti-evals/judge-rubberstamp-canary.md` first.
8. **Report PASS/FAIL** with itemized diffs. One line per missing expected step (or PASS-with-judge-note) / wrong exit code / forbidden action that fired / wrong decision / missing section / forbidden substring / missing regex / missing citation / unrecognized rationalization.

References: `subagent-prompt.md` (dispatch template), `judge-prompt.md` (Phase 4 judge), `assertion-rules.md` (full diff rules incl. Phase 4), `anti-evals/` (rubberstamp canary), `future-monitoring.md` (Claude Code drift).

## Red Flags — STOP and report

- Subagent returned no `<trajectory-report>` block, or the block doesn't parse as JSON. FAIL — do not retry silently.
- Captured `actions` list is empty and the scenario clearly required tool use. The subagent refused or stalled; FAIL with verbatim reply.
- Subagent reply contains a refusal. Treat as FAIL and surface verbatim.
- More than 15 turns of tool use per subagent. Kill the dispatch, FAIL with "turn limit exceeded".
- Multiple trajectory evals in one dispatch. **Always one trajectory per Agent dispatch** — context carryover ruins fidelity.
- You're tempted to mutate `eval.yaml` to make a failing eval pass. Eval drift is a separate fix; surface to user instead.
- **(Phase 4) Judge rubberstamping** — judge returned `equivalent` for a captured action that's clearly wrong. Anti-eval canary regressed; surface the `because` and propose a `judge-prompt.md` fix before re-running. Do NOT accept the PASS-with-judge-note.
- **(Phase 4) Judge cap exceeded** (> 5 missing-step failures in one run). Broken trajectory or stale eval.yaml — surface the unjudged failures; do NOT silently raise the cap.

**All of these mean: report FAIL and stop. The user reviews.**

## Self-Review Checklist

- [ ] `bin/skill-eval --validate` passed before any trajectory was attempted.
- [ ] Every trajectory_eval in scope was attempted (no silent skips).
- [ ] Each subagent dispatch returned a parseable `<trajectory-report>`.
- [ ] FAIL reports cite the exact eval id + trajectory step that didn't match.
- [ ] You did NOT edit `eval.yaml` to make a failing eval pass.
- [ ] Final report distinguishes PASS / FAIL / SKIP per trajectory.
- [ ] If Phase 4 judge fired: PASS-with-judge-note entries name `matched_captured_index` + verdict `because`. Judge cap was not exceeded. Anti-eval canary was run if `judge-prompt.md` was touched in this PR.

## What this skill does NOT cover

- **Static schema validation** → `bin/skill-eval --validate` (run that first).
- **Invocation evals** — schema-validated; execution still deferred (cross-skill dispatch is its own design problem).
- **Headless CI adapter** — deferred pending Claude Code SDK headless mode (see `follow-ups.md` § F).
- **Authoring new evals** → `/write-skill` step 5 + `/skill-baseline` step 7.

## Terminal State

Terminal state is **a PASS/FAIL report per trajectory in scope, with itemized diffs on FAIL**. Do NOT retry silently. Do NOT invoke `/ship`. Do NOT auto-edit `eval.yaml`. The user reviews the report and decides: fix the skill, fix the eval, or accept the regression.
