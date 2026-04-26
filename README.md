# Agent Harness

A production-tested toolkit that turns Claude Code into a reliable teammate: it plans your week, executes sprints, ships code, and refuses to touch `main`, `.env`, or anything else you'd have to revert.

Built for engineers who pair with Claude Code daily. Battle-tested on a Next.js monorepo at [Sigio](https://sigio.io). Works standalone with plain Claude Code, or lights up parallel-agent features when running inside a [Conductor](https://conductor.build) workspace.

---

## The workflow

```
/weekly-goals → /demo-script → /plan-sprint → /build <plan> → /ship
    (why)          (what)           (how)          (do it)     (send it)
```

Five commands cover the whole week. Pick goals Monday, draft a customer demo to stay honest about *what* you're shipping, break it into plans with explicit file footprints, dispatch them one at a time (or in parallel under Conductor), and ship with a lint + test + PR gate. That's the product.

---

## Install

Open Claude Code in the repo you want to set up and paste this:

```
Install the agent harness from https://github.com/markhazlett/agent-harness into this repo.

Steps:
1. Clone the harness to a temp dir: `git clone --depth 1 https://github.com/markhazlett/agent-harness /tmp/agent-harness-install`
2. Copy into the current repo root: `.claude/`, `bin/`, `setup.sh`, `VERSION`
3. Run `./setup.sh` — ask me each prompt it shows (workspace host, package manager, dev port, DB commands, etc.) and relay my answers
4. Clean up: `rm -rf /tmp/agent-harness-install`
5. Run `/harness-health` and report the result
```

The agent clones the latest harness, copies it in, walks you through the setup wizard, and verifies the install. Prefer a manual copy or a symlinked dev environment? See [install options](#install-options-detail) below.

---

## What you get

**A planning system that survives week to week.** Sprint plans live in `docs/plans/YYYY-wNN/` with dated goals, demo scripts, and per-priority plan files. `/plan-sprint` decomposes goals into parallel-safe waves by topologically sorting dependencies and eliminating pairs with overlapping file footprints. `/build` executes a plan end-to-end.

**Guardrails that run automatically.** A `bash-guard` hook blocks commits on `main`, `--no-verify` bypasses, `sed -i` on source files, and `rm -rf` on source dirs. A `protected-files` hook prevents edits to `.env` files, hook scripts, and `settings.json`. Claude can't accidentally do the things you'd have to revert anyway.

**Session state that persists through compaction.** At session start, you see branch + recent commits + uncommitted diff + prior-session handoff notes. On stop, tests + typecheck run automatically if source changed and handoff notes are written for next time. Before compaction, the full transcript is snapshotted. Your context survives.

**Specialized agents for the hard parts.** A read-only `validator` (Opus) that runs tests / lint / format / security checks. An `e2e-tester` (Sonnet) that drives a real Chrome browser. A `migration-validator` (Haiku) for schema changes. Dispatch them with `/orchestrate` or the `Agent` tool.

**A learning loop that compounds.** `/learn` captures corrections and surprising approvals from the session into `CLAUDE.md` (project) or your memory (user). Run it after a tough session — next time, the agent already knows.

**LangGraph track (opt-in).** Six `/lg-*` skills for building LangChain v1 / LangGraph v1 / Deep Agents work in TS — design (`/lg-design`), scaffold (`/lg-scaffold`), capability adds (`/lg-add`), evals (`/lg-eval`), audit (`/lg-review`), and a v1-current cheatsheet (`/lg-cheatsheet`). Default off; enable during `./setup.sh`.

**Auto-formatting, auto-typecheck, auto-everything.** Prettier + ESLint run after every edit. DB schema saves trigger your generate/push commands. Failed tool calls log themselves. You stop thinking about the mechanical parts.

---

## Conductor mode (optional)

If you use [Conductor](https://conductor.build) to run parallel Claude Code agents, `setup.sh` detects your `~/conductor/workspaces/` and defaults to Conductor mode. Three extras activate:

- **Sibling rollup** at session start — what other Conductor workspaces are working on (branch, phase, status).
- **Per-workspace status manifests.** `/build` writes `.context/conductor-status.json` as it progresses; siblings read it for the rollup.
- **Sprint dispatch.** `/plan-sprint` detects parallel-safe waves and offers to open one Conductor workspace per plan via `conductor://async` deep links.

Not using Conductor? Pick Claude Code mode at the setup prompt (the default when Conductor isn't detected) and the Conductor helpers self-gate to no-ops. Everything else works identically. The mode is stored in `.claude/hooks/harness.config.sh` as `HARNESS_HOST`; re-run `./setup.sh` to switch.

---

## Reference

<details>
<summary><strong>Install options detail</strong></summary>

### Manual copy

```bash
git clone --depth 1 https://github.com/markhazlett/agent-harness /tmp/agent-harness
cp -r /tmp/agent-harness/.claude /path/to/your-project/
cp -r /tmp/agent-harness/bin /path/to/your-project/
cp /tmp/agent-harness/setup.sh /path/to/your-project/
cp /tmp/agent-harness/VERSION /path/to/your-project/
cd /path/to/your-project && ./setup.sh
```

### Clone and symlink (for shared dev environments)

```bash
git clone https://github.com/markhazlett/agent-harness ~/.agent-harness
cd /path/to/your-project
ln -s ~/.agent-harness/.claude .claude
ln -s ~/.agent-harness/bin bin
~/.agent-harness/setup.sh
```

### What `setup.sh` asks for

Workspace host (Conductor or Claude Code), package manager, source dirs, test / typecheck / lint / format / build / dev commands, dev port, DB commands (optional), required env vars. Writes the result to `.claude/hooks/harness.config.sh` where every hook reads from it. Re-run any time to reconfigure.

</details>

<details>
<summary><strong>All hooks</strong> — wired automatically via <code>.claude/settings.json</code></summary>

| Hook | Trigger | What it does |
|------|---------|--------------|
| `init.sh` | Session start | Injects branch, recent commits, uncommitted changes, handoff notes |
| `context-reinject.sh` | Resume / compact | Lighter context re-injection after compaction |
| `bash-guard.sh` | Before any Bash | Blocks commits on main, `--no-verify`, `sed -i` on source, `rm -rf` on source |
| `protected-files.sh` | Before Edit / Write | Blocks edits to `.env`, hook scripts, `settings.json`, lockfile |
| `post-edit.sh` | After Edit / Write (async) | Runs Prettier + ESLint; triggers DB migration if schema changed |
| `stop.sh` | Session end | Runs tests + typecheck if source changed; writes handoff notes |
| `failure-log.sh` | Tool failure (async) | Appends to `.claude/logs/failures.jsonl` |
| `pre-compact.sh` | Before compaction (async) | Saves transcript snapshot to `.claude/transcripts/` |
| `config-audit.sh` | Config change (async) | Appends to `.claude/logs/config-changes.jsonl` |

</details>

<details>
<summary><strong>All skills</strong> — invoke with <code>/skill-name</code></summary>

**Workflow**

| Skill | When | Purpose |
|---|---|---|
| `/weekly-goals` | Start of week | Load goals; guard capacity |
| `/demo-script` | Planning | Customer-story demo for the week's goals |
| `/plan-sprint` | Planning | Break goals into executable plans with file footprints |
| `/deep-plan` | Complex features | Architecture analysis + sub-plan decomposition |
| `/ad-hoc-plan` | Mid-sprint | Quick plan for a one-off task |
| `/build <plan>` | Execution | Run a sprint plan end-to-end |
| `/ship` | Shipping | Test → lint → commit → push → PR |
| `/learn` | After a session | Capture corrections from the session into project + user learnings |
| `/sync` | Reset | Switch to main and pull |

**Quality**

| Skill | When | Purpose |
|---|---|---|
| `/tdd` | Implementation | Test-driven development cycle |
| `/pre-deploy` | Before deploy | Full go / no-go quality gate |
| `/security-review` | Before deploy | 15-phase security audit |
| `/db-review` | Schema changes | Migration safety review |
| `/e2e-verify` | After UI changes | End-to-end browser verification |
| `/self-verify` | Quick check | Browser UI spot-check |
| `/dev-server` | Development | Start / stop / monitor dev server |

**Operations**

| Skill | When | Purpose |
|---|---|---|
| `/incident` | Production issues | Structured incident response |
| `/worktree` | Parallel work | Git worktree management |
| `/harness-overview` | Reference | Full harness documentation |

**LangGraph (opt-in via `./setup.sh`)**

| Skill | When | Purpose |
|---|---|---|
| `/lg-design` | Before agent code | Design conversation, picks pattern, produces design doc |
| `/lg-scaffold` | New agent | Generates runnable v1 code (createAgent / StateGraph / Deep Agent) |
| `/lg-add` | Existing agent | Adds HITL / persistence / streaming / sub-agent / tool / middleware / store |
| `/lg-eval` | After scaffold | LangSmith or local-only eval harness with trajectory checks |
| `/lg-review` | Anytime | Audits for v1 best practices, deprecated patterns, footguns |
| `/lg-cheatsheet` | Reference | v1 API, footgun list, deprecation list |

</details>

<details>
<summary><strong>Agents</strong> — dispatched by <code>/orchestrate</code> or the <code>Agent</code> tool</summary>

| Agent | Model | Access | Purpose |
|-------|-------|--------|---------|
| `builder.md` | Sonnet | Edit / Write | Implements code changes following CLAUDE.md conventions |
| `validator.md` | Opus | Read-only | Runs tests, lint, format, security checks |
| `e2e-tester.md` | Sonnet | Browser | Verifies features in Chrome via Claude-in-Chrome MCP |
| `migration-validator.md` | Haiku | Read-only | Verifies DB schema changes are complete and consistent |

</details>

<details>
<summary><strong>Commands</strong></summary>

- **`/orchestrate <task>`** — Decomposes a task, spawns builder agents, runs the validator, iterates up to 3 cycles before asking for guidance.
- **`/harness-health`** — Checks hooks are executable, settings are wired, config is populated, tests pass.

</details>

<details>
<summary><strong>Guardrails detail</strong></summary>

**`bash-guard` blocks:**
- Commits or pushes on `main` / `master`
- `--no-verify` (hooks cannot be bypassed)
- `sed -i` on source directories (use the Edit tool)
- `rm -rf` on source directories
- Redirect overwrites to source files

**`protected-files` blocks Edit / Write on:**
- `.env` files (any variant)
- Hook scripts themselves (guards the guards)
- `.claude/settings.json`
- The lockfile

</details>

<details>
<summary><strong>Central config</strong> — <code>.claude/hooks/harness.config.sh</code></summary>

Every hook sources this file. Edit once, everything updates.

```bash
HARNESS_HOST="conductor"              # or "claude-code"
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

# Optional: auto-run DB commands when schema changes
HARNESS_DB_SCHEMA_PATH="src/db/schema.ts"
HARNESS_DB_GENERATE_CMD="pnpm run db:generate"
HARNESS_DB_PUSH_CMD="pnpm run db:push"
HARNESS_DB_MIGRATIONS_DIR="drizzle"
```

</details>

<details>
<summary><strong>Extending with your own skills</strong></summary>

Drop a file in `.claude/skills/<name>/SKILL.md`:

```bash
mkdir -p .claude/skills/my-skill
cat > .claude/skills/my-skill/SKILL.md << 'EOF'
# My Skill

Description and when to use it.

## Steps
...
EOF
```

The skill loader discovers it automatically. Project skills complement the base ones — you don't need to modify base skills to add behavior.

</details>

<details>
<summary><strong>File layout</strong></summary>

```
.claude/
  hooks/              9 shell hooks + harness.config.sh
  agents/             4 specialized sub-agents
  commands/           2 slash commands
  skills/             18 reusable skills
  settings.json       hook wiring + permission allowlist
bin/
  conductor-status    per-workspace status manifest (Conductor mode)
  conductor-dispatch  open conductor:// deep links (Conductor mode)
docs/plans/README.md  planning conventions
setup.sh              interactive configuration wizard
```

</details>

---

## Requirements

Claude Code · git · `bash` · `jq` · optional: `gh` (for `/ship`) · optional: `npx` (for auto-format in `post-edit.sh`)

## Credits

The `/office-hours` skill is adapted from the office-hours skill in [Garry Tan's gstack](https://github.com/garrytan/gstack), with the gstack-specific harness scaffolding stripped out. Original content by Garry Tan, used under MIT.

## License

MIT
