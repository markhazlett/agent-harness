---
name: lg-cheatsheet
description: Quick reference for LangChain v1 / LangGraph v1 / Deep Agents — mental model, v1-current API surface, footgun list, deprecated patterns, JS/TS specifics, production checklist. Use when the user asks "what's the right way to do X in LangGraph", "how do streaming/checkpointers/HITL work", or any general LangGraph reference question. Other lg-* skills load this for shared context.
user-invocable: true
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

<langgraph-gate>
Run: `bash -c 'source "$(git rev-parse --show-toplevel)/.claude/hooks/harness.config.sh"; [ "$HARNESS_LANGGRAPH" = "true" ] && echo OK || echo OPT_IN_REQUIRED'`
- `OPT_IN_REQUIRED` → tell the user: "lg-* skills are opt-in. Run `./setup.sh` and answer 'yes' to LangGraph mode to enable." Then stop without doing the rest of the skill.
- `OK` → continue silently.
</langgraph-gate>

# LangGraph Cheatsheet

Quick reference for LangChain v1 / LangGraph v1 / Deep Agents (TS/JS). For each topic: what it is, the v1-current API, the idiomatic shape, and the load-bearing footguns.

## 1. Mental Model

LangGraph v1 is a three-layer stack. Understanding which layer owns what prevents the most common architecture mistakes.

**Layer 1 — LangChain framework** (`langchain`, `@langchain/core`): Models, tools, messages, structured output, middleware, observability. The "what the agent does."

**Layer 2 — LangGraph runtime** (`@langchain/langgraph`): State machines, graph compilation, persistence (checkpointers), streaming, HITL. The "how the agent runs."

**Layer 3 — Deep Agents harness** (`deepagents`): Opinionated orchestration for long-horizon planning agents. Adds virtual FS, sub-agent coordination, `write_todos` planning loop, prompting conventions. Built on top of LangGraph — not a replacement.

**Observability layer** — LangSmith sits orthogonal to all three. It traces runs but is never required for code to execute.

Decision rule: start at Layer 1 (`createAgent`). Drop to Layer 2 (raw `StateGraph`) only when you need custom topology, non-message state, or fine-grained branching. Layer 3 (`createDeepAgent`) only for long-horizon multi-step planning with sub-agents.

## 2. The v1-Current API Surface

v1 broke several pre-v1 patterns. Know these before reading any older tutorial.

**`createAgent` from `langchain`** — the primary high-level API. Replaces `createReactAgent` from `@langchain/langgraph/prebuilt` and all `AgentExecutor` patterns. Accepts: `model`, `tools`, `checkpointer`, `middleware`, `structuredOutput`, `context`.

```typescript
import { createAgent } from "langchain";
import { MemorySaver } from "@langchain/langgraph";

const agent = createAgent({
  model: chatModel,           // NOT pre-bound with .bindTools()
  tools: [searchTool, calcTool],
  checkpointer: new MemorySaver(),
  middleware: [summarizationMiddleware({ maxTokens: 4000 })],
  // structuredOutput: MyZodSchema,  // provider-native structured output
});
```

Key v1 changes:
- **Do not pre-bind tools** — pass raw tools array to `createAgent`, it handles binding internally. Pre-binding breaks structured output.
- **`message.contentBlocks`** — provider-agnostic typed view of message content (replaces `.content` string hacks for multi-modal).
- **Stream event node name** — node renamed `"agent"` → `"model"` in `streamEvents`. Update any FE consumers.
- **`context` parameter** — replaces `config.configurable` for passing app-level state through to nodes.
- **Middleware is the extensibility surface** — don't monkey-patch nodes; use `wrapModelCall`, `wrapToolCall`, `beforeAgent`, `afterAgent` hooks.

## 3. State + Reducers

State is defined via `Annotation.Root`. Every channel needs an explicit reducer or it silently overwrites on parallel node execution.

```typescript
import { Annotation, MessagesAnnotation } from "@langchain/langgraph";

const State = Annotation.Root({
  // Spread MessagesAnnotation.spec for the standard append+dedup message channel
  ...MessagesAnnotation.spec,
  // Custom channels — always declare a reducer for anything that can be written concurrently
  urls: Annotation<string[]>({
    reducer: (existing, incoming) => [...new Set([...existing, ...incoming])],
    default: () => [],
  }),
  status: Annotation<string>({
    reducer: (_, incoming) => incoming,  // explicit last-write-wins
    default: () => "idle",
  }),
});

// Use these types for node signatures — don't use `any`
type StateType = typeof State.State;
type UpdateType = typeof State.Update;
```

- **Default reducer = overwrite** — if you omit the reducer, the channel takes the last write. Fatal for arrays and sets in parallel subgraphs.
- **`MessagesAnnotation.spec`** — provides append semantics + message ID deduplication for the `messages` channel. Spread it, don't reimplement it.
- **`typeof State.State`** — full state shape for node inputs.
- **`typeof State.Update`** — partial update shape for node return values.

## 4. Streaming Map

LangGraph exposes multiple streaming modes. Pick the right ones for your use case; multiplexing is cheap.

| Mode | What you get | When to use |
|---|---|---|
| `values` | Full state snapshot after each superstep | Debugging, simple FE state sync |
| `updates` | Delta per node per superstep | Efficient FE updates |
| `messages` | Token-level AIMessage chunks | Chat streaming |
| `messages-tuple` | `[message, metadata]` pairs | When you need node provenance per token |
| `custom` | Anything you `streamWriter.write()` | Progress events, custom payloads |
| `debug` | Internal LangGraph execution events | Deep debugging only |
| `events` | LangChain runnable events | Cross-layer observability |
| `tasks` | Superstep task list | Parallel execution visibility |
| `checkpoints` | Checkpoint writes | Persistence debugging |

**Recommended FE pattern** — multiplex `["messages", "updates"]`:

```typescript
const stream = await graph.stream(input, {
  streamMode: ["messages", "updates"],
  subgraphs: true,  // required to surface child graph token streams
});

for await (const [mode, chunk] of stream) {
  if (mode === "messages") { /* token chunks */ }
  if (mode === "updates") { /* node output deltas */ }
}
```

**React FE** — use `useStream` from `@langchain/langgraph` (handles SSE + reconnect).

`subgraphs: true` is load-bearing when any subgraph exists — without it, child token streams are swallowed.

## 5. Tools

Tools are defined with `tool()` + Zod. `ToolNode` handles parallel execution. Error mode is configurable.

```typescript
import { tool } from "@langchain/core/tools";
import { ToolNode, tools_condition } from "@langchain/langgraph/prebuilt";
import { z } from "zod";

const searchTool = tool(
  async ({ query }) => {
    // implementation
    return results;
  },
  {
    name: "search",
    description: "Search the web for current information. Accepts a natural language query.",
    schema: z.object({
      query: z.string().describe("The search query"),
    }),
  }
);

// In a raw StateGraph:
const toolNode = new ToolNode(tools);  // parallel by default
graph
  .addNode("tools", toolNode)
  .addConditionalEdges("model", tools_condition);
```

- **`ToolNode` is parallel by default** — all tool calls in a single AIMessage fire concurrently.
- **Error mode** — `new ToolNode(tools, { handleToolErrors: "continue" })` swallows errors back into messages; `"error"` throws; custom function for fine-grained handling.
- **Tool descriptions matter** — the model reads them. Minimum one full sentence. Mention the output format.
- **Don't pre-bind** — do not call `model.bindTools(tools)` before passing to `createAgent`. Let `createAgent` handle binding.

## 6. Persistence + Memory Three-Layer Model

Three distinct layers, each solves a different problem.

**Layer 1 — Checkpointer (per-thread)**
Saves full graph state at each superstep. Enables resume, HITL, time-travel. `MemorySaver` for dev/test; use a durable backend in production.

```typescript
import { MemorySaver } from "@langchain/langgraph";
import { PostgresSaver } from "@langchain/langgraph-checkpoint-postgres";
import { SqliteSaver } from "@langchain/langgraph-checkpoint-sqlite";

// Dev
const checkpointer = new MemorySaver();

// Prod (Postgres)
const checkpointer = PostgresSaver.fromConnString(process.env.DATABASE_URL!);
await checkpointer.setup();  // run once to create tables

// invoke always pass thread_id
const result = await graph.invoke(input, { configurable: { thread_id: userId } });
```

**Layer 2 — BaseStore (cross-thread)**
Key-value store for facts that span threads (user preferences, long-term memory, shared knowledge). Namespaced.

```typescript
// In a node, access via config.store
async function memoryNode(state: StateType, config: RunnableConfig) {
  const store: BaseStore = config.store!;
  const userFacts = await store.get(["users", config.configurable!.userId], "facts");
  await store.put(["users", config.configurable!.userId], "facts", { ...userFacts, ...newFacts });
}
```

**Layer 3 — summarizationMiddleware (message length)**
Trims the messages channel before it hits the context window limit. Applied as middleware in `createAgent`.

- `MemorySaver` is in-process and lost on serverless cold start — a fatal production mistake.
- Available prod checkpointers: `PostgresSaver`, `SqliteSaver`, `RedisSaver`, `MongoSaver`.

## 7. HITL — Human in the Loop

`interrupt()` pauses graph execution at a node boundary and waits for a `Command` resume.

```typescript
import { interrupt, Command } from "@langchain/langgraph";

// In a node — pause execution and surface a value to the caller
async function reviewNode(state: StateType) {
  const decision = interrupt({
    question: "Approve this action?",
    payload: state.pendingAction,
  });
  // Execution resumes here when Command({ resume: value }) is sent
  return { approved: decision === "yes" };
}

// Caller resumes:
const result = await graph.invoke(
  new Command({ resume: "yes" }),
  { configurable: { thread_id: "thread-1" } }
);
```

**Multi-interrupt** — if multiple `interrupt()` calls fire, resume with a map keyed by interrupt ID.

**Node-restart footgun** — when resuming, the node that contained `interrupt()` re-executes from the top. Any side effects (API calls, writes) before the `interrupt()` call will fire again. Guard them:

```typescript
async function reviewNode(state: StateType) {
  if (!state.emailSent) {
    await sendEmail(state.draft);  // only fires on first pass
  }
  const decision = interrupt({ question: "Approve?" });
  return { approved: decision === "yes" };
}
```

`humanInTheLoopMiddleware` from `langchain` is the `createAgent`-compatible shortcut — adds interrupt at tool-call boundaries without dropping to raw `StateGraph`.

## 8. Multi-Agent Patterns

LangGraph supports several multi-agent topologies. Pick based on coordination needs.

```typescript
import { createSupervisor } from "@langchain/langgraph-supervisor";
import { createSwarm, createHandoffTool } from "@langchain/langgraph-swarm";
import { Send, Command } from "@langchain/langgraph";

// Supervisor pattern — one coordinator routes to specialized agents
const supervisor = createSupervisor({
  agents: [researchAgent, writerAgent, reviewerAgent],
  model: coordinatorModel,
});

// Swarm pattern — peer-to-peer handoffs via tool calls
const handoff = createHandoffTool({ agent: writerAgent, name: "hand_to_writer" });
const researchAgent = createAgent({ model, tools: [...tools, handoff] });

// Parallel fanout with Send
function routerNode(state: StateType) {
  return state.urls.map(url => new Send("scraper", { url }));
}

// Direct handoff inside a node
function coordinatorNode(state: StateType) {
  if (needsResearch(state)) {
    return new Command({ goto: "research_agent", update: { task: state.query } });
  }
}
```

- **`createSupervisor`** — best when one agent decides routing. Agents are opaque to each other.
- **`createSwarm` / `createHandoffTool`** — best when agents need peer-to-peer handoff. More flexible, less centralized.
- **`Send`** — parallel fanout to the same node with different payloads. `Send` payload must match the target node's input, not the parent state.
- **`Command({ goto })`** — unconditional jump from inside a node. Useful for dynamic routing.

## 9. Subgraphs

Subgraphs are compiled graphs used as nodes inside a parent graph. State merging is automatic for shared channel keys.

```typescript
const parentGraph = new StateGraph(ParentState)
  .addNode("child", childGraph)  // compiled subgraph as node
  .addEdge("parent_start", "child")
  .addEdge("child", "parent_end");
```

- **Shared-key auto-merge** — channels with the same name in parent and child state are automatically synchronized at the boundary.
- **Subgraph streaming requires `subgraphs: true`** on every `stream()` / `getState()` / `updateState()` call. Missing it silently drops child stream events.
- **`getState()` with subgraphs** — call `graph.getState(config, { subgraphs: true })` to see child checkpoints.
- Subgraph state is independently checkpointed — each has its own checkpoint namespace under the parent thread.

## 10. Time Travel

LangGraph checkpoints are immutable. Time travel is replay or fork — not in-place mutation.

```typescript
// List checkpoints for a thread
const history = [];
for await (const checkpoint of graph.getStateHistory(config)) {
  history.push(checkpoint);
}

// Replay from a past checkpoint (read-only re-execution)
const replayConfig = { configurable: { thread_id: "t-1", checkpoint_id: checkpointId } };
const result = await graph.invoke(null, replayConfig);

// Fork — update state at a past checkpoint and run forward
await graph.updateState(replayConfig, { status: "corrected" });
const forkedResult = await graph.invoke(null, replayConfig);
```

- **History is immutable** — `updateState` creates a new checkpoint that forks from the target; original checkpoints are preserved.
- **Checkpoint replay vs fork** — replay re-runs nodes from a past point with original inputs; fork applies a state edit then runs forward.
- Time travel requires a durable checkpointer — `MemorySaver` loses history on process restart.

## 11. Deep Agents

`deepagents` is an opinionated harness for long-horizon agents. Use it when you need planning loops, sub-agents, and virtual FS — not for simple tool-using agents.

```typescript
import { createDeepAgent } from "deepagents";

const agent = createDeepAgent({
  model: chatModel,
  tools: [searchTool, codeTool],
  systemPrompt: mySystemPrompt,
  subAgents: [
    { name: "researcher", agent: researcherAgent },
    { name: "validator", agent: validatorAgent },  // v0.5: async sub-agents
  ],
  middleware: [todoListMiddleware(), summarizationMiddleware({ maxTokens: 8000 })],
  recursionLimit: 200,  // ALWAYS set explicitly — default is 10000
  fsBackend: new StoreBackend(store),  // cross-thread; use Filesystem or Sandbox for true FS
});
```

**Four pillars of Deep Agents:**
1. **Planning** — `write_todos` tool; agent plans before acting, ticks off tasks as it works.
2. **Sub-agents** — `task` tool; delegates to specialized sub-agents. v0.5 supports async sub-agents.
3. **Virtual FS** — file read/write abstracted behind a backend interface.
4. **Opinionated prompting** — system prompt conventions that keep the planning loop stable.

**FS backends:**
- `StateBackend` — ephemeral, in-graph state. Lost on serverless cold start.
- `StoreBackend` — cross-thread via `BaseStore`. Survives restarts if backed by Postgres/Redis.
- `Filesystem` — real local FS. Fine for local dev.
- `Sandbox` — Daytona / Deno Deploy / Modal for isolated execution.

**`recursionLimit`** — leave at default (10000) and a runaway agent will exhaust your budget before hitting the limit. Set it to a real budget (50-500 depending on task complexity).

## 12. LangSmith Setup

LangSmith traces runs for debugging, evaluation, and collaboration. It is never required for code to execute.

```bash
# .env — set these to enable tracing
LANGSMITH_TRACING=true
LANGSMITH_API_KEY=ls__...
LANGSMITH_PROJECT=my-agent

# CRITICAL for serverless (Lambda, Cloud Functions, Vercel):
LANGCHAIN_CALLBACKS_BACKGROUND=false
# Without this, the process exits before async trace uploads complete → lost traces
```

```typescript
import { traceable } from "langsmith";

// Wrap any function to add it as a custom span in traces
const myCustomStep = traceable(
  async (input: string) => { /* ... */ },
  { name: "my-custom-step", runType: "chain" }
);
```

**When you actually need it:**
- **Required for code to run:** never. Code runs cleanly with the env vars unset.
- **Required for evals:** depends on mode (`/lg-eval` supports local-only Vitest/Jest mode without LangSmith; LangSmith-backed and hybrid modes need it).
- **Recommended:** any multi-step agent with 5+ tool calls, all Deep Agents (the docs ship a `langsmith fetch` CLI specifically because Deep Agent traces are too long to read manually), production debugging, team collaboration, regression eval over weeks of iteration.
- **Not needed:** 2-tool prototype agents, throwaway scripts, single-shot LLM calls.

Import path: `langsmith` for `traceable`; `langsmith/evaluation` for `evaluate()` and `LLMEvaluator`.

## 13. Evals

LangSmith evals follow a dataset + target + evaluator pattern. Trajectory checks verify tool-call ordering, not just final output.

```typescript
import { evaluate } from "langsmith/evaluation";
import { Client } from "langsmith";

const client = new Client();

// Dataset: array of { input, reference } examples
const dataset = await client.createDataset("my-agent-evals");
await client.createExamples({ datasetId: dataset.id, inputs: [...], outputs: [...] });

// Evaluator — pure function, same shape for local and LangSmith-backed modes
function trajectoryEvaluator(run: Run, example: Example) {
  const toolCalls = run.outputs?.messages
    ?.flatMap((m: any) => m.tool_calls ?? [])
    .map((tc: any) => tc.name);
  const hasSearch = toolCalls?.includes("search");
  return { key: "has_search", score: hasSearch ? 1 : 0 };
}

// Run the evaluation
const results = await evaluate(
  (input) => agent.invoke(input),
  { data: dataset.name, evaluators: [trajectoryEvaluator], experimentPrefix: "v1-baseline" }
);
```

**Eval modes (pick at `/lg-eval` time):**
- **Local-only** — Vitest/Jest assertions, inline fixtures in `evals/datasets/<slug>.ts`, no upload. CI-safe without secrets.
- **LangSmith-backed** — datasets in dashboard, experiment tracking, online evals against prod traces.
- **Hybrid** — local fixtures committed to git, `pnpm eval:sync` mirrors to LangSmith. Both modes run against the same evaluators.

**Trajectory checks** parse `run.outputs.messages` for `tool_calls` and verify call ordering, required tool presence, or tool absence. More signal than final-answer checks alone.

## 14. Top 10 Footguns

These are the mistakes that waste hours. Memorize them.

- **Reducer omission → silent overwrite.** Any channel without a reducer takes the last write in a parallel superstep. Arrays silently replace instead of append.
- **Node-restart on resume → pre-interrupt side effects double-fire.** Code before `interrupt()` in a node re-runs on resume. Guard external writes with state flags.
- **`MemorySaver` lost on serverless cold start.** In-process memory doesn't survive Lambda/Cloud Run container recycling. Use Postgres/Sqlite/Redis in prod.
- **Subgraph streaming requires `subgraphs: true`.** Without it, child graph token streams are silently dropped. Applies to `stream()`, `getState()`, and `updateState()`.
- **`Send` payload ≠ parent state.** `Send("node", payload)` delivers payload as the node's input — it must match the target node's expected state shape, not the parent's.
- **Pre-binding tools breaks structured output.** Calling `model.bindTools(tools)` then passing the bound model to `createAgent` collides with `createAgent`'s own tool binding. Pass raw tools only.
- **Missing `subgraphs: true` on `getState()`.** `graph.getState(config)` without `{ subgraphs: true }` returns parent state only — child checkpoint state invisible.
- **Unbounded `recursionLimit` in Deep Agents.** Default is 10000. A planning loop bug will burn your entire LLM budget before hitting the limit. Set explicitly (50-500).
- **Deep Agent FS persistence — `StateBackend` is ephemeral.** `StateBackend` stores files in graph state — lost on cold start. Use `StoreBackend` (Postgres-backed) or `Filesystem` for anything that must survive.
- **Message ID dedup in `MessagesAnnotation`.** Re-sending a message with the same `id` replaces the existing message rather than appending. Use unique IDs or let the framework generate them.
- **Serverless `LANGCHAIN_CALLBACKS_BACKGROUND=true` losing traces.** The default (`true`) uploads traces async — the process exits before upload completes. Set `LANGCHAIN_CALLBACKS_BACKGROUND=false` in any serverless environment.

## 15. Deprecation List

These patterns are gone in v1. `/lg-review` will flag them; here's the full list.

- `createReactAgent` from `@langchain/langgraph/prebuilt` → use `createAgent` from `langchain`.
- `AgentExecutor`, `initializeAgentExecutorWithOptions`, `createOpenAIFunctionsAgent` from `langchain/agents` → `createAgent`.
- `langchain/chains` (legacy) → moved to `@langchain/classic/chains`.
- LCEL pipe-chains for agentic flows → `createAgent` + middleware.
- `dist/` direct imports → public entrypoints only (bundler output changed in v1).
- `MemorySaver` in production → swap for `Postgres`/`Sqlite`/`Redis`/`Mongo` saver.
- `config.configurable` for app-state → use new `context` parameter.
- Legacy `./callbacks` entrypoint → use Runnable observability.

## 16. Production Checklist

Wire these from day 1, not as an afterthought before launch.

**Resilience:**
- [ ] Retry config on all tool calls that hit external systems (`RetryOptions` in tool config).
- [ ] Fallback model for production LLM calls (`model.withFallbacks([cheaperModel])`).
- [ ] Rate-limit middleware if tools share an API key.
- [ ] Error handling: `ToolNode` error mode set to `"continue"` unless you want throws.

**Persistence:**
- [ ] Durable checkpointer (not `MemorySaver`) — `PostgresSaver` or `SqliteSaver`.
- [ ] `await checkpointer.setup()` run exactly once at deploy time.
- [ ] `thread_id` strategy documented and implemented (per-user, per-session, per-request?).
- [ ] `BaseStore` for any cross-thread data (user facts, shared knowledge).

**Structured output:**
- [ ] Use provider-native structured output where available (faster, cheaper, more reliable than JSON-mode prompting).
- [ ] Validate structured output with Zod at the boundary — don't trust raw model output.

**Observability:**
- [ ] `LANGSMITH_TRACING=true` and `LANGSMITH_API_KEY` in prod environment (or accept blind spots).
- [ ] `LANGCHAIN_CALLBACKS_BACKGROUND=false` if deploying to serverless.
- [ ] `traceable()` on any hot-path custom logic you'll want to debug.

**HITL (if applicable):**
- [ ] Idempotency guards on any pre-interrupt side effects.
- [ ] Resume handler tested with multi-interrupt scenarios.
- [ ] Timeout / expiry strategy for long-running interrupt waits.

**Deep Agents (if applicable):**
- [ ] `recursionLimit` set to a real budget (not left at 10000).
- [ ] FS backend chosen deliberately (`StoreBackend` for durability, not `StateBackend`).
- [ ] Async sub-agents configured if tasks can parallelize (v0.5+).

**Caching:**
- [ ] Prompt caching enabled if using Claude models (saves cost on long system prompts).
- [ ] Tool result caching for expensive/slow external calls where staleness is acceptable.

## 17. Refresh Hint

Last verified: 2026-04-26 against LangGraph v1.x / LangChain v1 / deepagents v0.5.

To refresh:
- https://github.com/langchain-ai/langgraphjs/releases
- https://github.com/langchain-ai/langchainjs/releases
- https://github.com/langchain-ai/deepagentsjs/releases
- https://docs.langchain.com/oss/javascript/releases/changelog
