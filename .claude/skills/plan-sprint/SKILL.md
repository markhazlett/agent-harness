---
name: plan-sprint
description: Break the current week's goals into concrete, executable projects with full implementation plans. Each project gets a plan written to docs/plans/YYYY-wNN/sprint-plans/ with file footprints, test criteria, and E2E browser verification steps. Use at the start of a week to turn goals into actionable work.
user-invocable: true
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

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
**Complexity budget:** X / 9 pts used ([Build] × 3 + [Extend] × 1)
**Checkpoints:** N independently-verifiable items

| # | Project | Effort | Type | Goal Items | Demo Scenes | Dependencies |
|---|---------|--------|------|------------|-------------|-------------|
| 1 | [name]  | N pts | Extend | P0.1 | Scene 3 | None |
| 2 | [name]  | N pts | Build  | P0.2 | Scene 4 | Project 1 |
```

### Sizing guidelines

- **Target 2-4 projects per week.** Fewer is better. Each should be 1-3 complexity points.
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

**Estimated effort:** N pts (list [Build]/[Extend] items)

**Parallel-safe:** TBD — populated by Phase 3.5

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

## Phase 3.5: Detect parallel execution waves

After all plans are written (Phase 3 complete), compute execution waves using each plan's `Depends on` field AND `File Footprint` section.

**Algorithm:**

1. Build a dependency graph: each plan is a node; edges point from a plan to the plans listed in its `Depends on` field.
2. Topologically sort into candidate waves (plans with no unmet deps are candidate Wave 1, plans whose deps are all in Wave 1 are candidate Wave 2, etc.).
3. Within each candidate wave, compute file-footprint overlap:
   - Union the `Creates` and `Modifies` file paths from each plan.
   - Any pair with overlapping paths cannot run in parallel. Keep the earlier-priority plan in the current wave; move the lower-priority plan to the next wave.
4. For each plan, set `Parallel-safe: yes` iff it shares its wave with at least one other plan; `no` otherwise. Use the `Edit` tool to update the `Parallel-safe:` line in each plan's header.

**Output:**

Print the wave summary to the user:

```
## Parallel Execution Plan

Wave 1 (parallel-safe, no unmet dependencies + no file overlap):
  - P0.1 feat-some-feature   (Parallel-safe: yes)
  - P0.2 feat-another-feature (Parallel-safe: yes)

Wave 2 (after Wave 1 ships):
  - P0.3 feat-builds-on-P0.1 (depends on P0.1)
```

If a wave has only one plan, mark it `Parallel-safe: no` — there's no one to run alongside.

## Phase 4: Update goals document

After all plans are written:

1. Add a `## Sprint Plan` section to the goals document listing all project plans with links, effort estimates, and execution order.
2. Commit all plan files and the updated goals doc together.

## Phase 5: Dispatch Wave 1 to Conductor workspaces (optional)

**Precondition:** Skip this phase entirely if `bin/conductor-dispatch` is not executable in the repo. Check with: `[ -x bin/conductor-dispatch ]`. If absent, note "Conductor dispatch helper not installed — skipping" and stop Phase 5.

After Phase 4 (goals doc updated and committed), offer to dispatch the Wave-1 plans as new Conductor workspaces.

1. Count the Wave 1 plans from Phase 3.5 output — call this N.

Substitute the actual count for N in the prompt below:

```
## Dispatch Wave 1

Open N Conductor workspaces now? Each will boot with its plan file
attached so you can type `/build <plan-path>` to start.

  [y] Open all N
  [s] Show deep links only (I'll open manually)
  [n] Skip
```

**On `y`:** for each Wave-1 plan, run:

```bash
bin/conductor-dispatch docs/plans/YYYY-wNN/sprint-plans/<plan>.md
```

Each invocation opens a new Conductor workspace with the plan attached as a markdown file. Print the URL so the user can see what was dispatched.

**On `s`:** for each Wave-1 plan, run the same command with `--print` and list the URLs.

**On `n`:** skip; the user can dispatch manually later.

**Wave 2+** is NOT auto-dispatched. When Wave 1 plans are complete, dispatch Wave 2 manually: run `bin/conductor-dispatch docs/plans/YYYY-wNN/sprint-plans/<plan>.md` for each Wave 2 plan.

## Naming conventions

Sprint week folders: `docs/plans/YYYY-wNN/`
Goals files: `docs/plans/YYYY-wNN/YYYY-wNN-goals.md`
Single-file plans: `docs/plans/YYYY-wNN/sprint-plans/PX.N-<type>-<slug>.md`

For complex workstreams, use folder-based plans — see the `deep-plan` skill.

## What this skill does NOT do

- Does not execute plans. Execution uses the `build-plan` skill.
- Does not create branches or PRs.
- Does not modify source code.
