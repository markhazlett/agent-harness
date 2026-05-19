---
name: lg-design
description: Use when the user says "design an agent", "I'm building an agent that does X", "help me architect this LangGraph", or before any agent implementation work. Asks structured questions, picks the right pattern (createAgent vs raw StateGraph vs Deep Agent vs supervisor/swarm), produces a design doc.
user-invocable: true
tier: flexible
kind: process
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Run `/harness-update` to pull it in." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

<langgraph-gate>
Run: `bash -c 'source "$(git rev-parse --show-toplevel)/.claude/hooks/config.sh"; [ "$HARNESS_LANGGRAPH" = "true" ] && echo OK || echo OPT_IN_REQUIRED'`
- `OPT_IN_REQUIRED` → tell the user: "lg-* skills are opt-in. Run `./setup.sh` and answer 'yes' to LangGraph mode to enable." Then stop without doing the rest of the skill.
- `OK` → continue silently.
</langgraph-gate>

# /lg-design

Architecture-conversation skill for LangGraph agents. Walks through eight structured questions, recommends the right pattern (createAgent / StateGraph / Deep Agent / supervisor / swarm), challenges premises before locking design, and writes a design doc. Never writes code — design only.

## Phase 0: Load shared context

Invoke the `lg-cheatsheet` skill via the `Skill` tool to load v1 facts, footgun list, and mental model. This skill treats the cheatsheet's API surface as authoritative.

## Phase 1: Detect context

Run:

```bash
LATEST_SPRINT=$(ls -d docs/plans/*-w* 2>/dev/null | sort -V | tail -1)
SPRINT_PLANS_DIR="${LATEST_SPRINT}/sprint-plans"
```

- If `$LATEST_SPRINT` is non-empty AND `$SPRINT_PLANS_DIR` exists → **sprint mode**: default output is `${SPRINT_PLANS_DIR}/<slug>-graph-design.md`.
- Otherwise → **standalone mode**: default output is `docs/lg-designs/$(date +%Y-%m-%d)-<slug>.md`.

Tell the user which mode is active and what the default output path will be. User can override with a different path.

## Phase 2: The eight forcing questions

Ask **one at a time** via AskUserQuestion. Wait for the response before asking the next. If the user is vague, push back: "What does it ACTUALLY do? Be specific."

### Q1: Purpose

Open-ended. Ask: "What does this agent do? One sentence."

Listen for specificity. Vague answers ("it helps users", "it does AI stuff") → push: name the action, the user, the outcome. Drives the slug and the purpose section of the doc.

### Q2: Trigger

Multi-choice. Ask how the agent is invoked. Options:
- Interactive chat (user types, agent responds)
- API request (sync, response expected immediately)
- Cron / scheduled job
- Webhook (event-driven, async)
- Batch (processes a queue or dataset)
- Other

Drives durability decisions (webhook/batch → durability matters; chat → less so).

### Q3: External surface area

Open-ended. Ask: "What does it touch? APIs, DBs, files, MCP servers — list them."

Each external surface is a potential tool. Drives the tools section and retry/fallback decisions.

### Q4: Single agent or multi-agent

Multi-choice. Options:
- Single agent (one graph, one model loop)
- Supervisor + workers (centralized routing to sub-agents)
- Swarm (peer handoff between agents)
- Hierarchical (supervisors of supervisors)
- DIY with `Send` + `Command` (manual fanout / handoff inside a node)

This is the highest-leverage question. Most agents should start as single. Push back if multi-agent is chosen without a clear reason.

### Q5: Run length

Multi-choice. Options:
- Sub-second (single LLM call, no tool use)
- Seconds (1-5 tool calls, short loops)
- Minutes (multi-step, 5-20 tool calls)
- Hours to days (long-horizon planning, Deep Agent territory)

Drives durability: anything beyond seconds should have a production checkpointer, not MemorySaver.

### Q6: HITL

Multi-choice. Options:
- None (fully autonomous)
- Tool-call approval (interrupt before a specific tool fires)
- Draft review (agent writes, human edits state, then resumes)
- Arbitrary checkpoint (pause anywhere, human decides next step)
- Multiple (more than one of the above)

Drives where `interrupt()` fires and whether `humanInTheLoopMiddleware` covers it.

### Q7: Streaming

Multi-choice. Options:
- None (batch invoke, final state only)
- Token-level (chat UI, user sees tokens as they generate)
- Node-level (progress events, show which step is running)
- Both

Drives the streaming section and FE consumer shape.

### Q8: Memory

Multi-choice. Options:
- Thread-only chat history (messages in checkpointer, no cross-thread)
- Cross-thread user facts (`BaseStore`, namespaced by user)
- Both
- Plus summarization for length (`summarizationMiddleware`)

Drives whether `BaseStore` appears in the design and which middleware fires.

## Phase 3: Pattern recommendation

Present the recommended pattern with reasoning. Map Q4 + complexity to these patterns:

| Situation | Pattern |
|---|---|
| Simple tool-using agent, message-shaped state | `createAgent` from `langchain` |
| Custom topology / non-message state / branching control flow | Raw `StateGraph` |
| Long-horizon planning + sub-agents + virtual FS | Deep Agents (`createDeepAgent`) |
| Multi-agent with centralized routing | `createSupervisor` |
| Multi-agent with peer handoff | `createSwarm` |

Common hybrid: `createAgent` *inside* a parent `StateGraph` — use when you need mostly-chat with a custom outer routing layer.

Default recommendation is toward simpler patterns. The premise challenge (Phase 5) will push back if the user over-engineered.

Get user confirmation on the pattern before moving to Phase 4.

## Phase 4: Graph design

Walk through each sub-section and confirm with the user before moving on. Ask one AskUserQuestion per sub-section where a decision is needed.

### State schema

Propose the state shape. For message-centric agents, use `MessagesValue` (v1-current):

```ts
import { StateSchema, MessagesValue } from "@langchain/langgraph";

export const State = new StateSchema({
  messages: MessagesValue,
  // ...other channels
});
```

If spreading legacy annotation: `MessagesAnnotation.spec`. Remind the user that channels without reducers default to overwrite — any array/list channel needs an explicit reducer.

### Nodes & edges

List each node with its responsibility. Sketch the edge structure (sequential, conditional, looping). For `StateGraph`, name the entry node and any `END` conditions. For `createAgent`, note the model node is `"model"` in stream events (not `"agent"` — v1 rename).

### Tool list

For each tool from Q3, sketch the Zod schema shape. Note parallel-tool-call posture: `ToolNode` runs in parallel by default; set `handleToolErrors: "continue"` or `"error"` explicitly.

### Persistence

- Dev: `MemorySaver` (never prod — lost on cold start / process restart).
- Prod options: `PostgresSaver`, `SqliteSaver`, `RedisSaver`, `MongoDBSaver`.
- `thread_id` strategy: one per conversation session, one per user, one per job — pick based on Q2 trigger.
- `BaseStore` only if Q8 answered cross-thread.

### HITL plan

If Q6 is not None: name the node where `interrupt()` fires. Sketch the `Command({ resume })` shape the client sends. Warn: code before `interrupt()` in that node re-runs on resume — idempotency guard external side effects.

### Streaming plan

Map Q7 to streamMode. FE recommended pattern: multiplex `["messages", "updates"]`. If subgraphs present, add `subgraphs: true`. For React, `useStream` from `@langchain/langgraph-sdk/react`.

### Eval plan

Dataset shape: `{ input, reference }`. Trajectory check examples: assert specific tools called in order. Mode: LangSmith-backed (recommended for multi-step agents) or local-only Vitest (fine for simple agents). `/lg-eval` handles full scaffolding.

### Middleware

From built-ins: `summarizationMiddleware` (if Q8 includes summarization), `humanInTheLoopMiddleware` (if Q6 HITL), `todoListMiddleware` (if Deep Agent). Custom hooks: `beforeAgent`, `beforeModel`, `wrapModelCall`, `wrapToolCall`, `afterModel`, `afterAgent`.

### Observability

Required env vars: `LANGSMITH_TRACING`, `LANGSMITH_API_KEY`, `LANGSMITH_PROJECT`. If serverless deployment: set `LANGCHAIN_CALLBACKS_BACKGROUND=false` (else traces are lost on function exit). Not required for code to run — optional but recommended for any multi-step agent.

## Phase 5: Premise challenge

Push back **before** locking design. Ask each via AskUserQuestion. Accept user's response and update design if they change course.

1. "Could `createAgent` cover this without dropping to `StateGraph`?" Default: yes — `StateGraph` is overkill for most agents. Only drop down for non-message state or custom topology.
2. "Are sub-agents actually needed, or is this one agent with more tools?" More tools is almost always simpler and correct first.
3. "Is `MemorySaver` really fine for prod?" Default: no. If Q5 is Minutes or longer, or if it's a webhook/cron trigger, push for `PostgresSaver` or `SqliteSaver`.
4. "Will the FE actually consume the streaming mode you picked?" Token-level streaming requires a streaming-capable FE — confirm it exists.
5. "What happens if the agent is interrupted by a crash mid-tool-call?" Drives durability decisions: any agent where re-doing a tool call has side effects needs a durable checkpointer and idempotency guards.

## Phase 6: Write the design doc

Write to the path computed in Phase 1. Derive `<slug>` from the agent's purpose (kebab-case, ≤4 words). Derive `<git branch>` from `git branch --show-current`.

```markdown
# Agent Design: <slug>

Generated by /lg-design on <date>
Branch: <git branch>
Mode: <sprint | standalone>

## Purpose
<one sentence from Q1>

## Trigger
<from Q2>

## External Surface Area
<from Q3>

## Pattern: <createAgent | StateGraph | Deep Agent | Supervisor | Swarm>

## State Schema
\`\`\`ts
import { StateSchema, MessagesValue } from "@langchain/langgraph";

export const State = new StateSchema({
  messages: MessagesValue,
  // ...other channels
});
\`\`\`

## Nodes & Edges
<table or list, responsibility per node>

## Tools
<list with Zod schema sketches>

## Persistence
<checkpointer choice + thread strategy + BaseStore use>

## HITL
<where interrupt() fires + Command({ resume }) shape>

## Streaming
<modes consumed + FE shape>

## Eval
<dataset + trajectory checks + LangSmith vs local-only mode>

## Middleware
<list of prebuilt + any custom hooks>

## Observability
<LangSmith env vars + LANGCHAIN_CALLBACKS_BACKGROUND posture>

## Premises (agreed during /lg-design)
<from Phase 5>

## Open questions
<anything unresolved>
```

Create the output directory if it doesn't exist.

## Phase 7: Hand off

Tell the user:

> "Design saved to `<path>`. Next: `/lg-scaffold <path>` to generate code."

If sprint mode, also recommend: "Link this design from your sprint plan's `## Skills` section."

## Terminal State

The next skill in the chain is `/lg-scaffold <design-doc-path>`. Do NOT invoke `/lg-add` (capabilities go after scaffold), `/build` (no scaffold yet), or other implementation skills until `/lg-scaffold` completes — or the user explicitly overrides (per `CLAUDE.md` § Instruction precedence).
