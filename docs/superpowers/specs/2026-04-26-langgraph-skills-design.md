# LangGraph Skills — Design Spec

Generated: 2026-04-26
Branch: markhazlett/langgraph-skills
Status: design approved, awaiting user review of written spec

## 1. Goal

Add a focused, opt-in skill set to the agent-harness that makes building LangGraph / LangChain / Deep Agents in TypeScript dramatically faster and harder to get wrong. The skills cover four moments the user picked: **build/architect**, **add capability**, **verify (eval/review/debug)**, and **migrate / stay current**.

The skill content is locked to **LangChain v1 + LangGraph v1 + Deep Agents v0.5** (the GA stack as of late 2025 / early 2026). All recommendations align with the v1 API surface — no `createReactAgent` from `@langchain/langgraph/prebuilt`, no `AgentExecutor`, no LCEL pipe-chains for agent loops.

## 2. Non-goals

- Python coverage. JS/TS only. (User's working language.)
- Replacing LangSmith — we wire it up, we don't reimplement it.
- Hosting / deployment automation. Skills can advise on LangGraph Platform vs self-hosted, but don't deploy.
- Migrating away from LangGraph. The skills assume the user wants to use the framework.

## 3. The skill set

Six skills under `.claude/skills/lg-*/`, each user-invocable.

| Skill | When fires | Output |
|---|---|---|
| `/lg-cheatsheet` | Reference questions; loaded by other lg-* skills for shared facts | Reference content (no artifact) |
| `/lg-design` | Before code, when designing a new agent or system | Design doc at `docs/lg-designs/...` or `docs/plans/.../sprint-plans/...-graph-design.md` |
| `/lg-scaffold` | New agent code from a design doc or one-liner | Runnable v1 code under `src/agents/<slug>/` |
| `/lg-add <capability>` | Adding HITL / persistence / streaming / sub-agents / tools / middleware / store to an existing agent | Targeted edits + tests |
| `/lg-eval` | Setting up evals / regression tests / trajectory checks | `evals/<slug>.eval.ts` + dataset + LangSmith experiment |
| `/lg-review` | Auditing existing code for v1 best practices, deprecated patterns, footguns | Punch list to `docs/lg-reviews/...`, optional fixes applied |

### 3.1 `/lg-cheatsheet`

The single source of truth for v1 facts. User-invocable for direct reference; loaded by the other five via the `Skill` tool to share context.

**Frontmatter description:**
> *"Quick reference for LangChain v1 / LangGraph v1 / Deep Agents — mental model, v1-current API surface, footgun list, deprecated patterns, JS/TS specifics, production checklist. Use when the user asks 'what's the right way to do X in LangGraph', 'how do streaming/checkpointers/HITL work', or any general LangGraph reference question."*

**Sections:**

1. **Mental model** — 3-layer (LangChain framework / LangGraph runtime / Deep Agents harness) + LangSmith for observability.
2. **The v1-current API surface** — `createAgent` from `langchain` (NOT `createReactAgent` from `@langchain/langgraph/prebuilt`); middleware is the v1 extensibility surface; `message.contentBlocks` (provider-agnostic typed view); structured output now in the agent loop; node renamed `"agent"` → `"model"` in stream events; new `context` parameter replaces `config.configurable`.
3. **State + reducers** — `Annotation.Root`, spread `MessagesAnnotation.spec`, default reducer = overwrite (silent footgun); `typeof State.State` and `typeof State.Update` for node typing.
4. **Streaming map** — Runnable `stream` / `streamEvents` vs LangGraph `streamMode` (`values` / `updates` / `messages` / `messages-tuple` / `custom` / `debug` / `events` / `tasks` / `checkpoints`); recommended FE pattern: multiplex `["messages","updates"]`; `subgraphs: true` to surface child token streams.
5. **Tools** — `tool()` + Zod, `bindTools`, `ToolNode` (parallel by default), error-mode config (`continue` / `error` / custom).
6. **Persistence + memory three-layer** — checkpointer (per-thread; `MemorySaver` dev, `Postgres/Sqlite/Redis/Mongo` prod) + `BaseStore` (cross-thread facts, namespaced) + `summarizationMiddleware` (length).
7. **HITL** — `interrupt()` + `Command({ resume, update?, goto? })`; node restarts on resume (idempotency footgun); multi-interrupt resume map.
8. **Multi-agent** — `createSupervisor`, `createSwarm` / `createHandoffTool`, `Send` for parallel fanout, `Command({ goto })` for handoff inside a node.
9. **Subgraphs** — shared-state-key auto-merge; subgraph streaming requires `subgraphs: true`.
10. **Time travel** — checkpoint replay vs `updateState` fork (history is immutable).
11. **Deep Agents** — `deepagents` npm; `createDeepAgent({ model, tools, systemPrompt, subAgents, middleware })`; four pillars (planning `write_todos` / sub-agents `task` / FS / opinionated prompt); FS backends (`StateBackend` ephemeral / `StoreBackend` cross-thread / `Filesystem` / `Sandbox` Daytona/Deno/Modal); v0.5 async sub-agents; `recursionLimit: 10000` default → bound explicitly.
12. **LangSmith setup** — `LANGSMITH_TRACING` / `LANGSMITH_API_KEY` / `LANGSMITH_PROJECT`; **`LANGCHAIN_CALLBACKS_BACKGROUND=false` in serverless** (else traces lost); `traceable()` for custom spans.
    **When you actually need it:**
    - **Required for code to run:** never. Code runs cleanly with the env vars unset.
    - **Required for evals:** depends on mode (`/lg-eval` supports local-only Vitest/Jest mode without LangSmith; LangSmith-backed and hybrid modes need it).
    - **Recommended:** any multi-step agent with 5+ tool calls, all Deep Agents (the docs ship a `langsmith fetch` CLI specifically because Deep Agent traces are too long to read manually), production debugging, team collaboration, regression eval over weeks of iteration.
    - **Not needed:** 2-tool prototype agents, throwaway scripts, single-shot LLM calls.
13. **Evals** — dataset + target + evaluator; trajectory checks for agents; Vitest/Jest harness; `client.evaluate()` programmatic; `evaluate-complex-agent` recipe.
14. **Top 10 footguns** — reducer omission; node-restart on resume; `MemorySaver` lost on serverless cold start; subgraph streaming flag; `Send` payload != parent state; pre-binding tools breaks structured output; missing `subgraphs: true` on getState; unbounded `recursionLimit` in Deep Agents; Deep Agent FS persistence (`StateBackend` is ephemeral); message ID dedup in MessagesAnnotation; serverless `LANGCHAIN_CALLBACKS_BACKGROUND=true` losing traces.
15. **Deprecation list** — don't use: `createReactAgent` from `@langchain/langgraph/prebuilt`, `AgentExecutor`, `langchain/agents`, `langchain/chains` (moved to `@langchain/classic/chains`), LCEL pipe-chains for agentic flows, `dist/` direct imports, `MemorySaver` in production, `config.configurable` (use `context`), `./callbacks` legacy entrypoint.
16. **Production checklist** — caching, rate limits, retries, fallbacks, structured output (provider-native first), validators, HITL, durability — what to wire from day 1.
17. **Refresh hint** — *"Last verified against LangGraph v1.x / LangChain v1 / deepagents v0.5. To refresh, see [list of doc URLs and changelog endpoints]."*

**Length target:** ~400 lines.

### 3.2 `/lg-design`

The architecture-conversation skill. Modeled on `/office-hours`'s structured questioning, scoped to LangGraph design decisions.

**Frontmatter description:**
> *"Design a LangGraph agent before writing code. Asks structured questions about purpose, tools, persistence, HITL, streaming, memory; picks the right pattern (createAgent vs raw StateGraph vs Deep Agent vs supervisor/swarm); produces a design doc. Use when the user says 'design an agent', 'I'm building an agent that does X', 'help me architect this LangGraph', or before any agent implementation work."*

**Phases:**

1. **Context detection.** Check for open sprint dir at `docs/plans/YYYY-wNN/`. If yes, default output goes to `docs/plans/YYYY-wNN/sprint-plans/<slug>-graph-design.md`. If no, `docs/lg-designs/YYYY-MM-DD-<slug>.md`.
2. **Load shared context.** `Skill`-invoke `/lg-cheatsheet` once (locks v1-current API).
3. **Eight forcing questions** (one at a time via `AskUserQuestion`):
   - Purpose (one-sentence summary).
   - Trigger (interactive chat / API request / cron / webhook / batch).
   - External surface area (APIs, DBs, files, MCP servers).
   - Single agent or multi-agent (supervisor / swarm / hierarchical / DIY with `Send`+`Command`).
   - Run length (sub-second / seconds / minutes / hours-days).
   - HITL (tool-call approval / draft review / arbitrary checkpoint / none).
   - Streaming (token-level / node-level / progress events / none).
   - Memory (thread-only chat history / cross-thread user facts / both / summarization needed).
4. **Pattern recommendation** — explicit decision tree:
   - Simple tool-using agent, message-shaped state → `createAgent` from `langchain`.
   - Custom topology / non-message state / branching control flow → raw `StateGraph`.
   - Long-horizon planning + sub-agents + virtual FS → Deep Agents (`createDeepAgent`).
   - Multi-agent coordination → `createSupervisor` / `createSwarm`.
   - Combinations: `createAgent` *inside* a parent `StateGraph` is the common hybrid.
5. **Graph design** — write up:
   - State schema (channels + reducers; `MessagesAnnotation.spec` spread).
   - Nodes & edges (responsibility per node).
   - Tool list (Zod schema sketches, parallel-tool-call posture).
   - Persistence: checkpointer choice, `thread_id` strategy, when `BaseStore` enters.
   - HITL plan: where `interrupt()` fires, `Command({ resume })` shape.
   - Streaming plan: which modes the FE consumes; `useStream` if React.
   - Eval plan: dataset shape, trajectory check examples, regression hook.
   - Middleware: which built-ins (`summarizationMiddleware`, `humanInTheLoopMiddleware`, `todoListMiddleware`), any custom.
   - Observability: LangSmith env vars, `LANGCHAIN_CALLBACKS_BACKGROUND` for the deployment target.
6. **Premise challenge** — push back before locking:
   - Could `createAgent` cover this without dropping to `StateGraph`? (default yes)
   - Are sub-agents actually needed or is this one agent with more tools?
   - Is `MemorySaver` really fine for prod? (default no)
   - Will the FE actually consume the streaming mode you picked?
7. **Write the design doc** — to the path determined in step 1.
8. **Hand off.** Final message: *"Design saved to `<path>`. Next: `/lg-scaffold <path>` to generate code."*

**Length target:** ~250 lines.

### 3.3 `/lg-scaffold`

Generates runnable v1 code from a design doc OR a one-line description.

**Frontmatter description:**
> *"Scaffold a new LangChain/LangGraph agent in TypeScript. Generates runnable code: `createAgent` (or raw `StateGraph` / Deep Agent) + tools + checkpointer + LangSmith tracing + streaming wiring. Use when the user says 'scaffold an agent', 'build me a LangGraph agent that does X', 'create a Deep Agent', 'start a new agent', or hands off from `/lg-design` with a design path."*

**Phases:**

1. **Input mode.** Three entry points:
   - `/lg-scaffold <design-doc-path>` → read design, scaffold from it.
   - `/lg-scaffold "<one-liner>"` → ask 2-3 fast questions, scaffold simple case.
   - `/lg-scaffold` (no args) → ask: design doc or quick mode?
2. **Load shared context.** Invoke `/lg-cheatsheet`.
3. **Detect target project shape.** Read `package.json`:
   - Node version (warn if <20).
   - Existing LangChain deps; generate `npm install` for missing.
   - TS or JS, ESM or CJS, source dir from `harness.config.sh`.
4. **Pick file footprint.** Default layout:
   ```
   src/agents/<slug>/
     graph.ts          # builds + exports compiled graph
     state.ts          # Annotation.Root state schema
     tools.ts          # tool() definitions with Zod
     middleware.ts     # custom middleware (or omit)
     checkpointer.ts   # checkpointer factory (Memory dev / Postgres prod)
     index.ts          # public entry: invoke / stream
     graph.test.ts     # smoke test using MemorySaver
   .env.example        # LANGSMITH_*, OPENAI_API_KEY, etc.
   ```
   Single-file mode for trivial cases.
5. **Generate.** Pick template per pattern:
   - **`createAgent`** — `langchain` import; plain model + tools list (NOT pre-bound); middleware array; checkpointer; structured-output schema if requested.
   - **Raw `StateGraph`** — `Annotation.Root` with reducers; nodes typed via `typeof State.State` / `typeof State.Update`; `MessagesAnnotation.spec` spread; `ToolNode` + `tools_condition`.
   - **Deep Agent** — `createDeepAgent({...})`; sub-agent specs; FS backend choice; explicit `recursionLimit` (don't leave at 10000).
   - **Multi-agent** — `createSupervisor` / `createSwarm` skeleton; or hand-rolled `Send` / `Command`.
6. **Wire observability (opt-in).** Ask once: *"Wire LangSmith from day 1? Recommended for any multi-step agent; skip for a 2-tool prototype. (y/N)"*. Default **no**.
   - If yes: generate `.env.example` with `LANGSMITH_TRACING=true`, `LANGSMITH_API_KEY=`, `LANGSMITH_PROJECT=<slug>`. If serverless target, set `LANGCHAIN_CALLBACKS_BACKGROUND=false` with explanatory comment.
   - If no: generate `.env.example` with the LangSmith vars **commented out** plus a one-line note: *"Uncomment to enable tracing. See /lg-cheatsheet for when LangSmith is worth wiring."* Code still runs cleanly without them set.
7. **Wire streaming.** If streaming was in the design, generate consumer skeleton: Express/Next/Fastify route yielding `["messages","updates"]`, OR `useStream` example for React.
8. **Smoke test.** Generate `graph.test.ts` that imports compiled graph, invokes with fixed input + `MemorySaver`, asserts shape of final state.
9. **Run smoke test.** Execute `$HARNESS_TEST_CMD` (read from `harness.config.sh`) against the new directory. If `HARNESS_TEST_CMD` is empty or missing, skip the run and print: *"No test command configured; run the new test manually."* If the command exists but fails, surface the error and offer to fix.
10. **Hand off.** *"Scaffold done. Next: `/lg-add` for capabilities, `/lg-eval` for evals."*

**Length target:** ~350 lines (heavy on templates).

### 3.4 `/lg-add <capability>`

Targeted modifier for an existing agent. Reads existing graph file(s), makes precise edits.

**Frontmatter description:**
> *"Add a capability to an existing LangGraph agent: HITL (`interrupt()`), persistence (checkpointer + thread strategy), streaming (token + node events), sub-agents, custom tools, middleware (summarization, PII redaction, rate-limit), or BaseStore for cross-thread memory. Use when the user says 'add HITL to my agent', 'make this graph durable', 'wire streaming', 'add a sub-agent', 'attach a checkpointer', or any 'add X to my LangGraph' phrasing."*

**Phases:**

1. **Identify target.** `/lg-add <capability> <path>` or `/lg-add` (asks). Globs `src/**/{graph,index}.ts` if not specified.
2. **Load shared context.** Invoke `/lg-cheatsheet`.
3. **Read target graph.** Extract: pattern (`createAgent` / `StateGraph` / Deep Agent), state schema, existing nodes, existing checkpointer, existing middleware. Detect deprecated patterns and *gently* recommend `/lg-review` first if found (warn, don't block).
4. **Capability switch:**
   - **`hitl`** — Add `humanInTheLoopMiddleware` (createAgent path) OR insert `interrupt()` at right node + ensure checkpointer present (raw StateGraph). Generate resume handler. Warn about node-restart-on-resume idempotency.
   - **`persist`** — Add checkpointer (`MemorySaver` dev / `Sqlite` single-process / `Postgres` prod). Add install + `await saver.setup()` for Postgres. Add `thread_id` to invoke call sites if missing.
   - **`stream`** — Detect FE shape (Next/Express/Fastify/React/none) and generate consumer. Default multiplex `["messages","updates"]`. If subgraphs present, set `subgraphs: true`.
   - **`subagent`** — For Deep Agents: add `SubAgent` spec; suggest sync vs `AsyncSubAgent`. For createAgent: scaffold a separate sub-graph and parent supervisor edge.
   - **`tool`** — Generate `tool()` definition with Zod. Wire into agent's tools list. Generate `tool.test.ts`.
   - **`middleware`** — Pick from prebuilt (`summarizationMiddleware`, `humanInTheLoopMiddleware`, `todoListMiddleware`, PII redaction, rate-limit) or scaffold custom (`wrapModelCall`, `wrapToolCall`, `beforeAgent`, `afterAgent`).
   - **`store`** — Add `BaseStore` (in-memory or Postgres-backed). Inject `config.store` into nodes that need it. Default namespace strategy: `["users", userId, ...]`.
5. **Make edits** with `Edit` tool. (Post-edit hook re-runs Prettier.)
6. **Update tests.** Extend `graph.test.ts` with smoke test for new capability (e.g. for HITL, an interrupt-then-resume test).
7. **Run tests.** Fix or surface.
8. **Print follow-up.** Capability-specific (e.g. for `hitl`: *"Resume handler at `<path>:<line>`. Idempotency note: pre-interrupt code re-runs on resume — guard external side effects."*).

**Length target:** ~400 lines (seven capability switches).

### 3.5 `/lg-eval`

Sets up evals for an agent. LangSmith-centric, Vitest/Jest-flavored.

**Frontmatter description:**
> *"Set up evals for a LangGraph/LangChain agent in either local-only mode (Vitest/Jest assertions, no upload) or LangSmith-backed mode (datasets, experiment tracking, regression bound to a dataset, online evals against prod traces). Trajectory checks (right tools called in right order), final-answer correctness, smoke/hallucination checks, custom evaluators (rule-based + LLM-as-judge). Use when the user says 'add evals', 'write a regression test for my agent', 'set up LangSmith evals', 'check the agent's trajectory', or 'I broke something — write the test first'."*

**Phases:**

1. **Detect target.** `/lg-eval <agent-path>` or skill globs and asks. Reads agent to understand state shape, tools, pattern.
2. **Load shared context.** Invoke `/lg-cheatsheet`.
3. **Pick eval mode** (single-select via `AskUserQuestion`, this is the load-bearing decision):
   - **Local-only** — Vitest/Jest assertions on agent output. No LangSmith account, no upload. Best for: prototyping, CI without external dependencies, simple agents with deterministic-ish output.
   - **LangSmith-backed** — full experiment tracking, datasets in the dashboard, online evals against prod traces, dataset-bound regressions. Best for: multi-step agents, Deep Agents, anything you'll iterate on for weeks.
   - **Hybrid** — local fixtures committed to git, evaluators usable both ways; `pnpm eval` runs locally, `pnpm eval:remote` uploads to LangSmith. Best for: shipping projects that need both PR-time signal and dashboard view.
4. **Detect prerequisites** (mode-dependent):
   - **All modes:** test runner (Vitest or Jest)? Default Vitest if neither. Generate install for `langsmith` package if mode is LangSmith-backed or hybrid (the `evaluate()` helper lives there even when running locally — it accepts a no-op LangSmith client).
   - **LangSmith-backed / hybrid:** `LANGSMITH_API_KEY` set? Check `.env`/`.env.local`/process env. If missing, **prompt user to add (don't write secrets)**. If user declines, downgrade to local-only mode and continue.
   - **Local-only:** no API key needed. Skip prompts.
5. **Eval check picker** (multi-select via `AskUserQuestion`):
   - Final-answer correctness (LLM-as-judge or exact match).
   - Trajectory check (tool-call ordering / tool absence).
   - Regression suite (dataset-bound evaluators auto-run on every experiment).
   - Online eval — **only available in LangSmith-backed/hybrid modes**; greyed out in local-only.
   - Smoke / hallucination check (no empty AIMessage; respects `recursionLimit`).
6. **Dataset scaffolding** (mode-dependent):
   - **Local-only:** inline fixtures → `evals/datasets/<slug>.ts` (TS array of `{ input, reference }`).
   - **LangSmith-backed:** upload script (`client.createDataset` + `client.createExamples`); inline fixtures NOT generated.
   - **Hybrid:** inline fixtures committed to git, mirrored via `$HARNESS_PKG_MGR run eval:sync` (script generated alongside).
7. **Evaluator scaffolding** (same shape regardless of mode — evaluators are pure functions):
   - Rule-based: TS function `(run, example) => { score, comment }`. Trajectory checks parse `run.outputs.messages` for `tool_calls`.
   - LLM-as-judge: prompt template + ChatModel call returning `{ score, comment }`. In LangSmith mode, wrap with `LLMEvaluator` from `langsmith/evaluation`; in local-only, call the model directly.
   - Structured-output check: Zod schema validation against final state.
8. **Test harness** (mode-dependent shape):
   - **Local-only:** generate `evals/<slug>.eval.test.ts` using plain Vitest/Jest — iterate the dataset, call the agent, run each evaluator, `expect()` the score thresholds. Runs as part of the regular test suite or via the `eval` script.
   - **LangSmith-backed / hybrid:** generate `evals/<slug>.eval.ts` calling `evaluate(agent, { data, evaluators, experimentPrefix })`. Hybrid generates **both** files.
9. **Wire to CI.** Add an `eval` script to `package.json` (separate from the `test` script). Use `$HARNESS_PKG_MGR run eval` for invocation — package manager (npm / pnpm / yarn / bun) is read from `harness.config.sh`. Optionally generate GitHub Action on PR-tag `eval`. **For local-only mode, the GitHub Action runs cleanly without secrets** — no `LANGSMITH_API_KEY` needed in repo secrets.
10. **First run.** Execute `$HARNESS_PKG_MGR run eval`.
    - **Local-only:** assertions pass/fail via the test runner; print pass/fail summary.
    - **LangSmith-backed / hybrid:** surface LangSmith experiment URL. If `LANGSMITH_API_KEY` is missing at this point (user added it during step 4 then removed, or env is wonky), stop and prompt instead of silently failing.
11. **Print follow-up.** *"Mode: `<local-only | langsmith | hybrid>`. Dataset at `evals/datasets/<slug>.ts`, evaluators at `evals/<slug>.eval.ts`, [experiment URL if LangSmith]. To add an evaluator: re-run `/lg-eval add-evaluator`."*

**Length target:** ~350 lines (dual-mode templates push it ~50 over the original estimate).

### 3.6 `/lg-review`

Read-only audit of existing agent against v1-current best practices. Doubles as migration scout.

**Frontmatter description:**
> *"Review existing LangChain/LangGraph code for v1 best practices, deprecated patterns, and footguns. Catches: legacy `createReactAgent`/`AgentExecutor`/`langchain/agents`, missing reducers, `MemorySaver` in production, pre-bound tools breaking structured output, missing observability, missing `subgraphs: true`, node-restart idempotency hazards, unbounded `recursionLimit`. Use when the user says 'review my agent', 'is this LangGraph code current', 'audit this for footguns', 'help me migrate from v0', or 'find the bug in my graph'."*

**Phases:**

1. **Scope.** `/lg-review <path>` or `/lg-review` (asks; defaults to `src/agents/**`). Read-only — no edits without explicit OK.
2. **Load shared context.** Invoke `/lg-cheatsheet`.
3. **Static checks.** One pass per category, each entry cites `file:line`:

   **Deprecation pass (BLOCKING):**
   - `createReactAgent` from `@langchain/langgraph/prebuilt` → `createAgent` from `langchain`.
   - `AgentExecutor`, `initializeAgentExecutorWithOptions`, `createOpenAIFunctionsAgent` → `createAgent`.
   - Imports from `langchain/agents`, `langchain/chains` → new packages.
   - LCEL pipe-chains around an agent loop → `createAgent` + middleware.
   - `dist/` direct imports → public entrypoints.
   - `config.configurable` for app-state → new `context` parameter.
   - `prebuilt` re-exports mixed with `langchain` imports → standardize.

   **Correctness pass (BLOCKING):**
   - Channel without reducer that's an array/list/set → silent overwrite hazard.
   - `MessagesAnnotation` without `MessagesAnnotation.spec` spread → no append, no dedupe.
   - Raw message objects without `HumanMessage`/`AIMessage` constructors → ID dedupe broken.
   - Pre-bound tools (`model.bindTools(...)` then handed to `createAgent`) when structured output is used → collision.
   - `interrupt()` in a node where pre-interrupt code has external side effects without idempotency guard → restart hazard.
   - `Send` payloads referencing parent state shape → mismatch.

   **Production pass (WARNING):**
   - `MemorySaver` outside `*.test.ts` / `dev.ts` → recommend Postgres/Sqlite/Redis.
   - Missing `LANGSMITH_TRACING` setup or `traceable()` on hot paths.
   - Serverless deployment without `LANGCHAIN_CALLBACKS_BACKGROUND=false`.
   - `recursionLimit` left at default in Deep Agents (10000) → recommend explicit budget.
   - Missing `subgraphs: true` when subgraph present and streaming consumed.
   - No checkpointer at all on a stateful agent.
   - No fallback model on production calls.
   - No retry config on tools that hit external systems.

   **Style pass (NIT):**
   - Loose node return types (`any`).
   - Tool descriptions < 1 sentence.
   - Tool schemas not Zod.
   - `as any` casts in graph construction.

4. **Synthesize** punch list grouped by severity.
5. **Offer fixes** via `AskUserQuestion`: *"Want me to apply BLOCKING fixes? (y/n/select)"*. If yes, switch to write-mode and apply with `Edit`. WARNINGs and NITs default to "leave for user". Re-run tests after fixes.
6. **Migration mode.** If punch list dominated by deprecation hits (≥3 BLOCKING deprecations), offer: *"This looks like a v0→v1 migration. Run a full migration in one pass? Yes / Step-by-step / Just print the plan."*
7. **Final report.** Print punch list (whether or not fixes applied), saved to `docs/lg-reviews/YYYY-MM-DD-<slug>.md` for audit trail.

**Length target:** ~350 lines.

## 4. Plumbing

### 4.1 Opt-in flag

`.claude/hooks/harness.config.sh` adds `HARNESS_LANGGRAPH="false"` (default). `setup.sh` adds one prompt:

> *"Do you build LangChain/LangGraph agents in this project? Enabling adds /lg-design, /lg-scaffold, /lg-add, /lg-eval, /lg-review, and /lg-cheatsheet to your skill set. [y/N]"*

Writes `HARNESS_LANGGRAPH="true"` or `"false"` to `harness.config.sh`.

### 4.2 Per-skill precondition gate

Each `lg-*` skill begins with:

```bash
source "$(git rev-parse --show-toplevel)/.claude/hooks/harness.config.sh"
if [ "$HARNESS_LANGGRAPH" != "true" ]; then
  echo "lg-* skills are opt-in. Run ./setup.sh and answer 'yes' to LangGraph mode to enable."
  exit 0
fi
```

The precondition is the first instruction the skill issues to Claude. If not enabled, Claude prints the one-liner and stops. Skills stay discoverable in the slash menu but inert until enabled.

### 4.3 Update-check block

Each `lg-*` skill includes the standard `<update-check>` block matching existing harness skills.

## 5. Integration with existing planning skills

### 5.1 `/plan-sprint` patch (~15 lines)

Insert a new step after goal decomposition, before plan-file generation:

```
For each goal/project being decomposed:
  IF the goal description matches LangGraph triggers, e.g.:
     /(langgraph|langchain|deep ?agent|\b(ai|llm|chat) ?agent\b|tool ?calling|HITL|interrupt\(\)|checkpointer|state ?graph|create ?agent)/i

     (Note: bare \bagent\b is intentionally excluded — the harness already uses
      "agent" for sub-agents like validator/builder. Require an LLM-context
      qualifier or LangGraph-specific term to avoid false positives.)

    Recommend pre-planning architecture:
      "This goal involves agent work. Recommend running /lg-design first to
       produce a graph design before the plan locks. Run now? (y/n/skip)"

    If user says yes:
      - Detect open sprint dir: docs/plans/YYYY-wNN/
      - Invoke /lg-design with sprint context (writes to
        docs/plans/YYYY-wNN/sprint-plans/<slug>-graph-design.md)
      - Link the design doc into the plan body

    When generating the plan file, inject a "Skills" section:
      ## Skills
      - `/lg-scaffold` — generate v1 code from the design doc
      - `/lg-add` — for each capability listed below
      - `/lg-eval` — set up the eval harness referenced in success criteria

    File footprint references:
      - The design doc (read-only input to /lg-scaffold)
      - Expected output paths (src/agents/<slug>/...)
```

No changes to `/plan-sprint`'s existing behavior for non-agent goals. Detection regex is conservative — false positives produce one extra question, no further harm.

**Implementation precondition.** Before this patch lands, the implementation plan must verify `/plan-sprint`'s plan-file template has a stable place to inject the new `## Skills` section (e.g. between the existing "## File footprint" and "## Test plan" sections). If the template is too rigid, the patch needs to add the section header as part of the same change. Reading `.claude/skills/plan-sprint/SKILL.md` first is mandatory.

### 5.2 `/build-plan` — unchanged behavior, doc note added

Auto-fire from frontmatter descriptions handles execution. We add a single sentence to `/build-plan`'s skill description noting: *"When plan steps involve LangGraph agent work, /lg-* skills auto-fire."*

The `lg-*` skill descriptions are written specifically to match plan-step bullets:

- *"Scaffold the agent graph at `src/agents/research/`."* → `/lg-scaffold` fires.
- *"Add HITL approval before the email tool fires."* → `/lg-add hitl` fires.
- *"Wire LangSmith trajectory evaluator with 10-row golden dataset."* → `/lg-eval` fires.

### 5.3 `/lg-design` sprint-context detection

`/lg-design` checks for an open sprint at session start by:

```bash
LATEST_SPRINT="$(ls -d docs/plans/*-w* 2>/dev/null | sort -V | tail -1)"
SPRINT_PLANS_DIR="$LATEST_SPRINT/sprint-plans"
```

If found, default output goes to `$SPRINT_PLANS_DIR/<slug>-graph-design.md`. Otherwise, `docs/lg-designs/YYYY-MM-DD-<slug>.md`. User can override via skill argument.

## 6. Other repo changes

- **`README.md`** — add a one-liner under "What you get" mentioning the LangGraph track is opt-in. Add an `lg-*` row in the **All skills** collapsed details block.
- **`VERSION`** — bump `0.5.0` → `0.6.0` (minor; new skill family, matches precedent: `0.4.0` added `/office-hours`, `0.5.0` added `/learn`).

## 7. Skill cross-loading

`/lg-cheatsheet` is the load-bearing reference. The other five skills `Skill`-invoke it once at the top of their flow when they need shared context (v1 facts, footgun list, mental model). This avoids duplicating the reference content across files. If `/lg-cheatsheet` is updated, all five inherit the new material on next run.

## 8. Refresh strategy

`/lg-cheatsheet` ends with a "Last verified" date and links to changelogs:

- https://github.com/langchain-ai/langgraphjs/releases
- https://github.com/langchain-ai/langchainjs/releases
- https://github.com/langchain-ai/deepagentsjs/releases
- https://docs.langchain.com/oss/javascript/releases/changelog

When the user later asks "is this still current?" or "refresh the cheatsheet", they can run `/lg-cheatsheet refresh` (one-arg sub-mode) which fetches the changelogs, diffs against the cheatsheet's current claims, and proposes updates. This is **out of scope for v1** — initial ship leaves the cheatsheet static and asks the user to re-run `/lg-review` periodically to surface drift.

## 9. File footprint

```
.claude/skills/lg-cheatsheet/SKILL.md      (new, ~400 lines)
.claude/skills/lg-design/SKILL.md          (new, ~250 lines)
.claude/skills/lg-scaffold/SKILL.md        (new, ~350 lines)
.claude/skills/lg-add/SKILL.md             (new, ~400 lines)
.claude/skills/lg-eval/SKILL.md            (new, ~300 lines)
.claude/skills/lg-review/SKILL.md          (new, ~350 lines)
.claude/skills/plan-sprint/SKILL.md        (patch, ~15 lines)
.claude/skills/build-plan/SKILL.md         (patch, ~1 line description note)
.claude/hooks/harness.config.sh            (patch, +1 var)
setup.sh                                   (patch, +1 prompt)
README.md                                  (patch, ~5 lines)
VERSION                                    (patch, 0.5.0 → 0.6.0)
```

No new dependencies, no new hooks, no new commands. Pure skill additions + small patches.

## 10. Success criteria

- All 6 `lg-*` skills present, each with the `<update-check>` block, the precondition gate, and the body sections described above.
- `setup.sh` prompts and writes `HARNESS_LANGGRAPH` correctly. Re-running flips the value.
- `/plan-sprint` detects agent goals (regex above) and offers `/lg-design` integration.
- `/lg-design` detects open sprint context and routes output correctly.
- `/lg-cheatsheet` is loadable via `Skill` from each of the other five skills.
- Manual end-to-end test: enable LangGraph mode, run `/lg-design` → `/lg-scaffold` → `/lg-add hitl` → `/lg-eval` → `/lg-review` against a dummy goal. Each step writes the expected artifact and runs without error.
- VERSION bumped to `0.6.0` and `harness-update-check` surfaces the upgrade for users on `0.5.x`.

## 11. Out of scope (v1)

- Python coverage.
- `/lg-cheatsheet refresh` — auto-update the cheatsheet from upstream changelogs.
- Multi-language code generation (only TS).
- LangGraph Platform deployment automation.
- LangSmith dataset versioning.
- A separate `/lg-debug` skill for live-graph inspection — `/lg-review` covers static analysis; live debugging is left for the next iteration.

## 12. Risks

- **Doc drift.** LangChain ships fast — by mid-2026 v2 may be hinted at. Mitigation: cheatsheet has a "last verified" date; periodic re-runs of `/lg-review` will surface drift via deprecation warnings.
- **Auto-fire false positives.** A plan step mentioning "agent" in a non-LangGraph sense could fire `/lg-scaffold`. Mitigation: skill descriptions specifically say "LangChain/LangGraph agent" — non-LG uses won't match.
- **Skill bloat in slash menu.** 6 new skills is significant. Mitigation: opt-in gate keeps them out of users' menus until enabled.
- **Setup-flow interruption.** New prompt in `setup.sh` is one extra question. Mitigation: question explains the impact in one sentence.
