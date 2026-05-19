# Pi Harness — Research Findings

Resolved questions for the Pi harness implementation plan. Each entry has:
- **Question** — what we wanted to know
- **Method** — how we answered it
- **Finding** — concrete answer
- **Implication** — what this means for the plan

Spec reference: `docs/superpowers/specs/2026-05-18-pi-harness-design.md`
Plan reference: `docs/superpowers/plans/2026-05-18-pi-harness.md`

## R1: createAgentSession API

### Question
Does `createAgentSession` exist in `@earendil-works/pi-coding-agent`? What's its exact signature?

### Method
Installed `@earendil-works/pi-coding-agent@0.75.3` into `/tmp/pi-research-r1` via `npm install`. Inspected `dist/index.d.ts` (the package's declared `types` entrypoint) and `dist/core/sdk.d.ts` (where the function is defined). Also installed the package globally so `pi` is on PATH at `/opt/homebrew/bin/pi` (v0.75.3). Wrote a 15-line smoke test at `/tmp/pi-research-r1/smoke-test.mjs`; could not run it because `ANTHROPIC_API_KEY` was not set in the environment.

### Finding
Confirmed. `createAgentSession` is exported from the package root:

```
import { createAgentSession } from "@earendil-works/pi-coding-agent";
```

Defined in `dist/core/sdk.d.ts` line 106:

```typescript
export declare function createAgentSession(
  options?: CreateAgentSessionOptions
): Promise<CreateAgentSessionResult>;
```

`CreateAgentSessionOptions` (all fields optional):
- `cwd?: string` — working directory for project discovery (default: `process.cwd()`)
- `agentDir?: string` — global config dir (default: `~/.pi/agent`)
- `authStorage?: AuthStorage` — credential storage
- `modelRegistry?: ModelRegistry` — model/API-key resolution
- `model?: Model<any>` — model to use (default: from settings or first available)
- `thinkingLevel?: ThinkingLevel` — `'low' | 'medium' | 'high'`
- `scopedModels?: Array<{ model; thinkingLevel? }>` — models for cycling
- `noTools?: "all" | "builtin"` — suppress default or all tools
- `tools?: string[]` — allowlist of enabled tool names
- `customTools?: ToolDefinition[]` — additional tools to register
- `resourceLoader?: ResourceLoader`
- `sessionManager?: SessionManager` — use `SessionManager.inMemory()` to skip disk I/O
- `settingsManager?: SettingsManager`
- `sessionStartEvent?: SessionStartEvent`

`CreateAgentSessionResult`:
- `session: AgentSession` — the live session object
- `extensionsResult: LoadExtensionsResult`
- `modelFallbackMessage?: string`

`AgentSession.prompt(text: string, options?: PromptOptions): Promise<void>` — sends a user turn. Subscribe to events via `session.subscribe(listener)` and watch for `agent_end` event; retrieve response via `session.getLastAssistantText()`.

Smoke test written but not executed (no `ANTHROPIC_API_KEY` in env). Next step to run: set `ANTHROPIC_API_KEY` and run `node /tmp/pi-research-r1/smoke-test.mjs`.

### Implication
Task 24 implements as designed in spec §5. The import path and signature match the pseudocode in the spec exactly. `SessionManager.inMemory()` (also exported from the package root) can be passed to avoid writing session files to disk during subagent spawns, which is useful for the task-tool extension.

## R2: Parallel session spawning

### Question
TODO

### Method
TODO

### Finding
TODO

### Implication
TODO

## R3: before_agent_start system-prompt mutability

### Question
TODO

### Method
TODO

### Finding
TODO

### Implication
TODO

## R4: pi --headless mode

### Question
TODO

### Method
TODO

### Finding
TODO

### Implication
TODO

## R5: Pi + Conductor compatibility (post-v1)

### Question
TODO

### Method
TODO

### Finding
TODO

### Implication
TODO
