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
Can a Pi extension's `before_agent_start` handler mutate the system prompt or inject messages? If not, what's the alternative for context injection at session start?

### Method
Type-only inspection of `@earendil-works/pi-coding-agent` v0.75.3. Examined:
- `dist/core/extensions/types.d.ts` — event interface definitions, result types, and `ExtensionAPI.on()` overloads
- `dist/core/extensions/runner.js` lines 700–754 — `emitBeforeAgentStart()` implementation showing how handler return values are processed
- `dist/core/agent-session.js` lines 783–810 — how the combined result is applied to `this.agent.state.systemPrompt`

### Finding

**Handler receives** (`BeforeAgentStartEvent`, `types.d.ts` lines 468–478):
```typescript
interface BeforeAgentStartEvent {
  type: "before_agent_start";
  prompt: string;              // raw user prompt text (after expansion)
  images?: ImageContent[];     // attached images, if any
  systemPrompt: string;        // the fully assembled system prompt string
  systemPromptOptions: BuildSystemPromptOptions;  // structured options used to build it
}
```

**Handler return type** (`BeforeAgentStartEventResult`, `types.d.ts` lines 735–739):
```typescript
interface BeforeAgentStartEventResult {
  message?: Pick<CustomMessage, "customType" | "content" | "display" | "details">;
  /** Replace the system prompt for this turn. If multiple extensions return this, they are chained. */
  systemPrompt?: string;
}
```

The return type is **not void** — it has two optional fields:
1. `systemPrompt?: string` — fully replaces the system prompt for the turn. Multiple extensions returning this are chained (each sees the previous extension's modified prompt as `event.systemPrompt`).
2. `message?` — injects a custom message into the session before the agent turn. Appears in the session history as a `"custom"` role entry.

**Runtime behaviour** (`runner.js` lines 700–754): The runner iterates all `before_agent_start` handlers. If `result.systemPrompt !== undefined`, it sets `currentSystemPrompt = result.systemPrompt` and passes that updated value in `event.systemPrompt` to the next extension. The final `currentSystemPrompt` is returned in `BeforeAgentStartCombinedResult`.

**Application** (`agent-session.js` lines 783–810): After `emitBeforeAgentStart()` returns, if `result?.systemPrompt` is truthy, `this.agent.state.systemPrompt = result.systemPrompt` — the session's live system prompt is replaced for that turn. On the next turn, unless an extension overrides again, it resets to `this._baseSystemPrompt`.

**Key limitation:** `systemPrompt` is a full replacement, not an append. Extensions must read `event.systemPrompt` (the current value) and return it with additions concatenated:
```typescript
pi.on("before_agent_start", (event, ctx) => {
  const injection = buildContextBlock(); // branch, commits, diff, handoff
  return { systemPrompt: event.systemPrompt + "\n\n" + injection };
});
```

**Alternative path for injecting user-visible messages:** Return `{ message: { customType: "harness-context", content: [...], display: "..." } }`. This adds a `custom`-role entry to the session's message list (visible in UI, stored in session file, but not sent to LLM as a `"user"` message). This is suitable for showing handoff state to the user but not for LLM context injection.

Cited files and lines:
- `types.d.ts` lines 468–478 (`BeforeAgentStartEvent`)
- `types.d.ts` lines 735–739 (`BeforeAgentStartEventResult`)
- `types.d.ts` line 796 (`ExtensionAPI.on("before_agent_start", ...)` overload)
- `runner.js` lines 700–754 (`emitBeforeAgentStart` implementation, chaining logic)
- `agent-session.js` lines 783–810 (result application to `this.agent.state.systemPrompt`)

### Implication for Tasks 18 (init) and 19 (context-reinject)

**Use `before_agent_start` with `return { systemPrompt: event.systemPrompt + "\n\n" + injection }`.** This is the correct mechanism for both tasks.

- **Task 18 (init):** Register a `before_agent_start` handler in `hooks/pi/init/index.ts`. On first startup (`reason === "startup"` in `session_start`), build the context block (branch, recent commits, uncommitted diff, prior-session handoff note) and return `{ systemPrompt: event.systemPrompt + "\n\n---\n" + contextBlock }`. The system prompt is replaced for that turn only; subsequent turns reset to the base prompt, which is correct behaviour (the injected context is already in the LLM's context window from the first turn).

- **Task 19 (context-reinject):** Register a `session_compact` handler (for compaction) and use `session_start` with `reason === "resume"` to catch session reload. After compaction, Pi re-runs the agent with the compacted context; use `before_agent_start` to re-inject the current branch/diff/handoff block into the system prompt for the first post-compaction turn.

**Do not use `pi.sendUserMessage()` for context injection.** That sends a synthetic user turn and triggers a new agent loop — it would cause spurious turns and double-count context.

**Do not use `return { message: ... }` for LLM context injection.** Custom messages are not sent to the LLM as `user` or `system` content; they are session log entries for UI display only.

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
