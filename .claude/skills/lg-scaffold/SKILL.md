---
name: lg-scaffold
description: Scaffold a new LangChain/LangGraph agent in TypeScript. Generates runnable code using LangChain v1 / LangGraph v1 patterns — `createAgent` (or raw `StateGraph` / Deep Agent) + tools + checkpointer + optional LangSmith tracing + streaming wiring. Use when the user says "scaffold an agent", "build me a LangGraph agent that does X", "create a Deep Agent", "start a new agent", or hands off from `/lg-design` with a design path.
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

# /lg-scaffold

Generates runnable LangGraph v1 TypeScript code from a design doc or a one-liner description. Picks the right template (createAgent / raw StateGraph / Deep Agent / multi-agent), wires LangSmith opt-in, produces a smoke test, and runs it. Hand off from `/lg-design` or use standalone for quick-mode scaffolding.

## Phase 0: Load shared context

Invoke the `/lg-cheatsheet` skill via the `Skill` tool. This locks the v1-current API surface — `createAgent` from `langchain`, `StateSchema`/`MessagesValue`, `INTERRUPT` symbol, `backend` parameter — for all template generation below.

## Phase 1: Input mode

Three entry points — detect which applies, then proceed:

- **`/lg-scaffold <design-doc-path>`** — Read the design doc at the given path. Extract: pattern recommendation, state schema, node list, tool list, HITL plan, streaming plan, middleware plan, observability plan, slug. Scaffold from those decisions.
- **`/lg-scaffold "<one-liner>"`** — Ask 2-3 fast clarifying questions (pattern, streaming y/n, HITL y/n), then scaffold the simple case.
- **`/lg-scaffold` (no args)** — Ask the user: "Do you have a design doc path, or want quick mode (just describe what the agent should do)?"

## Phase 2: Detect target project shape

Read `package.json` (and `.claude/hooks/harness.config.sh`) to detect:

- **Node version** (`engines.node`): warn if `<20` — LangGraph v1 requires Node 20+.
- **Existing LangChain deps**: check for `langchain`, `@langchain/langgraph`, `@langchain/openai`, `@langchain/anthropic`, `@langchain/core`, `langsmith`, `deepagents`. For each missing dep needed by the chosen pattern, emit:
  ```
  $HARNESS_PKG_MGR install <pkg>
  ```
- **TS or JS, ESM or CJS**: read `type` field and `tsconfig.json` if present. Default to TS + ESM.
- **Source dir**: read `HARNESS_SRC_DIRS` from `harness.config.sh`; default to `src/` if unset.

## Phase 3: Pick file footprint

Propose this layout to the user and get a nod before generating:

```
src/agents/<slug>/
  graph.ts          # builds + exports compiled graph
  state.ts          # StateSchema state definition
  tools.ts          # tool() definitions with Zod
  middleware.ts     # custom middleware (or omit if none)
  checkpointer.ts   # checkpointer factory (MemorySaver dev / Postgres prod)
  index.ts          # public entry: invoke / stream
  graph.test.ts     # smoke test using MemorySaver
.env.example        # LANGSMITH_*, OPENAI_API_KEY, etc.
```

**Single-file mode** (just `index.ts` + `graph.test.ts`): use for trivial cases — 1-2 tools, no custom middleware, no subgraphs.

## Phase 4: Generate from template

Branch on the pattern determined in Phase 1 (from design doc or quick-mode answers). Generate across all files in the chosen footprint. Include a comment block at the top of `graph.ts` linking back to the design doc path (if scaffolded from one) and referencing the relevant `/lg-cheatsheet` section.

---

### Template A: `createAgent` (preferred for most agents)

`graph.ts`:
```ts
// Design doc: <path-if-present>
// v1 pattern: createAgent from langchain — see /lg-cheatsheet §2
import { createAgent } from "langchain";
import { ChatOpenAI } from "@langchain/openai"; // swap to @langchain/anthropic if needed
import { tools } from "./tools";
import { createCheckpointer } from "./checkpointer";
// import { middleware } from "./middleware"; // uncomment when middleware is needed

export const agent = createAgent({
  model: new ChatOpenAI({ model: "gpt-4o" }), // plain model — do NOT pre-bind tools
  tools,                                        // separate tools list
  // middleware: [middleware],
  checkpointer: createCheckpointer(),
});
```

`state.ts`:
```ts
import { StateSchema, MessagesValue } from "@langchain/langgraph";

export const State = new StateSchema({
  messages: MessagesValue,
  // Add additional channels here. Omitting a reducer means overwrite — add one for arrays/sets.
});

export type StateType = typeof State.State;
export type UpdateType = typeof State.Update;
```

`tools.ts`:
```ts
import { tool } from "@langchain/core/tools";
import { z } from "zod";

export const exampleTool = tool(
  async ({ input }) => {
    // implement
    return `result for ${input}`;
  },
  {
    name: "example_tool",
    description: "One-sentence description of what this tool does and when to use it.",
    schema: z.object({
      input: z.string().describe("The input to process"),
    }),
  }
);

export const tools = [exampleTool];
```

`checkpointer.ts`:
```ts
import { MemorySaver } from "@langchain/langgraph";
// import { PostgresSaver } from "@langchain/langgraph-checkpoint-postgres"; // for prod

export function createCheckpointer() {
  // MemorySaver is for local dev only — lost on process restart / serverless cold start.
  // Switch to PostgresSaver (or SqliteSaver) before deploying.
  return new MemorySaver();
}
```

`index.ts`:
```ts
import { agent } from "./graph";

export async function invokeAgent(userMessage: string, threadId: string) {
  return agent.invoke(
    { messages: [{ role: "user", content: userMessage }] },
    { configurable: { thread_id: threadId } }
  );
}
```

---

### Template B: Raw `StateGraph` (when custom topology is needed)

`graph.ts`:
```ts
// Design doc: <path-if-present>
// v1 pattern: raw StateGraph — see /lg-cheatsheet §3
import {
  StateGraph,
  StateSchema,
  MessagesValue,
  START,
  END,
} from "@langchain/langgraph";
import { ToolNode, toolsCondition } from "@langchain/langgraph/prebuilt";
import { ChatOpenAI } from "@langchain/openai";
import { tools } from "./tools";

export const State = new StateSchema({
  messages: MessagesValue,
});

type StateType = typeof State.State;
type UpdateType = typeof State.Update;

const llm = new ChatOpenAI({ model: "gpt-4o" });
// Do NOT pre-bind tools here — pass separately to ToolNode and model.

const graph = new StateGraph(State)
  .addNode("model", async (s: StateType): Promise<UpdateType> => ({
    messages: [await llm.invoke(s.messages)],
  }))
  .addNode("tools", new ToolNode(tools))
  .addEdge(START, "model")
  .addConditionalEdges("model", toolsCondition)
  .addEdge("tools", "model");

// Checkpointer injected at compile time for HITL / persistence.
import { MemorySaver } from "@langchain/langgraph";
const checkpointer = new MemorySaver(); // swap for prod checkpointer

export const compiled = graph.compile({ checkpointer });
```

---

### Template C: Deep Agent (long-horizon planning + sub-agents + virtual FS)

`graph.ts`:
```ts
// Design doc: <path-if-present>
// v1 pattern: createDeepAgent — see /lg-cheatsheet §11
import { createDeepAgent, StoreBackend } from "deepagents";
import { InMemoryStore } from "@langchain/langgraph";
import { tools } from "./tools";

export const agent = createDeepAgent({
  model: "claude-sonnet-4-5-20250929", // default; swap to ChatOpenAI/etc as needed
  tools,
  systemPrompt: `<domain-specific framing here.
The harness layers BASE_AGENT_PROMPT and middleware instructions on top — keep this to domain context only.>`,
  subAgents: [
    {
      name: "researcher",
      description: "Searches and summarizes information from external sources.",
      instructions: "You are a research specialist. Be concise, cite sources.",
    },
    // Add more sub-agents per design doc.
  ],
  backend: new StoreBackend(), // use StateBackend() for ephemeral, Filesystem for local FS
  store: new InMemoryStore(),
  // middleware: [], // add summarizationMiddleware, humanInTheLoopMiddleware, etc.
});

// Pass recursionLimit at invoke time — framework default is too low for Deep Agents.
// Example: agent.invoke(input, { recursionLimit: 50 });
```

`index.ts` (Deep Agent variant):
```ts
import { agent } from "./graph";

export async function invokeAgent(userMessage: string) {
  return agent.invoke(
    { messages: [{ role: "user", content: userMessage }] },
    { recursionLimit: 50 } // tune per task complexity; don't leave at framework default
  );
}
```

---

### Template D: Multi-agent (supervisor or swarm)

`graph.ts` (supervisor variant):
```ts
// Design doc: <path-if-present>
// v1 pattern: createSupervisor — see /lg-cheatsheet §8
import { createSupervisor } from "@langchain/langgraph-supervisor";
import { ChatOpenAI } from "@langchain/openai";
// import { createSwarm, createHandoffTool } from "@langchain/langgraph-swarm"; // swarm alt

const researcherAgent = /* ... your compiled sub-graph or createAgent instance ... */ null;
const writerAgent = /* ... */ null;

export const supervisor = createSupervisor({
  agents: [researcherAgent, writerAgent],
  llm: new ChatOpenAI({ model: "gpt-4o" }),
  // systemPrompt: "Route tasks to the right specialist.",
}).compile();
```

For hand-rolled coordination (when `createSupervisor` is too opinionated), use `Send` for parallel fanout and `Command({ goto })` for handoff inside a node. See `/lg-cheatsheet §8` for the pattern.

---

## Phase 5: Wire streaming

If streaming was in the design doc or quick-mode said yes, generate the consumer skeleton. If subgraphs are present in the graph, set `subgraphs: true` on the stream call.

**Express/Fastify — SSE handler:**
```ts
import type { Request, Response } from "express";
import { compiled } from "./graph"; // or agent

export async function streamHandler(req: Request, res: Response) {
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");

  const stream = compiled.stream(
    { messages: [{ role: "user", content: req.body.message }] },
    {
      configurable: { thread_id: req.body.threadId },
      streamMode: ["messages", "updates"],
      // subgraphs: true, // uncomment if subgraphs present
    }
  );

  for await (const chunk of await stream) {
    res.write(`data: ${JSON.stringify(chunk)}\n\n`);
  }
  res.end();
}
```

**Next.js — route handler:**
```ts
// app/api/chat/route.ts
import { compiled } from "@/src/agents/<slug>/graph";

export async function POST(req: Request) {
  const { message, threadId } = await req.json();
  const stream = compiled.stream(
    { messages: [{ role: "user", content: message }] },
    { configurable: { thread_id: threadId }, streamMode: ["messages", "updates"] }
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

**React — `useStream` hook:**
```ts
import { useStream } from "@langchain/langgraph-sdk/react"; // adjust import per SDK version

const { messages, startStream } = useStream({
  graphId: "<slug>",
  streamMode: ["messages", "updates"],
});
```

If no streaming was requested: skip this phase entirely.

## Phase 6: Wire observability (opt-in)

Ask the user once:

> "Wire LangSmith from day 1? Recommended for any multi-step agent; skip for a 2-tool prototype. (y/N)"

Default is **no**.

**Yes branch** — generate `.env.example`:
```
LANGSMITH_TRACING=true
LANGSMITH_API_KEY=
LANGSMITH_PROJECT=<slug>
# Serverless deployments only — uncomment to flush traces before exit
# LANGCHAIN_CALLBACKS_BACKGROUND=false
```
If the design doc confirmed a serverless deployment target, uncomment `LANGCHAIN_CALLBACKS_BACKGROUND=false` and add the comment: `# Required on serverless — traces lost otherwise. See /lg-cheatsheet §12.`

**No branch** — generate `.env.example` with LangSmith vars commented out:
```
# LANGSMITH_TRACING=true
# LANGSMITH_API_KEY=
# LANGSMITH_PROJECT=<slug>
# Uncomment to enable tracing. See /lg-cheatsheet §12 for when LangSmith is worth wiring.
OPENAI_API_KEY=
```
Code runs cleanly without any of these set.

## Phase 7: Generate the smoke test

`graph.test.ts`:
```ts
import { describe, it, expect } from "vitest";
import { MemorySaver } from "@langchain/langgraph";
import { agent } from "./graph"; // or: import { compiled } from "./graph"

describe("<slug> agent", () => {
  it("invokes without error and produces an AIMessage", async () => {
    const result = await agent.invoke(
      { messages: [{ role: "user", content: "<smoke test input matching agent purpose>" }] },
      { configurable: { thread_id: "smoke-test-1" } }
    );
    expect(result.messages.at(-1)?.role).toBe("assistant");
    expect(result.messages.at(-1)?.content).toBeTruthy();
  });
});
```

Use `vitest` or `jest` based on what's in `package.json` devDependencies. Default to `vitest` if neither is present (and emit the install command).

For Deep Agent pattern: use `{ recursionLimit: 10 }` in the test invoke options to keep smoke tests fast.

## Phase 8: Run smoke test

```bash
source .claude/hooks/harness.config.sh
if [ -z "$HARNESS_TEST_CMD" ]; then
  echo "No test command configured (HARNESS_TEST_CMD empty). Run the new test manually."
else
  $HARNESS_TEST_CMD src/agents/<slug>
fi
```

- If the command is missing or empty: print the note above and continue to Phase 9.
- If the command exists but exits non-zero: surface the full error output and offer to fix before handing off.
- If the command exits 0: print "OK: smoke test passed" and proceed.

## Phase 9: Hand off

Final message to the user:

> "Scaffold done at `src/agents/<slug>/`. Next: `/lg-add <capability>` to wire HITL / persistence / streaming / sub-agents / middleware. Set up evals: `/lg-eval`."

If scaffolded from a design doc, also note: "Design doc is linked in `graph.ts` header comment for traceability."

---

## Tone and approach

Senior-engineer-to-senior-engineer. Templates are correct starting points, not gospel — generate them and hand off. Don't over-explain every line; add comments where the v1 API diverges from what engineers familiar with v0 would expect (pre-binding tools, `backend` vs `fsBackend`, `recursionLimit` at invoke time, `StateSchema` vs `Annotation.Root`).

When the user's design doc specifies something different from the template default, use the design doc's decision — the template is a fallback, not an override.
