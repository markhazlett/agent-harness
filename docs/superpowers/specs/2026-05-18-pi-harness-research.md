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
Can two `createAgentSession()` calls in Promise.all run in parallel, or does the SDK internally serialize them?

### Method
Type-only and source-only inspection (no live smoke test — ANTHROPIC_API_KEY not available in research environment). Read `dist/core/sdk.d.ts` and `dist/core/sdk.js` (the `createAgentSession` implementation). Also read `dist/core/agent-session.js` (the `AgentSession` class and its `prompt()` method), `dist/core/tools/file-mutation-queue.js` (the only queue/lock mechanism found), and `dist/core/session-manager.js`. Searched for `Mutex`, `Semaphore`, `p-queue`, `p-limit`, `serialize`, `lock`, `singleton`, `global` across the entire `dist/` tree.

### Finding
Likely parallel: `createAgentSession` creates a fresh, independent runtime per call. No module-level locks, mutexes, or queues were found that could serialize concurrent sessions.

Specific evidence:

1. **`dist/core/sdk.js` lines 83–281**: `createAgentSession` is a plain `async function` with no module-level state. Every call creates its own `AuthStorage`, `ModelRegistry`, `SettingsManager`, `SessionManager`, `DefaultResourceLoader`, and `Agent` instance from scratch. Nothing is shared between calls.

2. **`dist/core/agent-session.js` line 55** (only module-level constant): `const THINKING_LEVELS = ["off", "minimal", "low", "medium", "high"]` — an immutable constant, not a lock.

3. **`dist/core/tools/file-mutation-queue.js` line 3**: `const fileMutationQueues = new Map()` — this is a module-level singleton, but it only serializes mutations *to the same file path*, not sessions. Two concurrent sessions writing to different files run in parallel. Two sessions writing to the same file would serialize their writes against each other (correct behavior, not a session bottleneck).

4. **`AgentSession.prompt()` (`dist/core/agent-session.js` lines 697–817)**: No internal mutex or lock on the method itself. Each `AgentSession` instance holds its own `this.agent` (an `Agent` instance), so two sessions calling `prompt()` concurrently call `this.agent.prompt()` on different objects with no shared state.

5. **Grep for `Mutex|Semaphore|p-queue|p-limit|serialize|lock`** across all of `dist/`: no results in session-creation or prompt-dispatch paths.

The one caveat: if two sessions share the same `cwd` and both call built-in file-mutation tools (edit/write) on the same file simultaneously, `withFileMutationQueue` will serialize those file ops (correct behavior). Sessions operating on different working directories or different files are fully independent.

### Implication
Task 24 supports parallel task calls in v1 as designed in spec §5. Two `createAgentSession({ sessionManager: SessionManager.inMemory(), cwd: taskCwd })` calls in `Promise.all` will run concurrently — each has its own provider client, agent state, and session — with no SDK-level serialization. If a future live smoke test reveals unexpected serialization (e.g., from provider-side rate limiting), that is a network-layer concern, not an SDK architecture constraint.

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
