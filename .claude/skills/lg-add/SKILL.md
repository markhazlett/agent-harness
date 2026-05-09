---
name: lg-add
description: Use when the user says "add HITL to my agent", "make this graph durable", "wire streaming", "add a sub-agent", "attach a checkpointer", or any "add X to my LangGraph" phrasing. Adds capabilities to an existing LangGraph agent — HITL, persistence, streaming, sub-agents, custom tools, middleware, or BaseStore.
user-invocable: true
tier: flexible
kind: implementation
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

# /lg-add <capability>

Targeted modifier for an existing LangGraph agent. Reads the existing graph file(s), detects the pattern in use (`createAgent` / raw `StateGraph` / Deep Agent), then runs the capability-specific playbook. Makes precise edits with the `Edit` tool, extends tests, and runs them. Each capability is a focused workflow — not exhaustive docs.

## Phase 0: Load shared context

Invoke the `/lg-cheatsheet` skill via the `Skill` tool. This locks the v1-current API surface — `createAgent` from `langchain`, `StateSchema`/`MessagesValue`, `INTERRUPT` symbol, full middleware hook set, `backend` parameter — for all edits below.

## Phase 1: Identify target

Three invocation forms:

- **`/lg-add <capability> <path>`** — both args explicit; skip prompts.
- **`/lg-add <capability>`** — capability known; glob `src/**/{graph,index}.ts` for existing graphs. If exactly one match, use it. If multiple, ask the user to pick.
- **`/lg-add`** — ask both: which capability? which graph file?

Valid capabilities: `hitl` | `persist` | `stream` | `subagent` | `tool` | `middleware` | `store`.

If the user passes an unrecognized capability, list the seven and ask them to pick one.

## Phase 2: Read target graph

Read the target file(s). Extract:

- **Pattern** — `createAgent` (import from `langchain`), `StateGraph` (raw), or Deep Agent (`createDeepAgent` from `deepagents`). Detect by import paths and exported value shape.
- **State schema** — channels and reducers (if `StateGraph` pattern).
- **Existing nodes** — node names and responsibilities.
- **Existing checkpointer** — look in `compile({ checkpointer })` or `createAgent({ checkpointer })`.
- **Existing middleware** — look in `createAgent({ middleware })` array or `createDeepAgent({ middleware })`.

**Deprecated pattern warning:** If `createReactAgent` from `@langchain/langgraph/prebuilt` is imported, print:

> "This graph still uses the legacy `createReactAgent`. Recommend running `/lg-review` first to migrate to `createAgent` from `langchain` before adding more capabilities."

Don't block — user may have a reason. Continue with the capability switch.

## Phase 3: Capability switch

Branch on `<capability>`. Each sub-section is a self-contained playbook.

### 3.1 hitl — Human-in-the-loop

**createAgent path:**

Add `humanInTheLoopMiddleware` from `langchain` to the `middleware` array. Provide a config callback that decides which tool calls to gate. Default: gate all tool calls.

```ts
import { humanInTheLoopMiddleware } from "langchain";

const agent = createAgent({
  model,
  tools,
  middleware: [
    humanInTheLoopMiddleware({
      // Return true to require human approval before this tool call executes.
      shouldInterrupt: ({ toolCall }) => true,
    }),
  ],
  checkpointer,
});
```

**StateGraph path:**

Insert `interrupt()` from `@langchain/langgraph` at the appropriate node (typically before an external side-effect — email send, DB write, API call). If no checkpointer is present in the graph, block: tell the user to run `/lg-add persist` first (interrupt requires a checkpointer to save state across the pause).

Generate the resume handler using `INTERRUPT` symbol + `isInterrupted()`:

```ts
import { interrupt, Command, INTERRUPT, isInterrupted } from "@langchain/langgraph";

// In the node that needs approval:
const reviewNode = async (state: StateType) => {
  const approval = interrupt({ message: "Approve this action?", data: state.pendingAction });
  // Execution pauses here. Resume resumes from this line.
  return { approved: approval };
};

// At the call site, after invoke:
const result = await graph.invoke(input, config);
if (isInterrupted(result)) {
  const resumeMap: Record<string, unknown> = {};
  for (const i of result[INTERRUPT]) {
    if (i.id != null) resumeMap[i.id] = await getHumanResponse(i.value);
  }
  await graph.invoke(new Command({ resume: resumeMap }), config);
}
```

**Idempotency note (print verbatim):**

> "**Idempotency note:** pre-interrupt code re-runs on resume. Guard external side effects (HTTP calls, DB writes, email sends) with idempotency keys, or move them after `interrupt()`."

### 3.2 persist — Checkpointer

Ask the user which checkpointer to use:

| Option | Use case | Package |
|---|---|---|
| `MemorySaver` | Local dev only — lost on restart/cold start | ships with `@langchain/langgraph` |
| `SqliteSaver` | Single-process / long-running server | `@langchain/langgraph-checkpoint-sqlite` |
| `PostgresSaver` | Production, multi-process | `@langchain/langgraph-checkpoint-postgres` |
| `RedisSaver` | Production, low-latency sessions | `@langchain/langgraph-checkpoint-redis` |

Generate the install command using `$HARNESS_PKG_MGR` (read from `harness.config.sh`). Skip the install line for `MemorySaver`.

**createAgent path:**
```ts
import { PostgresSaver } from "@langchain/langgraph-checkpoint-postgres";

const checkpointer = PostgresSaver.fromConnString(process.env.DATABASE_URL!);
await checkpointer.setup(); // once at boot — idempotent

const agent = createAgent({ model, tools, checkpointer });
```

**StateGraph path:**
```ts
const compiled = graph.compile({ checkpointer });
```

After wiring the checkpointer, scan all call sites for `agent.invoke(...)` / `graph.invoke(...)`. If any are missing `{ configurable: { thread_id: "<value>" } }`, show the user where they are and add the `thread_id` field. A missing `thread_id` means every invocation overwrites the same thread — common footgun.

### 3.3 stream — Streaming

Detect the frontend shape from `package.json` dependencies: look for `next`, `express`, `fastify`, `react`. If none detected, ask the user which framework they're targeting.

Default stream mode: multiplex `["messages", "updates"]`.

If the graph has subgraphs (any `.addNode` call passing a compiled sub-graph, or Deep Agent `subAgents` array), add `subgraphs: true` to the stream call.

**Next.js — route handler (`app/api/<slug>/route.ts`):**
```ts
import { compiled } from "@/src/agents/<slug>/graph"; // or agent

export async function POST(req: Request) {
  const { message, threadId } = await req.json();
  const stream = compiled.stream(
    { messages: [{ role: "user", content: message }] },
    {
      configurable: { thread_id: threadId },
      streamMode: ["messages", "updates"],
      // subgraphs: true, // uncomment if subgraphs present
    }
  );
  return new Response(
    new ReadableStream({
      async start(controller) {
        for await (const chunk of await stream) {
          controller.enqueue(new TextEncoder().encode(JSON.stringify(chunk) + "\n"));
        }
        controller.close();
      },
    }),
    { headers: { "Content-Type": "application/x-ndjson" } }
  );
}
```

**Express / Fastify — SSE route handler:**
```ts
import type { Request, Response } from "express";

export async function streamHandler(req: Request, res: Response) {
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");

  const stream = compiled.stream(
    { messages: [{ role: "user", content: req.body.message }] },
    {
      configurable: { thread_id: req.body.threadId },
      streamMode: ["messages", "updates"],
    }
  );

  for await (const chunk of await stream) {
    res.write(`data: ${JSON.stringify(chunk)}\n\n`);
  }
  res.end();
}
```

**React — `useStream` hook:**
```ts
import { useStream } from "@langchain/langgraph-sdk/react";

const { messages, startStream } = useStream({
  graphId: "<slug>",
  streamMode: ["messages", "updates"],
});
```

### 3.4 subagent — Sub-agents

**Deep Agent path (`createDeepAgent`):**

Add a `SubAgent` spec object to the `subAgents` array. Choose sync vs `AsyncSubAgent` based on expected duration:

- **Sync** (blocks parent until done): use for sub-second to seconds work — data lookup, formatting, validation.
- **AsyncSubAgent** (non-blocking via Agent Protocol): use for minutes+ work — web scraping, code execution, multi-step research.

```ts
import { createDeepAgent, StoreBackend } from "deepagents";

const agent = createDeepAgent({
  model,
  tools,
  subAgents: [
    {
      name: "researcher",
      description: "Searches and summarizes information from external sources. Use for any research task that requires fetching from the web.",
      instructions: "You are a research specialist. Be concise, cite your sources.",
      // For async: add { async: true } — sub-agent runs via Agent Protocol
    },
  ],
  backend,
});
```

**createAgent / StateGraph path:**

Scaffold a separate sub-graph file at `src/agents/<slug>/<subagent-name>/graph.ts`, then wire a supervisor edge in the parent. Use `createSupervisor` from `@langchain/langgraph-supervisor` if the coordination logic is standard routing. Use `Command({ goto })` inside a node for explicit handoff:

```ts
import { Command } from "@langchain/langgraph";

const routerNode = async (state: StateType) => {
  // decide which agent handles this
  return new Command({ goto: "researcherAgent" });
};
```

For parallel fanout across multiple sub-agents, use `Send`:
```ts
import { Send } from "@langchain/langgraph";

const fanoutNode = (state: StateType) =>
  state.tasks.map((task) => new Send("workerAgent", { task }));
```

### 3.5 tool — Custom tool

Ask the user:
- Tool name (snake_case, e.g. `search_web`)
- One-sentence description (matters — the model reads this to decide when to call it)
- Schema fields (name, type, optional description for each)

Generate in `tools.ts` (or inline in `graph.ts` if single-file):

```ts
import { tool } from "@langchain/core/tools";
import { z } from "zod";

export const searchWeb = tool(
  async ({ query, maxResults = 5 }) => {
    // implement: call your search API, return string result
    return `Results for "${query}": ...`;
  },
  {
    name: "search_web",
    description: "Search the web for current information. Use when the user asks about recent events, facts, or anything that may have changed since training.",
    schema: z.object({
      query: z.string().describe("The search query"),
      maxResults: z.number().optional().describe("Maximum number of results to return (default: 5)"),
    }),
  }
);
```

Wire into the agent's `tools` list. For `createAgent`, add to the `tools` array. For raw `StateGraph`, add to the `ToolNode` constructor and the model's tool list.

Generate `<tool-name>.test.ts` alongside:

```ts
import { describe, it, expect } from "vitest";
import { searchWeb } from "./tools";

describe("searchWeb tool", () => {
  it("returns a result for a valid query", async () => {
    const result = await searchWeb.invoke({ query: "LangGraph v1 release" });
    expect(typeof result).toBe("string");
    expect(result.length).toBeGreaterThan(0);
  });

  it("rejects an invalid schema", async () => {
    // @ts-expect-error — intentional schema violation
    await expect(searchWeb.invoke({ query: 42 })).rejects.toThrow();
  });
});
```

### 3.6 middleware — Middleware

Ask: prebuilt or custom?

**Prebuilt options (all from `langchain`):**

| Middleware | Import | What it does |
|---|---|---|
| `summarizationMiddleware` | `langchain` | Summarizes message history when it exceeds a token limit |
| `humanInTheLoopMiddleware` | `langchain` | Gates tool calls for human approval (see 3.1) |
| `todoListMiddleware` | `langchain` | Maintains a structured task list across the agent loop |

For PII redaction or rate-limit, scaffold custom middleware (see below).

Wire prebuilt middleware:
```ts
import { summarizationMiddleware } from "langchain";
import { ChatOpenAI } from "@langchain/openai";

const agent = createAgent({
  model,
  tools,
  middleware: [
    summarizationMiddleware({
      model: new ChatOpenAI({ model: "gpt-4o-mini" }), // cheap model for summaries
      maxTokens: 4000, // summarize when history exceeds this
    }),
  ],
  checkpointer,
});
```

**Custom middleware — scaffold with `createMiddleware`:**

Ask which hooks the user needs, then only fill in those hooks. Omit the rest.

```ts
import { createMiddleware } from "langchain";

export const myMiddleware = createMiddleware({
  beforeAgent: async (state, config) => {
    // Runs before the agent loop starts. Use for input validation, rate-limit checks.
  },
  beforeModel: async (state, config) => {
    // Runs before each model call. Use for injecting context, token counting.
  },
  wrapModelCall: async (state, config, next) => {
    // Wraps each model call. Use for retry logic, fallback models, latency tracking.
    return next(state, config);
  },
  wrapToolCall: async (state, config, next) => {
    // Wraps each tool call. Use for PII redaction, rate-limit enforcement, audit logging.
    return next(state, config);
  },
  afterModel: async (state, config) => {
    // Runs after each model call. Use for output filtering, token usage tracking.
  },
  afterAgent: async (state, config) => {
    // Runs after the agent loop completes. Use for cleanup, final audit log.
  },
});
```

Wire into the agent's `middleware` array.

### 3.7 store — BaseStore (cross-thread memory)

Ask: `InMemoryStore` (dev) or `PostgresStore` (prod)?

- `InMemoryStore`: ships with `@langchain/langgraph` — no install.
- `PostgresStore`: `@langchain/langgraph-checkpoint-postgres` — generate install command using `$HARNESS_PKG_MGR`.

Default namespace strategy: `["users", userId, "<facet>"]` — namespace by user, then by memory type (e.g. `"facts"`, `"preferences"`, `"history"`).

Wire the store:

```ts
import { InMemoryStore } from "@langchain/langgraph";
// import { PostgresStore } from "@langchain/langgraph-checkpoint-postgres"; // prod

const store = new InMemoryStore();

const agent = createAgent({
  model,
  tools,
  checkpointer,
  store, // inject at agent construction time
});

// Invoke with store in config:
const result = await agent.invoke(
  { messages: [{ role: "user", content: message }] },
  {
    configurable: { thread_id: threadId },
    store,
  }
);
```

Show how to read and write inside a node:

```ts
const node = async (state: StateType, config: RunnableConfig) => {
  const store = config.store;
  const userId = config.configurable?.userId ?? "anonymous";

  // Write a fact:
  await store.put(["users", userId, "facts"], "food-preference", { value: "vegetarian" });

  // Read it back:
  const fact = await store.get(["users", userId, "facts"], "food-preference");
  // fact?.value.value === "vegetarian"

  return state;
};
```

## Phase 4: Make edits

Use the `Edit` tool to apply the changes identified in Phase 3. Edit the minimum set of lines — targeted diffs, not rewrites. The post-edit hook re-runs Prettier automatically; no manual formatting needed.

If the capability requires a new file (e.g. a sub-graph, a `tools.ts` for a new tool, a route handler), use the `Write` tool for those and `Edit` for modifications to existing files.

## Phase 5: Update tests

Extend `graph.test.ts` with a smoke test for the new capability. If a separate test file is more appropriate (e.g. `<tool-name>.test.ts` for a new tool), generate that instead.

**Test shapes by capability:**

**hitl:**
```ts
it("pauses at interrupt and resumes with Command", async () => {
  const result = await graph.invoke(input, config);
  expect(isInterrupted(result)).toBe(true);

  const resumeMap: Record<string, unknown> = {};
  for (const i of result[INTERRUPT]) {
    if (i.id != null) resumeMap[i.id] = "approved";
  }
  const final = await graph.invoke(new Command({ resume: resumeMap }), config);
  expect(final.messages.at(-1)?.role).toBe("assistant");
});
```

**persist:**
```ts
it("maintains message history across two invocations with same thread_id", async () => {
  const config = { configurable: { thread_id: "persist-test-1" } };
  await agent.invoke({ messages: [{ role: "user", content: "My name is Alice" }] }, config);
  const result = await agent.invoke({ messages: [{ role: "user", content: "What is my name?" }] }, config);
  expect(result.messages.at(-1)?.content).toMatch(/alice/i);
});
```

**stream:**
```ts
it("yields at least one messages chunk", async () => {
  const chunks: unknown[] = [];
  for await (const chunk of await agent.stream(input, { streamMode: ["messages", "updates"] })) {
    chunks.push(chunk);
  }
  expect(chunks.length).toBeGreaterThan(0);
});
```

**subagent:**
```ts
it("invokes the sub-agent's capability", async () => {
  // Mock the sub-agent's external call; assert it fired.
  const result = await agent.invoke(input, config);
  expect(result.messages.some((m) => m.content?.includes("researcher"))).toBe(true);
});
```

**tool:** See the `tool.test.ts` generated in Phase 3 §3.5.

**middleware:**
```ts
it("middleware hook fires during invocation", async () => {
  let hookFired = false;
  const testMiddleware = createMiddleware({
    beforeAgent: async (state, config) => { hookFired = true; },
  });
  const testAgent = createAgent({ model, tools, middleware: [testMiddleware], checkpointer });
  await testAgent.invoke(input, config);
  expect(hookFired).toBe(true);
});
```

**store:**
```ts
it("writes and reads from store with namespace isolation", async () => {
  const store = new InMemoryStore();
  await store.put(["users", "alice", "facts"], "pref", { value: "vegetarian" });
  const result = await store.get(["users", "alice", "facts"], "pref");
  expect(result?.value.value).toBe("vegetarian");

  // Namespace isolation — different user sees nothing:
  const other = await store.get(["users", "bob", "facts"], "pref");
  expect(other).toBeNull();
});
```

## Phase 6: Run tests

```bash
source .claude/hooks/harness.config.sh
if [ -z "$HARNESS_TEST_CMD" ]; then
  echo "No test command configured (HARNESS_TEST_CMD empty). Run the new test manually."
else
  $HARNESS_TEST_CMD
fi
```

- If `HARNESS_TEST_CMD` is empty or unset: print the note and continue to Phase 7.
- If the command exits non-zero: surface the full error output and offer to fix before continuing.
- If the command exits 0: print "OK: tests passed" and proceed.

## Phase 7: Print follow-up

Print the capability-specific follow-up. Be concrete — cite the actual file path and line number where the main artifact landed.

**hitl:**
> "Resume handler at `<path>:<line>`. Idempotency note: pre-interrupt code re-runs on resume — guard external side effects (HTTP calls, DB writes, email sends) with idempotency keys, or move them after `interrupt()`."

**persist:**
> "Checkpointer wired (`<MemorySaver | SqliteSaver | PostgresSaver | RedisSaver>`). `thread_id` strategy: `<chosen>`. For prod, set the connection-string env var before deploy."

**stream:**
> "Stream consumer at `<path>`. FE multiplexes `messages`+`updates`. If subgraphs are added later, set `subgraphs: true` on the stream call."

**subagent:**
> "Sub-agent `<name>` added. Sync (blocks parent) / async (non-blocking via Agent Protocol). Test mocks the sub-agent invocation."

**tool:**
> "Tool `<name>` wired at `<path>`. Tests cover happy path + schema validation. Add it to the agent's `tools` array if not already done."

**middleware:**
> "Middleware `<name>` added at `<path>`. Hooks wired: `<list of hooks filled in>`. Test verifies the hook fires on invocation."

**store:**
> "BaseStore (`<InMemoryStore | PostgresStore>`) wired. Namespace pattern: `[\"users\", userId, ...]`. Read/write inside nodes via `config.store`. Switch to `PostgresStore` before deploying to production."

---

## Tone and approach

Senior-engineer-to-senior-engineer. Each capability is a focused playbook — generate the right code, wire it in, run the test. Don't over-explain every line; add comments where the v1 API diverges from what engineers familiar with v0 would expect (`INTERRUPT` symbol, `isInterrupted()`, `backend` vs `fsBackend`, `createAgent` vs `createReactAgent`, `recursionLimit` at invoke time). When the user's existing code differs from the template, adapt — the existing graph is the source of truth, the templates are guides.
