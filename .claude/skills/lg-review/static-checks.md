# Static Checks Reference — /lg-review

Loaded on demand from `SKILL.md`. Detailed tables, grep strategies, and patterns for the four static-check passes (deprecation, correctness, production, style). Authoritative criteria live in `/lg-cheatsheet` §14 (footguns) and §15 (deprecation list); this file is the operational mapping from those criteria to greppable patterns.

## 2.1 Deprecation pass (BLOCKING)

| Pattern | Recommended replacement |
|---|---|
| `from ['"]@langchain/langgraph/prebuilt['"]` (when importing `createReactAgent`) | `import { createAgent } from "langchain";` |
| `AgentExecutor`, `initializeAgentExecutorWithOptions`, `createOpenAIFunctionsAgent` | `createAgent` from `langchain` |
| `from ['"]langchain/agents['"]` or `from ['"]langchain/chains['"]` | `langchain` (top-level) or `@langchain/classic/chains` |
| LCEL pipe-chains as agent loops (`prompt.pipe(llm).pipe(parser)` with retry logic) | `createAgent` + middleware |
| `dist/` direct imports from any `@langchain/*` package | public entrypoints only |
| `config.configurable` carrying app state (vs `thread_id`/`store`) | new `context` parameter |
| `Annotation.Root` for state | `StateSchema` from `@langchain/langgraph` (legacy still works, prefer current) |

**Grep strategies:**

- `@langchain/langgraph/prebuilt` → pattern `langgraph/prebuilt`, output mode `content`, glob `**/*.ts`
- `AgentExecutor` → pattern `AgentExecutor|initializeAgentExecutorWithOptions|createOpenAIFunctionsAgent`, output mode `content`
- Legacy chain imports → pattern `from ['"]langchain/(agents|chains)`, output mode `content`
- LCEL pipe-chains → pattern `\.pipe\(`, output mode `content`, context 3 lines; flag when surrounding code is an agent-loop (model call + parser with retry); ignore single-step transforms
- `dist/` imports → pattern `@langchain[^'"]+dist/`, output mode `content`
- `config.configurable` → pattern `config\.configurable`, output mode `content`; read context to confirm app state is being carried (not just `thread_id`)
- `Annotation.Root` → pattern `Annotation\.Root`, output mode `content`

Count total BLOCKING deprecation hits; the count drives Phase 4 (migration mode).

## 2.2 Correctness pass (BLOCKING)

| Pattern | Why it's wrong |
|---|---|
| `Annotation<X[]>(...)` channel without a reducer | silent overwrite per node |
| `Annotation.Root({...})` for chat-shaped state without `MessagesAnnotation.spec` spread | no append, no dedupe |
| `{ role: "user", content: "..." }` raw objects (vs `HumanMessage`/`AIMessage`) | message ID dedup broken |
| `model.bindTools(tools)` then `createAgent({ llm: bound, tools })` | structured-output collision |
| `interrupt()` in a node where pre-interrupt code calls `fetch`/`db.x()`/`sendMail()` without idempotency guard | restart hazard |
| `new Send("name", state)` where the payload references parent state shape | mismatch |
| `recursionLimit` passed as `createDeepAgent({...})` constructor option | wrong placement; pass in `.invoke()` config |

**Grep strategies:**

- Missing reducer → `Annotation<`, `content`; flag array/list/set channels lacking `reducer:`
- `MessagesAnnotation.spec` spread → `MessagesAnnotation`, `content`; flag references without the spread
- Raw message objects → `\{ role: ["']`, `content`; any raw role/content not wrapped in message constructors
- Pre-bound tools → `bindTools`, `content`; flag if return then passed as `llm:` into `createAgent`
- `interrupt()` with side effects → `interrupt\(\)`, `content`, context 10; read 10 lines above for `fetch(`, `await db.`, `sendMail`, etc.; flag without idempotency guard
- `Send` payload → `new Send\(`, `content`, context 3; flag payloads mirroring parent state shape vs target input shape
- `recursionLimit` in constructor → `recursionLimit`, `content`; flag inside `createDeepAgent\(\{`

## 2.3 Production pass (WARNING)

| Pattern | Recommendation |
|---|---|
| `MemorySaver` outside `*.test.ts` / `dev.ts` | `Postgres`/`Sqlite`/`Redis` saver |
| Missing `LANGSMITH_TRACING` setup or `traceable()` on hot paths | wire LangSmith (per `/lg-cheatsheet` §12) |
| Serverless deploy target without `LANGCHAIN_CALLBACKS_BACKGROUND=false` | set the env var or traces will be lost |
| Deep Agents `.invoke()` without explicit `recursionLimit` | framework default 25 will trigger `GraphRecursionError`; pass 50+ |
| Subgraph in graph but `.stream()` / `.getState()` without `subgraphs: true` | child events invisible |
| Stateful agent with no checkpointer at all | no resume, no HITL, no replay |
| No `withFallbacks([backup])` on production model calls | single point of failure |
| Tools that hit external systems with no retry config | flaky |

**Grep strategies:**

- `MemorySaver` in prod → `new MemorySaver`, `content`; flag matches NOT in `*.test.ts`, `*.spec.ts`, `dev.ts`, `dev/**`
- LangSmith setup → `LANGSMITH_TRACING` and `traceable`; flag if both absent
- Background callbacks → `LANGCHAIN_CALLBACKS_BACKGROUND`; if absent, check for serverless markers (`vercel.json`, `netlify.toml`, Lambda handler, Deno Deploy)
- `recursionLimit` in `.invoke()` → `\.invoke\(`, `content`, context 5; flag Deep Agent invokes missing `recursionLimit`
- `subgraphs: true` → `subgraphs:`; cross-reference with `addNode.*compiled`; flag stream/getState without `subgraphs: true` when subgraph child nodes exist
- Checkpointer → `checkpointer:` and `thread_id`; flag graphs accepting `thread_id` but missing `checkpointer:` in `.compile(`
- `withFallbacks` → `new Chat(OpenAI|Anthropic|Google)`, context 3; flag prod model instantiations without `.withFallbacks(`
- Tool retry → `fetch\(|axios\.`, glob `**/tools*.ts`; flag without retry wrapper

## 2.4 Style pass (NIT)

| Pattern | Fix |
|---|---|
| `: any` in node return types | `typeof State.Update` |
| Tool descriptions < 1 sentence | LLM tool-pick quality suffers |
| Tool schemas not Zod | lose JSON-schema introspection |
| `as any` casts in graph construction | break type safety |

**Grep strategies:**

- `any` returns → `\): any|=> any`, glob `**/*.ts`
- Short tool descriptions → `description:`, glob `**/tools*.ts`; flag values <40 chars
- Non-Zod schemas → `tool\(`, context 5; flag `tool()` calls where schema arg isn't `z.object(`
- `as any` → ` as any`, glob `**/graph*.ts`

## Common fix patterns (for the punch list `→`)

- Deprecated import: `import { createAgent } from "langchain";`
- Missing reducer (array): `reducer: (a, b) => [...a, ...b], default: () => []`
- Missing reducer (messages): spread `...MessagesAnnotation.spec` into `Annotation.Root({ ... })`
- Raw message: wrap in `new HumanMessage(content)` or `new AIMessage(content)`
- Pre-bound tools collision: pass unbound `llm` to `createAgent`
- `interrupt()` restart hazard: move external call after `interrupt()` or wrap in idempotency check
- `MemorySaver` in prod: `new PostgresSaver(pool)` or `new SqliteSaver(db)` behind `NODE_ENV` check
- Missing `subgraphs: true`: `graph.stream(input, { ...config, subgraphs: true })`

## Punch list format

```
BLOCKING (must fix)
  [B1] src/agent.ts:14  uses deprecated createReactAgent from @langchain/langgraph/prebuilt
         → import { createAgent } from "langchain";
  [B2] src/state.ts:22  channel `findings` has no reducer; will overwrite per node
         → reducer: (a, b) => [...a, ...b], default: () => []

WARNING
  [W1] src/agent.ts:48  MemorySaver in production code path
         → swap for PostgresSaver behind NODE_ENV check

NIT
  [N1] src/tools.ts:10  tool description under 1 sentence
```

If a severity category is entirely clean, print:

```
BLOCKING (must fix)
  none found
```

Save to `docs/lg-reviews/$(date +%Y-%m-%d)-<slug>.md` where `<slug>` is the agent directory or file basename.
