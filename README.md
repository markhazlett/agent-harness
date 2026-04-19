# Agent Harness

A portable Claude Code agent infrastructure you can drop into any project. Provides quality hooks, specialized agents, reusable skills, and a sprint planning workflow that takes work from goals through to shipped code.

Extracted from [Sigio](https://sigio.io) — battle-tested on a production Next.js monorepo.

---

## What's included

```
.claude/
  hooks/              # 9 shell hooks + 1 central config file
  agents/             # 4 specialized sub-agents
  commands/           # 2 slash commands
  skills/             # 18 reusable skills
  settings.json       # Hook wiring + permission allowlist template
docs/
  plans/
    README.md         # Planning conventions + workflow docs
setup.sh              # Interactive configuration wizard
```

---

## Quick start

```bash
# 1. Copy the .claude/ directory into your project
cp -r /path/to/agent-harness/.claude /your/project/

# 2. Run the setup wizard (configures harness.config.sh for your project)
cd /your/project
chmod +x setup.sh && ./setup.sh

# 3. Verify everything is wired up
claude /harness-health
```

That's it. Open Claude Code in your project and the hooks activate automatically.

---

## How to install

### Option A: Copy the directory

```bash
cp -r agent-harness/.claude /path/to/your-project/
cp agent-harness/setup.sh /path/to/your-project/
cp -r agent-harness/docs /path/to/your-project/
cd /path/to/your-project && ./setup.sh
```

### Option B: Clone and symlink (for shared dev environments)

```bash
git clone https://github.com/markhazlett/agent-harness ~/.agent-harness
cd /path/to/your-project
ln -s ~/.agent-harness/.claude .claude
./setup.sh
```

### What setup.sh does

The interactive wizard asks for:
- Package manager (pnpm/npm/yarn/bun)
- Source directory patterns (e.g., `src|lib|apps`)
- Test, typecheck, lint, format, build commands
- Dev server command and port
- DB schema path and migration commands (optional)

It writes these to `.claude/hooks/harness.config.sh` and makes all hook scripts executable.

---

## Hooks

All 9 hooks are wired automatically via `.claude/settings.json`.

| Hook | Trigger | What it does |
|------|---------|--------------|
| `init.sh` | Session start | Injects branch, recent commits, uncommitted changes, and handoff notes into Claude's context |
| `context-reinject.sh` | Resume / compact | Lighter context re-injection after compaction |
| `bash-guard.sh` | Before any Bash | Blocks: commits on main, `--no-verify`, `sed -i` on source files, `rm -rf` on source dirs |
| `protected-files.sh` | Before Edit/Write | Blocks edits to `.env` files, hook scripts, `settings.json`, lockfile |
| `post-edit.sh` | After Edit/Write (async) | Auto-runs Prettier + ESLint; triggers DB migration if schema file changed |
| `stop.sh` | Session end | Runs tests + typecheck if source changed; writes handoff notes; macOS notification |
| `failure-log.sh` | Tool failure (async) | Appends to `.claude/logs/failures.jsonl` for diagnostics |
| `pre-compact.sh` | Before compaction (async) | Saves transcript snapshot to `.claude/transcripts/` |
| `config-audit.sh` | Config change (async) | Appends to `.claude/logs/config-changes.jsonl` |

### Central config

All project-specific values live in one file: `.claude/hooks/harness.config.sh`

```bash
HARNESS_PKG_MGR="pnpm"
HARNESS_SRC_DIRS="src|lib|apps"
HARNESS_TEST_CMD="pnpm test"
HARNESS_TYPECHECK_CMD="pnpm run typecheck"
HARNESS_LINT_CMD="pnpm run lint"
HARNESS_FORMAT_CMD="pnpm run format"
HARNESS_BUILD_CMD="pnpm run build"
HARNESS_APP_NAME="My App"
HARNESS_DEV_PORT="3000"
HARNESS_DEV_CMD="pnpm run dev"
HARNESS_LOCK_FILE="pnpm-lock.yaml"

# Optional: DB migration on schema save
HARNESS_DB_SCHEMA_PATH="src/db/schema.ts"
HARNESS_DB_GENERATE_CMD="pnpm run db:generate"
HARNESS_DB_PUSH_CMD="pnpm run db:push"
HARNESS_DB_MIGRATIONS_DIR="drizzle"
```

Every hook sources this file at the top. Edit it once; all hooks update automatically.

---

## Agents

Four specialized sub-agents that Claude can dispatch:

| Agent | Model | Access | Purpose |
|-------|-------|--------|---------|
| `builder.md` | Sonnet | Edit/Write | Implements code changes following CLAUDE.md conventions |
| `validator.md` | Opus | Read-only | Runs tests, lint, format, security checks |
| `e2e-tester.md` | Sonnet | Browser | Verifies features work in Chrome via Claude-in-Chrome MCP |
| `migration-validator.md` | Haiku | Read-only | Verifies DB schema changes are complete and consistent |

Agents are spawned by the `/orchestrate` command or directly via the `Agent` tool.

---

## Commands

### `/orchestrate <task>`

Decomposes a task into sub-tasks, spawns builder agents, runs the validator, and iterates until passing. Up to 3 build → validate → fix cycles before asking for guidance.

### `/harness-health`

Checks that all hooks are executable, settings are wired correctly, config values are populated, and tests pass.

---

## Skills

Skills are invokable prompts that implement specific workflows. Use them with `/skill-name` in Claude Code.

### Workflow skills

| Skill | Trigger | Purpose |
|-------|---------|---------|
| `/weekly-goals` | Start of week | Load goals, align work, guard capacity |
| `/demo-script` | Planning | Generate customer-story demo script scoped to the week |
| `/plan-sprint` | Planning | Break goals into executable plans with file footprints |
| `/deep-plan` | Complex features | Architecture analysis + sub-plan decomposition |
| `/ad-hoc-plan` | Mid-sprint | Quick plan for a single task |
| `/build <plan>` | Execution | Run a sprint plan end-to-end |
| `/ship` | Shipping | Test → lint → commit → push → PR |
| `/sync` | Reset | Switch to main and pull |

### Quality skills

| Skill | Trigger | Purpose |
|-------|---------|---------|
| `/tdd` | Implementation | Test-driven development cycle |
| `/pre-deploy` | Before deploy | Full go/no-go quality gate |
| `/security-review` | Before deploy | 15-phase security audit |
| `/db-review` | Schema changes | Migration safety review |
| `/e2e-verify` | After UI changes | End-to-end browser verification |
| `/self-verify` | Quick check | Browser UI spot-check |
| `/dev-server` | Development | Start/stop/monitor dev server |

### Operations skills

| Skill | Trigger | Purpose |
|-------|---------|---------|
| `/incident` | Production issues | Structured incident response |
| `/worktree` | Parallel work | Git worktree management |
| `/harness-overview` | Reference | Full harness documentation |

---

## Conductor integration

The harness auto-integrates with [Conductor](https://conductor.build) — when you run it inside a Conductor workspace (i.e. under `~/conductor/workspaces/<repo>/`), extra capabilities activate:

### What activates automatically

- **Sibling workspace awareness.** On SessionStart, `conductor-context.sh` injects a rollup of sibling workspaces into Claude's context: who's working on what, which branch, what phase.
- **Per-workspace status manifest.** `/build` writes `.context/conductor-status.json` at each phase (implementing → verifying → shipped). Siblings read it for the rollup; the file is `.gitignored`-per-workspace, so it never pollutes branches.

### Sprint dispatch flow

Inside `/plan-sprint`:

1. Plans get written as usual.
2. **Phase 3.5** detects parallel-safe waves by topologically sorting `Depends on` and eliminating pairs with overlapping `File Footprint`s.
3. **Phase 5** offers to dispatch Wave 1 — one `conductor://async` deep link per plan, opening new Conductor workspaces with the plan file pre-attached. Type `/build <plan-path>` in each child to execute.

### Bootstrapping a new project

Run `./setup.sh` in a fresh clone. The wizard generates both `.claude/hooks/harness.config.sh` and `conductor.json` (with `setup`/`run`/`archive` scripts tailored to your detected stack). Commit `conductor.json` to share Conductor setup across your team.

### Helpers

| Helper | What it does |
|---|---|
| `bin/conductor-status get/update/list` | Read/write the per-workspace manifest; used by `/build` and the SessionStart hook |
| `bin/conductor-dispatch <plan.md>` | Base64-encode a plan and `open` a `conductor://async` deep link |
| `.claude/hooks/conductor-context.sh` | SessionStart hook that prints the sibling rollup |

### Verifying

```bash
claude /harness-health  # includes Conductor integration checks
```

---

## Planning workflow

The harness ships with a sprint planning system. Plans live in `docs/plans/`:

```
docs/plans/
  2026-w15/
    2026-w15-goals.md       # North Star, P0/P1/P2 priorities, demo script
    sprint-plans/
      P0.1-feat-my-feature.md
      P0.2-fix-my-bug.md
```

The full workflow:

```
/weekly-goals → /demo-script → /plan-sprint → /build <plan> → /sync
   (why)           (what)          (how)         (do it)       (reset)
```

See `docs/plans/README.md` for the full planning conventions.

---

## Extending with project-specific skills

Add your own skills in `.claude/skills/<skill-name>/SKILL.md`:

```bash
mkdir -p .claude/skills/my-skill
cat > .claude/skills/my-skill/SKILL.md << 'EOF'
# My Skill

Description of what this skill does and when to use it.

## Steps
...
EOF
```

The skill loader discovers them automatically. Your project skills complement the base harness skills — you don't need to modify base skills to extend behavior.

---

## Git safety

The bash-guard hook enforces these rules automatically:

- No commits or pushes on `main`/`master`
- No `--no-verify` flag (hooks cannot be bypassed)
- No `sed -i` on source directories (use the Edit tool instead)
- No `rm -rf` on source directories
- No redirect overwrites to source files

The protected-files hook blocks edits to:
- `.env` files (any variant)
- Hook scripts themselves (guards the guards)
- `.claude/settings.json`
- The lockfile

---

## Requirements

- Claude Code (any recent version)
- Git
- `jq` (used by hooks for JSON parsing)
- `bash` (hooks are bash scripts)
- `gh` CLI (optional, for PR creation in `/ship`)
- `npx` (optional, for auto-format/lint in `post-edit.sh`)

---

## License

MIT
