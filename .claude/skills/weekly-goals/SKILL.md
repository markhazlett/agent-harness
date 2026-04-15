---
name: weekly-goals
description: Load and reference the current week's goals. Use proactively to keep work aligned with weekly priorities, flag when tasks drift off-track, and suggest what to work on next.
user-invocable: true
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Weekly Goals

Load the current week's goals and use them to guide work.

## Context

Read `CLAUDE.md` for context on the project owner — their role, working style, and any sprint complexity overrides. This shapes how to prioritize and suggest work.

## Instructions

1. **Find the current week's goals:** Look for `docs/plans/YYYY-wNN/YYYY-wNN-goals.md` matching the current ISO week. If no exact match, find the most recent week folder.

2. **Surface context:** Display the North Star, current priorities (P0 → P1 → P2), "What's NOT This Week" boundaries, and the demo script's complexity check.

3. **Guide work alignment:** When the user asks to work on something, cross-reference it against the week's goals:
   - If it maps to a P0 item, proceed immediately
   - If it maps to a P1/P2 item, note that there may be higher-priority P0 work remaining
   - If it's in "What's NOT This Week", flag it and ask if the user wants to proceed anyway
   - If it doesn't map to any priority, mention this and ask if it should be added

4. **Protect scope.** If the sprint's complexity points are approaching `HARNESS_SPRINT_COMPLEXITY_MAX`, flag it. If the user is going down a rabbit hole that isn't P0, gently call it out.

5. **Suggest next work:** When asked "what should I work on?", reference unchecked P0 items first, then P1, then P2. Bias toward items tagged `[Extend]` over `[Build]` when possible — extending existing work ships faster.

6. **Track progress:** When a goal item is completed during the conversation, suggest updating the checkbox in the goals doc (change `- [ ]` to `- [x]`).

7. **Demo script awareness:** The demo script is the end-to-end walkthrough that proves the week's goals. Use it to:
   - Understand what the finished product looks like before starting work
   - Map each task back to a specific scene in the demo script
   - At the end of the week (or when asked), walk through the demo script to verify everything works
   - Distinguish between `[Exists]`/`[Extend]`/`[Build]` scenes (must work) and `[Narrate]` scenes (vision, not yet built)

8. **Sprint plan awareness.** If a `## Sprint Plan` section exists in the goals doc, reference it when suggesting work. Suggest running `/plan-sprint` if the goals exist but no sprint breakdown has been created yet.

## Steps

1. Scan `docs/plans/` for week folders (e.g., `2026-w13/`)
2. Determine the current ISO week from the current date
3. Read `docs/plans/YYYY-wNN/YYYY-wNN-goals.md` (or most recent week's goals)
4. Present the North Star and priority summary
5. Note the complexity check from the demo script
6. Check for a `## Sprint Plan` section — if missing, suggest running `/plan-sprint`
7. Note any completed items and remaining P0 work
