---
name: plan-sprint
description: Break the current week's goals into concrete, executable projects with full implementation plans. Each project gets a plan written to docs/plans/YYYY-wNN/sprint-plans/ with file footprints, test criteria, and E2E browser verification steps. Use at the start of a week to turn goals into actionable work.
user-invocable: true
---

# Sprint Planner

Break the current week's goals into discrete projects, design full implementation plans for each, and write them to the week's sprint-plans folder.

## Directory Structure

```
docs/plans/
  YYYY-wNN/                          # One folder per sprint week
    YYYY-wNN-goals.md                # Goals file + demo script
    sprint-plans/                    # Implementation plans for this sprint
      P0.1-feat-some-feature.md
      P0.2-feat-another-feature.md
```

## Phase 1: Gather context

Before proposing any projects:

1. **Read the goals.** Load `docs/plans/YYYY-wNN/YYYY-wNN-goals.md` for the current week. Read the North Star, priorities (P0/P1/P2), demo script, and "What Already Works."

2. **Audit the codebase.** For each priority item, explore the relevant source files to understand:
   - What already exists and works
   - What needs to be extended
   - What needs to be built from scratch
   - What files would be touched

3. **Read existing plans.** Scan `docs/plans/YYYY-wNN/sprint-plans/` for any plans already created this week — don't duplicate work that's already planned.

4. **Inventory the demo script.** Map each demo scene to the work required. Scenes tagged `[Exists]` need no project. Scenes tagged `[Extend]` or `[Build]` each become a candidate project.

## Phase 2: Propose the breakdown

Present a summary table of proposed projects:

```markdown
## Proposed Sprint Breakdown

**Goals:** docs/plans/YYYY-wNN/YYYY-wNN-goals.md
**Available capacity:** ~X hours
**Total estimated effort:** ~Y hours

| # | Project | Effort | Type | Goal Items | Demo Scenes | Dependencies |
|---|---------|--------|------|------------|-------------|-------------|
| 1 | [name]  | ~N hrs | Extend | P0.1 | Scene 3 | None |
| 2 | [name]  | ~N hrs | Build  | P0.2 | Scene 4 | Project 1 |
```

### Sizing guidelines

- **Target 2-4 projects per week.** Fewer is better. Each should be 3-5 hours.
- **One project = one coherent deliverable.**
- **Each project must map to a demo scene or priority item.**
- **Prefer [Extend] over [Build].** Extending existing code ships faster and has fewer unknowns.
- **Flag unknowns.** If a project has significant uncertainty, estimate high and note the risk.

**Wait for the user to approve the breakdown before proceeding to Phase 3.**

## Phase 3: Create full plans

For each approved project:

1. **Enter plan mode** — call `EnterPlanMode`
2. **Explore the codebase** — use Glob, Grep, Read to understand relevant files and patterns
3. **Design the plan** — write the full implementation plan following the template below
4. **Exit plan mode** — call `ExitPlanMode` to present the plan for user review
5. **On approval** — write the finalized plan to `docs/plans/YYYY-wNN/sprint-plans/PX.N-<slug>.md`

### Plan template

```markdown
# [Project Title]

**Goal:** docs/plans/YYYY-wNN/YYYY-wNN-goals.md

**Priority items:** P0.1, P0.2 (reference specific items from goals)

**Demo scenes:** Scene N (which demo scenes this enables)

**Depends on:** None | docs/plans/YYYY-wNN/sprint-plans/PX.N-<other-plan>.md

**Estimated effort:** ~N hours

## Context

Why this work matters. What exists today. What's missing. 2-3 paragraphs max.

## Key Decisions

Numbered list of architectural or UX decisions made during planning.
Each decision should explain the choice and the alternative considered.

## File Footprint

### Creates
- `path/to/new/file.ts` — one-line description of purpose

### Modifies
- `path/to/existing/file.ts` — what changes and why

### Reads (no modifications)
- `path/to/dependency.ts` — why this file is relevant context

## Implementation

### Step 1: [Title]

**File:** `path/to/file.ts`

Description of what to do, with code scaffolding where it reduces ambiguity.

### Step 2: [Title]
...

## Test Plan

### Unit Tests

- `path/to/__tests__/file.test.ts` — what to test, key scenarios, edge cases

### E2E Browser Verification

Step-by-step browser walkthrough to verify the feature works end-to-end.

1. Navigate to [URL]
2. [Action] — expected result
3. Verify: [what to check in the UI]

## Done Criteria

- [ ] Implementation complete (all steps above)
- [ ] Unit tests passing
- [ ] E2E browser verification passing
- [ ] No lint/type errors
- [ ] Committed on feature branch with conventional commit
```

## Phase 4: Update goals document

After all plans are written:

1. Add a `## Sprint Plan` section to the goals document listing all project plans with links, effort estimates, and execution order.
2. Commit all plan files and the updated goals doc together.

## Naming conventions

Sprint week folders: `docs/plans/YYYY-wNN/`
Goals files: `docs/plans/YYYY-wNN/YYYY-wNN-goals.md`
Single-file plans: `docs/plans/YYYY-wNN/sprint-plans/PX.N-<type>-<slug>.md`

For complex workstreams, use folder-based plans — see the `deep-plan` skill.

## What this skill does NOT do

- Does not execute plans. Execution uses the `build-plan` skill.
- Does not create branches or PRs.
- Does not modify source code.
