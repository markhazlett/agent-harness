---
name: worktree
description: Use when spinning up builder agents, working on multiple isolated tasks simultaneously, or the user says "create a worktree", "isolated branch", or "parallel workspace".
user-invocable: true
tier: util
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Worktree Management

Manage git worktrees for isolated parallel development. Use when spinning up builder agents or working on multiple tasks simultaneously.

## Create a Worktree

```bash
BRANCH_NAME="claude/$(openssl rand -hex 4)"
git worktree add .claude/worktrees/$BRANCH_NAME -b $BRANCH_NAME
cd .claude/worktrees/$BRANCH_NAME
# Install dependencies if needed (read CLAUDE.md for the right command)
```

## Rules

- Max **3 active worktrees** at a time
- Install dependencies after creating if the project requires it
- Worktrees go under `.claude/worktrees/` (gitignored)
- Clean up when done

## List Worktrees

```bash
git worktree list
```

## Remove a Worktree

```bash
git worktree remove .claude/worktrees/<name>
```

## Clean Up All

```bash
git worktree list --porcelain | grep "^worktree" | grep ".claude/worktrees" | awk '{print $2}' | xargs -I{} git worktree remove {} --force
```

## Use Case: Parallel Builder Agents

When running multiple builder agents in parallel (via `/orchestrate`):
1. Create one worktree per independent task
2. Each agent works in its own worktree on its own branch
3. When all agents complete, the orchestrator merges results
4. Remove worktrees after merge
