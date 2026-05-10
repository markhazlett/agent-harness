---
name: ad-hoc-plan
description: Use when the user has a one-off task that slots into the current sprint and needs a quick written plan — lighter than /plan-sprint. Reads existing plans for context, uses plan mode, writes a focused plan file.
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

# Ad-Hoc Plan

Create a focused implementation plan for a single task that fits into the current sprint. This is the lightweight alternative to `/plan-sprint` — no goals analysis, no demo script mapping, no breakdown table. Just a quick plan that understands the sprint context.

<input_document> #$ARGUMENTS </input_document>

## When to use this vs /plan-sprint

| Use `/ad-hoc-plan` | Use `/plan-sprint` |
|---|---|
| Single task or small feature | Full week's goals breakdown |
| Found something mid-sprint | Start of a new week |
| ≤3 complexity pts (1-2 `[Extend]` items) | Multi-item sprint |
| "I noticed we need X" | "Let's plan the whole sprint" |

## Workflow

### 1. Gather sprint context (fast)

Read the existing sprint plans to understand the current landscape:

```
docs/plans/YYYY-wNN/sprint-plans/
```

Scan for:
- What's already planned and done (`.DONE.md` files)
- What's in progress
- What dependencies exist
- Where this new task fits in the priority order

Also glance at the goals file to understand the North Star — but don't do the full goals analysis that `/plan-sprint` does.

### 2. Enter plan mode

Call `EnterPlanMode` to design the implementation. In plan mode:

- Explore the relevant codebase (Glob, Grep, Read)
- Understand existing patterns and what already exists
- Design the implementation approach
- Write the plan to the plan file

### 3. Present for review

Call `ExitPlanMode` to present the plan for user approval.

### 4. Write the plan file

On approval, write the plan to `docs/plans/YYYY-wNN/sprint-plans/` using:

```
PX.N-<type>-<descriptive-slug>.md
```

**Priority numbering:** Look at existing plans and pick the next available number. Ad-hoc tasks are typically P1 or P2 unless the user specifies urgency.

### 5. Commit

Commit the plan file on the current branch (or create a docs branch if on main).

## Plan template

Keep it concise. Ad-hoc plans should be scannable in under 2 minutes.

```markdown
# [Task Title]

**Goal:** docs/plans/YYYY-wNN/YYYY-wNN-goals.md

**Priority items:** PX.N (ad-hoc — [brief reason])

**Demo scenes:** [which scene this enables, or "N/A"]

**Depends on:** [other plan or "None"]

**Estimated effort:** N pts (list [Build]/[Extend] items)

## Context

1-2 paragraphs max. What prompted this, why it matters now.

## Key Decisions

Only include if there are genuine choices to make. Skip for straightforward tasks.

## File Footprint

### Creates
- ...

### Modifies
- ...

### Reads (no modifications)
- ...

## Implementation

### Step 1: [Title]
**File:** `path/to/file`
[Concise description]

### Step 2: [Title]
...

## Test Plan

### Unit Tests
- Key scenarios only

### E2E Browser Verification
- Quick walkthrough steps

## Done Criteria

- [ ] [Key deliverables]
- [ ] Unit tests passing
- [ ] E2E browser verification passing
- [ ] No lint/type errors
- [ ] Committed on feature branch
```

## Guidelines

- **Keep it short.** An ad-hoc plan should be 50-100 lines, not 200+. If it's growing beyond that, use `/plan-sprint`.
- **Context from existing plans.** Reference what's already planned — this task might overlap or depend on something.
- **Don't over-plan.** If the task is 0 complexity points (a single `[Exists]` task), you probably don't need a plan file at all.
- **Priority ordering.** Use the next available slot at the right priority level.
