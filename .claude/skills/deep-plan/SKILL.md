---
name: deep-plan
description: Plan complex features or workstreams that need architecture analysis, sub-plan decomposition, and security review. Produces folder-based plans with an entry point document plus individually executable sub-plans. Use when the user describes work that spans multiple files/systems, involves architectural decisions, would exceed 9 complexity pts or span multiple sprints, or when they say "deep plan", "plan this feature", "let's plan [complex thing]".
user-invocable: true
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Deep Plan

Plan a complex feature or workstream by doing thorough architecture analysis, identifying risks and one-way doors, then decomposing into executable sub-plans with a parallelization strategy.

This produces a folder of plans that `build-plan` can execute individually.

<input_document> #$ARGUMENTS </input_document>

## When to use this vs other planning skills

| Skill | Scope | Output | Time |
|-------|-------|--------|------|
| `/ad-hoc-plan` | Quick fix, small feature | Single `.md` file | ≤3 complexity pts |
| **`/deep-plan`** | Complex feature, architectural change | Folder: `00-*.md` + sub-plans | >9 pts or multi-sprint |
| `/plan-sprint` | Full week's goals breakdown | Multiple single-file plans | Full sprint |

**Use `/deep-plan` when:**
- The work spans multiple systems or requires coordinated changes
- There are architectural decisions with long-term consequences
- The work has internal parallelization opportunities
- A single plan file would exceed ~150 lines
- The user describes something that "feels big" or has unclear scope

## Phase 1: Understand the Problem

### 1. Load context

Read the current week's goals and existing sprint plans to understand the landscape.

### 2. Interrogate the request

Complex work deserves hard questions upfront. Pick the 2-3 most relevant:

- **"What would success look like?"** — Get a concrete picture of the end state.
- **"What breaks if we don't do this?"** — Distinguish between urgent and important.
- **"What's the one-way door here?"** — Identify decisions expensive to reverse.
- **"Is this one workstream or several?"** — Sometimes it's 2-3 independent improvements that don't need deep planning.
- **"How does this connect to the demo script?"** — If it doesn't serve a demo scene, ask why it's this week's work.

**Wait for the user's answers before proceeding.**

## Phase 2: Deep Architecture Exploration

Use up to 3 Explore agents in parallel, each with a focused search mission:

- **Agent A**: Current implementation — how things work today, data flows, write paths
- **Agent B**: Integration points — what systems touch this, what depends on it
- **Agent C**: Patterns and precedent — how similar problems were solved elsewhere in the codebase

Each agent should return file paths with line numbers, concrete code snippets, and observations about gaps or risks.

### Synthesize findings

- **What exists** — Working code, established patterns, useful primitives
- **What's missing** — Gaps between current state and desired state
- **What's fragile** — Code with hidden assumptions or scaling limits
- **What's a one-way door** — Decisions baked in that constrain future options

## Phase 3: Architecture Analysis & Risk Assessment

### One-way door analysis

For each architectural risk:

1. **Current behavior** — What the code does today (file:line references)
2. **Why it's a one-way door** — What makes this expensive to change later
3. **Cost of fixing later** — What a retroactive fix would require
4. **Recommendation** — Fix now, fix later, or accept the tradeoff

### Security review

For workstreams touching authentication, data access, external APIs, or user input:
- Check workspace/tenant isolation on new queries
- Check input validation on new endpoints
- Check credential handling for new integrations
- Check access control on new mutations

Document findings. Critical issues become blocking sub-plans.

### What's NOT a one-way door

Explicitly call out decisions that are safe to defer — this prevents scope creep.

## Phase 4: Design & Questioning

Use a Plan agent to design the implementation approach with the full architecture analysis context.

### Challenge the design

- **"Is this the simplest thing that works?"** — Push back on unnecessary abstractions.
- **"What happens if we ship half of this?"** — Can sub-plans be shipped independently?
- **"Where will we regret this in 3 months?"** — New code creates one-way doors too.

Present the design to the user with your concerns. Wait for input on tradeoffs before finalizing.

## Phase 5: Sub-Plan Decomposition

Break the workstream into individually executable sub-plans.

### Decomposition principles

- **Each sub-plan is independently shippable.** It has its own branch, tests, and PR.
- **Shared context lives in the entry point.** Architecture decisions go in `00-*.md`.
- **Dependency graph is explicit.** Which sub-plans can run in parallel? Which must be sequential?
- **Each sub-plan follows the standard template** from `plan-sprint`.

### Parallelization strategy

For each sub-plan, identify:
- Which files it touches (non-overlapping file footprints enable parallelism)
- Which sub-plans must complete first
- Estimated complexity (pts)
- Recommended merge order

Include a time budget table:

| Sub-plan | Complexity | Can parallel? | Dependencies |
|----------|------------|---------------|-------------|

## Phase 6: Write the Plan Folder

```
docs/plans/YYYY-wNN/sprint-plans/<workstream-slug>/
  00-architecture-analysis.md    # Entry point
  G1-<descriptive-slug>.md       # Sub-plan (executable by build-plan)
  G2-<descriptive-slug>.md       # Sub-plan
```

### Entry point document (`00-*.md`) must include:

1. **Context** — Why this workstream exists
2. **Current state summary** — What works today
3. **One-way door analysis** — Core architectural assessment
4. **Security review findings** — If applicable
5. **Decisions that are NOT one-way doors** — What's safe to defer
6. **Execution strategy & parallelization** — Dependency graph, time budget
7. **Sub-plan index** — Table linking to each sub-plan

## Phase 7: Integrate with Sprint

### Update the goals document

Add the workstream to the Sprint Plan table in the goals doc. Link to the `00-*.md` entry point.

### Commit and push

```bash
git checkout -b docs/<workstream-slug>
git add docs/plans/YYYY-wNN/sprint-plans/<workstream-slug>/
git commit -m "docs(plans): add <workstream> architecture analysis and sprint plans"
git push -u origin docs/<workstream-slug>
gh pr create ...
```

## Guidelines

- **Architecture analysis is the deliverable, not the sub-plans.** The sub-plans follow naturally from a good analysis.
- **One-way doors are the priority filter.** When scoping what's launch-critical vs. deferrable, ask: "Can we fix this later without a migration?" If yes, it can wait.
- **Challenge early, not late.** Ask hard questions in Phase 1, not Phase 5.
- **Keep sub-plans independently valuable.** If shipping G1 without G2 makes things worse, they should be one plan.
