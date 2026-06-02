# Pi Harness Support — Design

**Date:** 2026-05-18
**Author:** Mark Hazlett
**Status:** Draft — awaiting review
**Builds on:** [2026-04-22 Multi-Harness Support](2026-04-22-multi-harness-support-design.md) — which introduced `HARNESS_HOST=conductor|claude-code` and explicitly punted "additional hosts" out of scope. This spec adds `pi` as the third host value and ports the harness to run inside Pi.

## Motivation

[Pi](https://pi.dev/docs/latest) is a terminal coding harness from Earendil — a direct alternative to the `claude` CLI. It supports the same Agent Skills spec we already use, has a similar prompt-template (slash command) system, and provides a TypeScript event-hook system roughly isomorphic to Claude Code's bash hooks. With a deliberate port we can offer the full harness — skills, prompts, hooks, subagents, plan→ship workflow — to Pi users with the same install paste.

The trigger: I want the harness to be a first-class option on Pi, not a Claude-Code-only artifact that happens to work on Pi if you squint. The phrasing in the original ask — "similar to being able to choose Claude Code or Conductor for Pi" — maps cleanly: extend the existing `HARNESS_HOST` axis with a third value.

## Goals

- A user on Pi can run the standard install paste and end up with a working harness (skills load, prompts work, hooks fire on tool calls, `task` subagent dispatch works).
- The plan→ship workflow (`/weekly-goals` → `/plan-sprint` → `/build` → `/ship`) works identically on Pi as on Claude Code.
- Existing Conductor and Claude Code users see zero behavior change unless they re-run `setup.sh`.
- The harness source repo organizes skills/prompts/agents at a neutral canonical location, so adding future hosts is a smaller diff next time.

## Non-Goals (v1)

- **Pi + Conductor.** Conductor today launches `claude`; whether it can launch `pi` is open and untested. v1 treats Pi as a standalone third host. A research task in the spec sketches a v2 `pi-conductor` host.
- **`config-audit.sh` equivalent on Pi.** Pi has no native ConfigChange event. Dropped in v1; revisit if users miss it.
- **Streaming sub-agent output through the `task` tool.** v1 returns the final message only.
- **npm-package distribution.** v1 ships via the existing git-clone install. v2 publishes as `npm:@markhazlett/agent-harness` so Pi users can install via `pi.packages`.
- **Windows support.** Mac-only is acceptable for the harness maintainer's own dev workflow (the harness source repo uses symlinks); user installs use copies and are portable.

## Design

### 1. Repo restructure — canonical neutral layout

The harness source repo moves skill/prompt/agent files out of `.claude/` to a neutral root location, splits hooks by target runtime, and renames the project-config file.

**Before:**
```
.claude/skills/<n>/SKILL.md         # 30 skills
.claude/commands/*.md               # ~25 commands
.claude/agents/*.md                 # 4 agents
.claude/hooks/*.sh                  # 11 shell hooks
.claude/hooks/harness.config.sh     # neutral config (shell)
.claude/settings.json
CLAUDE.md                           # working-on-the-harness instructions (stays)
docs/claude-md-template.md          # template for user CLAUDE.md (renames)
```

**After:**
```
skills/<n>/SKILL.md                 # canonical, neutral
prompts/*.md                        # canonical, neutral (was commands/)
agents/*.md                         # canonical, neutral
hooks/
  config.sh                         # neutral project config (was harness.config.sh)
  shell/*.sh                        # 10 shell hooks (Claude Code / Conductor)
  pi/                               # NEW — Pi extensions (TypeScript)
    bash-guard/index.ts
    protected-files/index.ts
    init/index.ts
    context-reinject/index.ts
    post-edit/index.ts
    stop/index.ts
    failure-log/index.ts
    pre-compact/index.ts
    task-tool/index.ts              # subagent dispatcher (new)
    _lib/                           # shared utilities
      config.ts                     # parses hooks/config.sh directly (no shell)
      git.ts
      notify.ts
      paths.ts
    package.json
    tsconfig.json
.claude/                            # SYMLINKS into canonical (harness repo only)
  skills/   → ../skills/
  commands/ → ../prompts/
  agents/   → ../agents/
  hooks/    → ../hooks/shell/
  settings.json                     # still real file (Claude-Code-specific schema)
.pi/                                # SYMLINKS into canonical (harness repo only)
  skills/      → ../skills/
  prompts/     → ../prompts/
  agents/      → ../agents/
  extensions/  → ../hooks/pi/
  settings.json                     # still real file (Pi-specific schema)
AGENTS.md                           # canonical project-instructions template
                                    # (Claude Code template renames to this; Pi reads it natively)
```

**User installs (after `setup.sh`):** copies, not symlinks. Each user project has exactly one of `.claude/` or `.pi/`, fully self-contained. The canonical layer at the repo root exists only in the harness source.

**Harness-maintainer dev workflow:** symlinks let us test both targets in the same source tree without duplication. A `bin/harness-link-dev` script (post-MVP) creates these symlinks; for v1 we wire them by hand or via a one-shot script in `setup.sh`'s dev-mode flag.

**Migration:** mechanical mv + grep/sed. ~80–120 files have `.claude/skills/`, `.claude/commands/`, `.claude/hooks/`, `harness.config.sh` references that need updating. Done as one bulk commit so the bisect-able state stays clean.

### 2. Skills layer

Skills barely change. The Agent Skills spec is the same on both hosts; the `SKILL.md` format works as-is. Three small additions:

- **Audit for `.claude/` references inside skill bodies.** Grep found ~12; all become `skills/` or get host-conditional language.
- **Optional `allowed-tools` frontmatter.** Pi enforces it; Claude Code ignores it. Bonus safety on Pi side for rigid skills, no-op on Claude side. Apply to `/tdd`, `/pre-deploy`, `/ship`, `/security-review`, `/incident`, `/db-review`, `/e2e-verify`, `/debug`.
- **Slash-command parity in docs.** Pi has `/skill:<name>` to force-load; Claude Code has `/<name>` directly. Skills that document their own invocation note both.

No skill *code* changes. Skills "just work" on Pi via Pi's settings glob: `"skills": ["./.pi/skills/*/SKILL.md"]` (relative to project root in user install).

### 3. Prompts layer

`.claude/commands/*.md` → `prompts/*.md`. Same Markdown + frontmatter + `$1`/`$@` substitution. Both hosts invoke via `/<name>`.

Internal cross-references (e.g., "see `.claude/commands/ship.md`") become "see `prompts/ship.md`."

### 4. Hooks port: shell → TypeScript

`.claude/hooks/` today contains 10 hooks plus 1 sourced config file (`harness.config.sh`). Of the 10 hooks, 8 get ported to Pi extensions in `hooks/pi/`, 1 is dropped (`config-audit.sh`, no Pi event), and 1 is not applicable (`conductor-context.sh`, Pi doesn't compose with Conductor). The config file stays shell (single source of truth, parsed by the TS hooks via a strict Node parser). One brand-new extension (`task-tool`) is added — see Section 5.

Each extension is a directory with `index.ts` exporting a default factory function.

**Event mapping:**

| Shell hook | Claude Code event | Pi equivalent |
|---|---|---|
| `bash-guard.sh` | PreToolUse: Bash | `pi.on("tool_call", e => e.toolName === "bash")` |
| `protected-files.sh` | PreToolUse: Edit\|Write\|MultiEdit | `pi.on("tool_call", e => ["edit","write"].includes(e.toolName))` |
| `init.sh` | SessionStart: startup | `pi.on("session_start", ...)` + `pi.on("before_agent_start", ...)` for context injection |
| `context-reinject.sh` | SessionStart: resume\|compact | `pi.on("session_compact", ...)`; Pi `session_start` fires on reload |
| `post-edit.sh` | PostToolUse: Edit\|Write\|MultiEdit | `pi.on("tool_result", e => ["edit","write"].includes(e.toolName))` |
| `stop.sh` | Stop | `pi.on("agent_end", ...)` |
| `failure-log.sh` | PostToolUseFailure | `pi.on("tool_result", e => e.error)` |
| `pre-compact.sh` | PreCompact | `pi.on("session_before_compact", ...)` |
| `config-audit.sh` | ConfigChange | **Dropped in v1** — no native Pi event |
| `conductor-context.sh` | SessionStart (host=conductor) | **Not applicable** — Pi host doesn't compose with Conductor in v1 |

**Per-hook structure:**

```typescript
// hooks/pi/bash-guard/index.ts
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { loadHarnessConfig } from "../_lib/config.js";
import { currentBranch } from "../_lib/git.js";

export default function(pi: ExtensionAPI) {
  const cfg = loadHarnessConfig();

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;
    const cmd = event.input.command ?? "";

    if (/^git commit\b/.test(cmd) && currentBranch() === "main") {
      return { block: true, reason: "Refusing to commit on main." };
    }
    if (/--no-verify\b/.test(cmd)) {
      return { block: true, reason: "Refusing to skip hooks." };
    }
    const srcDirs = cfg.HARNESS_SRC_DIRS ?? "src|lib";
    if (new RegExp(`^rm -rf\\b.*\\b(${srcDirs})\\/`).test(cmd)) {
      return { block: true, reason: "Refusing rm -rf on source dir." };
    }
    // ... port remaining rules from bash-guard.sh verbatim
  });
}
```

**Shared utilities** (`hooks/pi/_lib/`):
- `config.ts` — parses `hooks/config.sh` directly with a regex tokenizer. No shell invocation. Handles `KEY="value"`, `KEY='value'`, `KEY=value`, comments, blank lines. Rejects anything that looks like substitution (`$(...)`, backticks) with a clear error — config keys should be literals, not commands.
- `git.ts` — `currentBranch()`, `isDirty()`, etc. Uses `execFile` with explicit `git` args (no shell), via Node's `node:child_process` `execFile`.
- `notify.ts` — macOS notifications via `execFile("osascript", ["-e", scriptString])` (mirrors `stop.sh`).
- `paths.ts` — project root, hooks dir, target dir resolution.

**Async/sync:** Pi's `tool_call` handler returns `{ block: true, reason }`, `{ patch: {...} }`, or nothing. This is strictly more expressive than Claude Code's exit-code conventions; the TS hooks should be more reliable than the shell equivalents.

**Project config bridge:** `hooks/config.sh` stays shell (single source of truth, sourced by shell hooks directly). TS hooks parse the file directly via a small Node parser — no shell exec, no injection surface. The parser accepts simple `KEY=value` lines and `KEY="value"` quoted lines, which covers every current entry in `harness.config.sh`. Anything more exotic (command substitution, conditionals) is rejected at parse time with a clear error.

### 5. Custom `task` tool extension

Replaces Claude Code's native Task tool. Lives at `hooks/pi/task-tool/index.ts`.

```typescript
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { StringEnum } from "@earendil-works/pi-ai";
import { createAgentSession } from "@earendil-works/pi-coding-agent"; // research task: confirm import
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import matter from "gray-matter";

export default function(pi: ExtensionAPI) {
  // In user installs, agents/ lives at .pi/agents/. The extension resolves
  // relative to the .pi/ root, not cwd, so this works whether pi is launched
  // from project root or a subdirectory.
  const agentsDir = join(__dirname, "..", "..", "agents");
  const agents = readdirSync(agentsDir)
    .filter(f => f.endsWith(".md"))
    .map(f => f.slice(0, -3));

  pi.registerTool({
    name: "task",
    label: "Task (subagent)",
    description: "Dispatch a sub-agent for an isolated multi-step task. Returns the sub-agent's final message.",
    promptSnippet: "task — dispatch a sub-agent",
    parameters: Type.Object({
      subagent_type: StringEnum(agents as [string, ...string[]]),
      description: Type.String({ description: "Short label shown in UI" }),
      prompt: Type.String({ description: "Full task brief for the sub-agent" }),
    }),

    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const agentPath = join(agentsDir, `${params.subagent_type}.md`);
      const { data: fm, content: systemPrompt } = matter(readFileSync(agentPath, "utf8"));

      onUpdate?.({ content: [{ type: "text", text: `Spawning ${params.subagent_type}…` }] });

      const { session } = await createAgentSession({
        systemPrompt,
        model: fm.model ?? ctx.modelRegistry.getDefault(),
        tools: fm.tools, // restrict per agent.md frontmatter
        signal,
      });

      const result = await session.prompt(params.prompt);

      return {
        content: [{ type: "text", text: result.message }],
        details: {
          subagent_type: params.subagent_type,
          turns: result.turns,
          tokens: result.tokenUsage,
        },
      };
    },

    renderCall: (args, theme) => /* "task → builder: <desc>" */,
    renderResult: (result, opts, theme) => /* truncated last message */,
  });
}
```

**Concurrency:** v1 supports parallel `task` calls when the parent agent invokes multiple in one message (matching Claude Code). Pi's SDK should support this; confirmed in research task.

**Streaming:** v1 returns final message only. Streaming sub-agent progress through `onUpdate` is post-MVP.

**Frontmatter parsing:** uses `gray-matter` (added to `hooks/pi/package.json`).

### 6. `setup.sh` — three host options

Extends the existing two-option prompt:

```bash
echo "Workspace host:"
echo "  [1] Conductor (default if ~/conductor detected)"
echo "  [2] Claude Code only"
echo "  [3] Pi"
read -p "Choose [1-3] (default: $HOST_DEFAULT_LABEL): " HARNESS_HOST_CHOICE

case "${HARNESS_HOST_CHOICE:-$HOST_DEFAULT_NUM}" in
  1) HARNESS_HOST="conductor" ;;
  2) HARNESS_HOST="claude-code" ;;
  3) HARNESS_HOST="pi" ;;
esac

case "$HARNESS_HOST" in
  conductor|claude-code) install_claude_code_target ;;
  pi)                    install_pi_target ;;
esac
```

**`install_pi_target`:**
- Copies `skills/` → `.pi/skills/`
- Copies `prompts/` → `.pi/prompts/`
- Copies `agents/` → `.pi/agents/` (consumed by `task-tool` extension)
- Copies `hooks/pi/` → `.pi/extensions/`
- Generates `.pi/settings.json` with project-specific values from the wizard (model, theme, package paths)
- Copies `hooks/config.sh` → `.pi/hooks/config.sh` (the TS hooks read this)
- Runs `npm install` inside `.pi/extensions/` to fetch `@earendil-works/pi-coding-agent` and other deps
- Copies `AGENTS.md.template` → `AGENTS.md` (skip if file exists)
- Does NOT generate `conductor.json`, does NOT chmod `bin/conductor-*` helpers

**Generated `.pi/settings.json` skeleton:**
```json
{
  "skills": ["./.pi/skills/*/SKILL.md"],
  "prompts": ["./.pi/prompts/*.md"],
  "extensions": ["./.pi/extensions/*/index.ts"],
  "defaultProvider": "anthropic",
  "defaultModel": "claude-sonnet-4-20250514",
  "theme": "dark"
}
```

### 7. AGENTS.md vs CLAUDE.md

Pi reads `AGENTS.md` natively; Claude Code reads `CLAUDE.md`. The harness ships a single template; `setup.sh` writes it to the host's expected filename.

- `host=claude-code|conductor` → `CLAUDE.md` (existing behavior)
- `host=pi` → `AGENTS.md`

No symlinks at user-install time. Each install has exactly one file. The template lives at `AGENTS.md.template` in the harness repo (was `docs/claude-md-template.md`); content is host-agnostic.

The existing `CLAUDE.md` in the harness source repo (working-on-the-harness instructions) stays as-is — it's a separate concern from the user-install template.

### 8. Update-check, VERSION, testing, distribution

**Update-check:** `bin/harness-update-check` is host-agnostic (VERSION compare against remote). No changes. The `<update-check>` blocks in skill bodies work identically on both hosts.

**`/harness-update` skill:** target-aware. When classifying files (install / safe-update / unchanged / conflict), picks the right target tree per `HARNESS_HOST`. Source-side reads `skills/`, `prompts/`, `agents/`, `hooks/{shell|pi}/` from the freshly-pulled upstream. Algorithm unchanged; only the path mapping changes. ~30-line edit.

**Testing:**
- New `bin/tests/setup-pi.test.sh` — runs `setup.sh --target=pi` in a tempdir; asserts `.pi/skills/` populated, `.pi/settings.json` valid, `.pi/extensions/` copied.
- New `hooks/pi/_lib/__tests__/` (vitest) — unit tests for shared utilities (especially the shell-config parser, which is the highest-risk surface).
- One integration test: runs `pi --headless` against a fixture, sends a `bash rm -rf src/foo` tool call, asserts block message. Catches the "wires are connected" regression.
- Existing `bin/tests/*` test the Conductor and Claude Code paths unchanged.

**VERSION bump:** `0.14.1` → `0.15.0`. Minor — new feature category per CLAUDE.md convention.

**Distribution v1:** existing git-clone install. Same one-paste install for Pi users (script auto-detects `pi` binary on PATH or asks).

**Distribution v2 (post-MVP, flagged):** publish as `npm:@markhazlett/agent-harness` so Pi users can install via `pi.packages: ["npm:@markhazlett/agent-harness"]`. Pi's package system is built for this.

## Research tasks (must resolve before implementation)

These are open questions; the implementation plan should address them before code is written.

1. **Confirm `createAgentSession` API.** Pi's docs mention it in the SDK overview but don't pin the import path or exact signature. Read the Pi npm package locally; if the API doesn't exist as documented, find the actual session-spawning primitive and update Section 5.
2. **Confirm parallel `task` execution.** Verify Pi's SDK doesn't serialize concurrent `createAgentSession` calls. If it does, document the v1 behavior as sequential.
3. **Confirm Pi's `before_agent_start` can mutate the system prompt.** `init.sh` injects branch/commits/handoff into the agent's context. If Pi's event handlers can't add to the system prompt, fall back to injecting a synthetic user message.
4. **Probe Pi + Conductor compat.** Can Conductor be configured to launch `pi` instead of `claude`? If yes, sketch the v2 `pi-conductor` host (out of v1 scope).
5. **Verify `pi --headless` exists** as documented. If not, the integration test path needs another approach.

## Migration / rollout

- Single PR with four logical commits:
  1. Repo restructure (move `.claude/skills/` → `skills/`, etc.; bulk grep/sed). No behavior change.
  2. `setup.sh` adds third host option + `install_pi_target` logic.
  3. `hooks/pi/` extension implementations + tests.
  4. Docs (README adds Pi section, `harness-overview/SKILL.md` updates, VERSION bump to 0.15.0).
- Existing Conductor and Claude Code installs unaffected (no auto-migration; their `HARNESS_HOST` keeps current value; symlinked `.claude/` in harness repo replaces the old real `.claude/`).
- New Pi installs are net-new — no migration concern.

## Risks

- **`createAgentSession` API risk.** If Pi's SDK can't actually spawn sub-sessions cleanly, the `task` tool falls back to shell-out (`pi --headless ...`) — slower, no streaming. Research task #1 resolves this before commit.
- **TS hook drift from shell hook semantics.** Two implementations of the same logic — bugs in one but not the other. Mitigation: each ported hook gets a unit test that mirrors the corresponding shell hook's behavior file-for-file. CI runs both test suites.
- **`hooks/config.sh` parser fragility.** Hand-rolled shell parser may miss edge cases. Mitigation: the parser is strict — only `KEY=value` and `KEY="value"` accepted; anything fancier fails loud with a clear error pointing at the line. Test suite includes the current `harness.config.sh` content + adversarial samples (quoted spaces, escaped quotes, comments).
- **Pi version churn.** Pi is actively developed; SDK signatures may change. Mitigation: pin `@earendil-works/pi-coding-agent` to a tested version in `hooks/pi/package.json`.

## Out of scope (v2 backlog)

- `pi-conductor` host (research task #4 outcome dependent)
- npm-package distribution
- Streaming sub-agent output through `task` tool
- Pi-specific UI affordances (`ctx.ui.setStatus`, custom message renderers, live widgets) — could make hooks visibly richer than the shell equivalents, but v1 maintains parity
- `config-audit` equivalent on Pi
- Windows support
