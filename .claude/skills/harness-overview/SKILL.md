---
name: harness-overview
description: Use when the user wants to audit or understand the agent harness itself — its hooks, skills, agents, or commands — or asks "what's in this harness", "how does this harness work", or "harness overview".
user-invocable: true
tier: util
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Run `/harness-update` to pull it in." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Quality Harness Overview

Complete documentation of the agent harness — hooks, skills, agents, and commands.

## Hooks

| Hook | Event | Matcher | Purpose |
|------|-------|---------|---------|
| `harness.config.sh` | (sourced) | — | Central project configuration — edit this to customize |
| `bash-guard.sh` | PreToolUse | Bash | Blocks commits on main, --no-verify, destructive ops on source files |
| `protected-files.sh` | PreToolUse | Edit\|Write\|MultiEdit | Blocks edits to .env, hooks, settings, lockfile |
| `init.sh` | SessionStart | startup | Injects branch, commits, changes, handoff notes |
| `context-reinject.sh` | SessionStart | resume\|compact | Lighter context re-injection after compaction |
| `post-edit.sh` | PostToolUse | Edit\|Write\|MultiEdit | Auto-format + lint (async); DB migration on schema change |
| `stop.sh` | Stop | — | Run tests, typecheck, write handoff, macOS notification |
| `failure-log.sh` | PostToolUseFailure | — | Log failures to .claude/logs/failures.jsonl |
| `pre-compact.sh` | PreCompact | — | Save transcript snapshot before compaction |
| `config-audit.sh` | ConfigChange | — | Log config changes to .claude/logs/config-changes.jsonl |

## Skills

### Process & Workflow

| Skill | Purpose |
|-------|---------|
| `weekly-goals/` | Load current week's goals, guard capacity, align work to priorities |
| `demo-script/` | Generate customer-story demo scripts for the current week |
| `plan-sprint/` | Break weekly goals into executable project plans |
| `deep-plan/` | Plan complex multi-system workstreams with architecture analysis |
| `ad-hoc-plan/` | Quick plan for a single mid-sprint task |
| `build-plan/` | Execute a sprint plan autonomously end-to-end |
| `ship/` | Full shipping pipeline (test → lint → commit → push → PR) |
| `sync/` | Switch back to main and pull latest |
| `worktree/` | Git worktree management for parallel work |
| `harness-update/` | Pull latest harness into this project; preserves config and local-only skills |

### Quality & Verification

| Skill | Purpose |
|-------|---------|
| `tdd/` | Test-driven development workflow |
| `self-verify/` | Quick browser-based UI verification |
| `e2e-verify/` | Full E2E Chrome verification |
| `dev-server/` | Start/stop/monitor dev server |
| `pre-deploy/` | Full go/no-go pre-deployment quality gate |
| `db-review/` | Review database migrations for safety |
| `security-review/` | 15-phase comprehensive security audit |

### Operations

| Skill | Purpose |
|-------|---------|
| `incident/` | Structured incident response for production issues |
| `harness-overview/` | This document |

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `builder.md` | Sonnet | Full edit access, follows project conventions |
| `validator.md` | Opus | Read-only, runs tests/lint/security checks |
| `e2e-tester.md` | Sonnet | Browser automation, UI verification |
| `migration-validator.md` | Haiku | Read-only, verifies DB migration completeness |

## Commands

| Command | Purpose |
|---------|---------|
| `/orchestrate <task>` | Decompose task → builder → validator → iterate |
| `/harness-health` | Check all harness components are working |

## Configuration

All project-specific values live in `.claude/hooks/harness.config.sh`. Edit it once when installing in a new project:

```bash
HARNESS_PKG_MGR="pnpm"           # package manager
HARNESS_SRC_DIRS="src|lib"       # source dirs (regex alternation)
HARNESS_TEST_CMD="pnpm test"     # test command
HARNESS_APP_NAME="My App"        # app name for notifications
# ... see harness.config.sh for full list
```

## Workflow

The full workflow from planning to shipping:

```
/weekly-goals  →  /demo-script  →  /plan-sprint  →  /build  →  /sync
   (why)            (what)           (how)          (do it)    (reset)
```

## Adding Project-Specific Skills

To add skills for your project, create `<skill-name>/SKILL.md` in `.claude/skills/`. The skill loader discovers them automatically. Skills in this harness are generic — your project-specific skills extend them without modifying the base.
