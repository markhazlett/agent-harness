# Future monitoring — keeping evals aligned with Claude Code

The Claude Code harness is a moving target. Its system prompt, tool palette, skill-loading semantics, and `<system-reminder>` injection all evolve. When they change materially, the `eval.yaml` files written against the old behavior may surface false positives or false negatives. This file is the playbook for catching that drift.

## What to watch

Material changes worth tracking:

1. **Tool palette additions/renames.** `eval.yaml` `action:` values map to specific tool names (Read, Edit, Write, Bash, Glob, Grep, Agent, Skill). When Claude Code adds a new tool or renames one (e.g., the existing `Bash` becoming `Shell`), every eval that asserts on the old name silently fails to match. The `assertion-rules.md` mapping table needs updating.
2. **Skill tool content-injection behavior.** Skills get loaded via the Skill tool, which injects content into the model's context. Changes to *how* that injection works (timing, scope, what gets included) affect whether the subagent under test sees the skill body when it's supposed to. If the injection becomes lazier or stricter, eval scenarios may need adjusted prompts.
3. **`<system-reminder>` semantics.** The harness re-injects critical context (skill list, deferred tools, mode flags) per turn. If the format or frequency changes, the model's awareness of which skill is loaded shifts — and so does its trajectory.
4. **Subagent dispatch semantics.** The Agent tool is the substrate of `/skill-eval`. Changes to `subagent_type`, context isolation, or return-value shape directly affect this skill's reliability. A change here is a critical priority.
5. **Default model.** When Claude Code's default model changes (Opus 4.6 → 4.7, etc.), the same scenario may produce different trajectories. Not always a regression — but worth re-running evals to characterize the new behavior.
6. **CLAUDE.md / project-instruction precedence.** If the system prompt re-orders how project instructions, skills, and defaults compose, the user-supremacy invariant (`§ Instruction precedence`) shifts. Every rigid skill's override note depends on this.

## How to track

When you (or another agent) notice a Claude Code change that touches any of the above:

1. **Capture the change** as a learning at `docs/learnings/claude-code-<YYYY-MM-DD>-<change-slug>.md` with the `Rule / Why / How to apply` body. The rule: "Claude Code <changed X>; the harness now needs <Y>." The why: "Without this update, <specific eval/skill> would drift." The how-to-apply: "Re-run `/skill-eval --report`. For any skill that drifted, run `/skill-baseline` against the affected scenarios and update the eval.yaml expected_sequence."
2. **Run `/skill-eval --report`** under the new Claude Code version. The aggregate FAIL list is the drift surface — those are the skills whose evals no longer match production behavior.
3. **For each drifted skill, decide:** (a) the skill regressed and needs fixing (the harness's discipline is now wrong), or (b) the eval drifted and needs updating (Claude Code's behavior changed in a way the skill should accept). Never silently mutate `eval.yaml` to make a failing eval pass without (a) confirming with the user and (b) re-running `/skill-baseline` to refresh the trajectory.
4. **Update `assertion-rules.md`** if a tool was renamed or added — extend the mapping table.
5. **Bump VERSION patch** when the harness adapts to a Claude Code change. The commit message names the upstream change ("adapt to Claude Code 2.X tool palette: rename Bash→Shell in assertion mapping").

## When to run unprompted

The user's stated plan: watch Claude Code release notes and update the harness in response. Concrete triggers for proactive runs:

- **Claude Code release notice** mentions tool changes, skill changes, system-prompt changes, or new injection types.
- **A model major-version bump** (e.g., Claude 4.7 → Claude 5.0).
- **An evaluation surprise** during normal use — a subagent does something the skill body forbids without rationalizing, suggesting the discipline isn't transmitting. Worth a `/skill-eval` for the affected skill.

## What this is NOT

This is not a substitute for the per-skill `/skill-baseline` rationalization-table maintenance. Baselines harvest *new* rationalizations the model invents under pressure. Future-monitoring catches *infrastructure* drift (tool names, prompt structure). The two layers compound — baselines keep the table relevant, evals keep the assertions executable.
