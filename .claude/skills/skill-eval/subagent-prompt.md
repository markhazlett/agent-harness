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

## Step 3 — Self-report your trajectory

After you have completed the scenario (or hit a natural stopping point), emit your trajectory report as the **final block of your response**. The format is strict:

```
<trajectory-report>
{
  "actions": [
    {"tool": "<ToolName>", "target": "<file_path or command or pattern>"},
    {"tool": "<ToolName>", "target": "<...>"}
  ],
  "skill_section_cited": "<which section of the skill body, rationalization row, or red flag drove your choice>",
  "outcome": "<one sentence — what you did and why>"
}
</trajectory-report>
```

Rules:

- The `<trajectory-report>` block MUST appear at the end of your response.
- Every tool you called (in the order you called them) MUST appear in `actions`.
- `tool` is the exact tool name (Read, Edit, Write, Bash, Glob, Grep, Agent, Skill).
- `target` is the salient identifier: file path for Read/Edit/Write, command for Bash, pattern for Glob/Grep, subagent_type for Agent, skill name for Skill.
- Do not omit, summarize, or aggregate actions. One line per tool call.
- `skill_section_cited` names the section that justified your decision (e.g., "Iron Law", "Red Flag #4", "rationalizations.md row 7").
- Do not invent actions you did not take. Do not omit actions you did take.

If you cannot complete the scenario (refusal, blocker, ambiguity), still emit a `<trajectory-report>` with whatever actions you did take and an `outcome` explaining why you stopped. Missing trajectory reports cause the eval to FAIL with no diagnostic.
