# Orchestrate

Decompose a task into builder subtasks, validate results, and iterate until passing.

## Usage

`/orchestrate <task description>`

## Workflow

1. **Decompose** the task into discrete implementation steps
2. **Spawn builder agent(s)** — use worktrees for parallel work if steps are independent
3. **Wait for completion** of each builder step
4. **Spawn validator agent** to review all changes
5. **If validation fails** — create fix tasks and re-run builder
6. **If validation passes** — report results and list all commits

## Rules

- Max 3 iterations of build → validate → fix
- If still failing after 3 iterations, report status and ask for guidance
- Always run the full validator suite (tests, lint, format, security)
- Merge worktree branches back to the working branch when done

## Parallelization

If the task decomposes into independent steps with non-overlapping file footprints, spawn multiple builder agents in separate worktrees:

```bash
BRANCH_NAME="claude/$(openssl rand -hex 4)"
git worktree add .claude/worktrees/$BRANCH_NAME -b $BRANCH_NAME
```

Each builder agent works in its own worktree. When done, the orchestrator merges results.
