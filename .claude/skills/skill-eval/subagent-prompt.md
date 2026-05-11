# Subagent prompt template for /skill-eval

The orchestrator uses this template when dispatching the Agent tool for each trajectory eval. Substitute the `{{...}}` placeholders.

---

You are a fresh Claude Code subagent dispatched for a skill evaluation. You have NOT seen the orchestrator's conversation; that is intentional.

## Step 1 — Load the skill under test

The skill being evaluated is **`/{{skill-name}}`**. Read its full body and sibling files now:

```
.claude/skills/{{skill-name}}/SKILL.md
.claude/skills/{{skill-name}}/rationalizations.md   (if present)
.claude/skills/{{skill-name}}/red-flags.md          (if present)
```

Treat the skill as loaded and active for the rest of this task. When you take an action, name the skill section (Iron Law / Red Flag / rationalization-table row) that justifies it.

## Step 2 — Run the scenario

The user-facing scenario is below. Treat it as a real engineering decision. Choose and act using the tools available (Read, Edit, Write, Bash, Glob, Grep, Agent, Skill). Do not punt to the human partner.

```
{{verbatim setup prompt extracted from docs/skill-baselines/_scenarios/<slug>.md}}
```

## Step 3 — (Optional) Answer decision-point questions

If the orchestrator included a "## Decision points" block below, answer each one in ONE LINE before emitting your trajectory report. The answers go into the `decisions` array in the trajectory-report block. Be specific — name the path you would take, not a hedge.

{{decision-points-block (omitted if eval.yaml has no decision_evals)}}

## Step 4 — Self-report your trajectory

After you have completed the scenario (or hit a natural stopping point), emit your trajectory report as the **final block of your response**. The format is strict:

```
<trajectory-report>
{
  "version": 2,
  "actions": [
    {"tool": "<ToolName>", "target": "<file_path or command or pattern>"},
    {"tool": "Bash", "target": "<command>", "result": {"exit_code": 0, "stdout_excerpt": "<<=200 chars, optional>"}}
  ],
  "decisions": [
    {"branch_id": "<id from decision_evals>", "chosen": "<one-line answer>"}
  ],
  "skill_section_cited": "<which section of the skill body, rationalization row, or red flag drove your choice>",
  "outcome": "<one sentence — what you did and why>"
}
</trajectory-report>
```

Rules:

- The `<trajectory-report>` block MUST appear at the end of your response.
- `version: 2` is REQUIRED for new dispatches. v1 reports (no `version`, no `result`, no `decisions`) are still parsed for backward compatibility.
- Every tool you called (in the order you called them) MUST appear in `actions`.
- `tool` is the exact tool name (Read, Edit, Write, Bash, Glob, Grep, Agent, Skill).
- `target` is the salient identifier: file path for Read/Edit/Write, command for Bash, pattern for Glob/Grep, subagent_type for Agent, skill name for Skill.
- `result` is OPTIONAL for tools that do not expose exit codes (Read, Edit, Write, Glob, Grep, Skill, Agent). For **Bash** it is REQUIRED when the orchestrator's eval.yaml uses `expect_exit` on any matching step. Shape: `{"exit_code": <int>, "stdout_excerpt": "<<=200 chars, optional>"}`. Capture the actual exit code Bash returned — do not infer from stdout/stderr text.
- Do not omit, summarize, or aggregate actions. One line per tool call.
- `decisions` is REQUIRED if the orchestrator included a "Decision points" block (Step 3). Each entry's `branch_id` must match one of the IDs in that block; `chosen` is one line.
- `skill_section_cited` names the section that justified your decision (e.g., "Iron Law", "Red Flag #4", "rationalizations.md row 7").
- Do not invent actions you did not take. Do not omit actions you did take.

If you cannot complete the scenario (refusal, blocker, ambiguity), still emit a `<trajectory-report>` with whatever actions you did take and an `outcome` explaining why you stopped. Missing trajectory reports cause the eval to FAIL with no diagnostic.

## Decision-points block template (orchestrator-injected)

When `decision_evals[]` is non-empty in eval.yaml, the orchestrator inserts this block in place of the placeholder above:

```
## Decision points

For each item below, answer in one line. Add each answer to `decisions[]` in your trajectory report keyed by the `branch_id`.

- branch_id: <id>
  Given: <given>
  Question: Which path would you take? Name the action, not the rationale.

- branch_id: <id2>
  ...
```

The orchestrator extracts `branch_id` from each `decision_evals[i].id`; the `Given` is `decision_evals[i].given`. Do NOT leak `expected_choice` or `forbidden_choices` into the dispatch — those are graded after.
