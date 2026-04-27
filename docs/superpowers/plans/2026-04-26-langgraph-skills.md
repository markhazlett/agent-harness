# LangGraph Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an opt-in suite of six `lg-*` skills (cheatsheet, design, scaffold, add, eval, review) that supercharge LangGraph + LangChain v1 + Deep Agents work in TS, plus the plumbing (config flag, setup.sh prompt) and integration patches (`/plan-sprint`, `/build-plan`) that wire them into the existing sprint workflow.

**Architecture:** Each skill is a `.claude/skills/<name>/SKILL.md` file with YAML frontmatter (`name`, `description`, `user-invocable: true`), a standard `<update-check>` block, and a `HARNESS_LANGGRAPH` precondition gate that exits cleanly if the user hasn't opted in. `/lg-cheatsheet` is the load-bearing reference loaded by the others via the `Skill` tool. Two existing skills get small patches; one config flag is added; `setup.sh` gains one prompt.

**Tech Stack:** Bash (hooks, setup.sh, precondition gates), Markdown (skills + plans), YAML frontmatter, jq (existing), the existing harness `bin/harness-update-check` script.

**Spec:** `docs/superpowers/specs/2026-04-26-langgraph-skills-design.md` — read this before starting. The plan refers to its sections by number (e.g. "spec §3.1") for content outlines.

---

## File Structure

**Created:**
- `.claude/skills/lg-cheatsheet/SKILL.md`  — reference, ~400 lines
- `.claude/skills/lg-design/SKILL.md`      — design conversation, ~250 lines
- `.claude/skills/lg-scaffold/SKILL.md`    — code scaffold, ~350 lines
- `.claude/skills/lg-add/SKILL.md`         — capability add, ~400 lines
- `.claude/skills/lg-eval/SKILL.md`        — evals, ~350 lines
- `.claude/skills/lg-review/SKILL.md`      — audit, ~350 lines

**Modified:**
- `.claude/hooks/harness.config.sh`        — +1 var (`HARNESS_LANGGRAPH`)
- `setup.sh`                                — +1 prompt + +1 line in heredoc
- `.claude/skills/plan-sprint/SKILL.md`     — +regex detection, +`## Skills` section in plan template
- `.claude/skills/build-plan/SKILL.md`      — +1 sentence in `description` frontmatter
- `README.md`                               — +1 line under "What you get", +1 row in skills table
- `VERSION`                                 — `0.5.0` → `0.6.0`

**No new dependencies. No new hooks. No new commands.**

---

## Conventions used by every `lg-*` skill

These appear at the top of each skill, identically. Tasks below assume these as a starting block.

**Standard `<update-check>` block** (matches existing harness skills like `/learn`, `/deep-plan`):

````markdown
<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>
````

**Standard precondition gate** (right after update-check, before content):

````markdown
<langgraph-gate>
Run: `bash -c 'source "$(git rev-parse --show-toplevel)/.claude/hooks/harness.config.sh"; [ "$HARNESS_LANGGRAPH" = "true" ] && echo OK || echo OPT_IN_REQUIRED'`
- `OPT_IN_REQUIRED` → tell the user: "lg-* skills are opt-in. Run `./setup.sh` and answer 'yes' to LangGraph mode to enable." Then stop without doing the rest of the skill.
- `OK` → continue silently.
</langgraph-gate>
````

This block is part of the skill's instructions to Claude. The model executes the bash, reads the result, and either stops or continues — same pattern as `<update-check>`. **Skills MUST NOT do anything substantive before this gate passes.**

---

## Task 1: Add `HARNESS_LANGGRAPH` config flag

**Files:**
- Modify: `.claude/hooks/harness.config.sh:69-79` (insert after `HARNESS_REQUIRED_ENV_VARS`, before sprint-budget vars)

- [ ] **Step 1: Add the new variable to `harness.config.sh`**

Add this block right after the `HARNESS_REQUIRED_ENV_VARS` line (currently around line 69), keeping the existing comment style:

```bash
# Opt-in: enable the LangGraph skill set (/lg-design, /lg-scaffold, /lg-add,
# /lg-eval, /lg-review, /lg-cheatsheet). Skills are visible in the slash menu
# either way; with this set to "false" they print an opt-in hint and exit.
HARNESS_LANGGRAPH="${HARNESS_LANGGRAPH:-false}"
```

- [ ] **Step 2: Verify the variable parses**

Run: `bash -c 'source .claude/hooks/harness.config.sh && echo "HARNESS_LANGGRAPH=$HARNESS_LANGGRAPH"'`
Expected output: `HARNESS_LANGGRAPH=false`

- [ ] **Step 3: Verify the gate-check command works for both states**

Run: `bash -c 'source .claude/hooks/harness.config.sh; [ "$HARNESS_LANGGRAPH" = "true" ] && echo OK || echo OPT_IN_REQUIRED'`
Expected: `OPT_IN_REQUIRED`

Run: `bash -c 'HARNESS_LANGGRAPH=true; [ "$HARNESS_LANGGRAPH" = "true" ] && echo OK || echo OPT_IN_REQUIRED'`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add .claude/hooks/harness.config.sh
git commit -m "feat(lg): add HARNESS_LANGGRAPH opt-in flag

Default false. When true, the /lg-* skill family activates;
otherwise the skills print an opt-in hint and exit."
```

---

## Task 2: Add LangGraph prompt to `setup.sh`

**Files:**
- Modify: `setup.sh:112-145` (add prompt after `REQUIRED_ENV` read, then write the var into the generated config)

- [ ] **Step 1: Add the prompt**

Add this block in `setup.sh` immediately after the `read -p "Required env vars..."` line (currently line 112), before the heredoc that writes `harness.config.sh`:

```bash
echo ""
echo "LangGraph skill set (opt-in):"
echo "  Adds /lg-design, /lg-scaffold, /lg-add, /lg-eval, /lg-review,"
echo "  and /lg-cheatsheet for building LangChain/LangGraph agents."
read -p "Enable? [y/N]: " LG_CHOICE
LG_CHOICE="${LG_CHOICE:-N}"
case "$LG_CHOICE" in
  [Yy]*) HARNESS_LANGGRAPH="true" ;;
  *)     HARNESS_LANGGRAPH="false" ;;
esac
```

- [ ] **Step 2: Add the variable to the heredoc that generates `harness.config.sh`**

In the heredoc that starts with `cat > "$CONFIG" <<EOF` (currently around line 118), add this line right after `HARNESS_REQUIRED_ENV_VARS="${REQUIRED_ENV:-}"`:

```bash
HARNESS_LANGGRAPH="${HARNESS_LANGGRAPH}"
```

- [ ] **Step 3: Verify setup.sh runs cleanly with the new prompt**

Run: `bash -n setup.sh`  (syntax check only)
Expected: no output, exit code 0.

- [ ] **Step 4: Verify the prompt round-trips by running setup.sh in a temp dir**

```bash
TMPDIR=$(mktemp -d)
cp setup.sh "$TMPDIR/"
mkdir -p "$TMPDIR/.claude/hooks"
cd "$TMPDIR"
git init -q
echo "y" | bash setup.sh < /dev/null > /tmp/lg-setup-output.txt 2>&1 || true
grep -q 'HARNESS_LANGGRAPH="true"' .claude/hooks/harness.config.sh && echo "OK: y branch wrote true" || echo "FAIL: y branch missed true"
cd - > /dev/null
rm -rf "$TMPDIR"
```

Expected: `OK: y branch wrote true`. (Setup.sh has many prompts so input may be exhausted — this only validates the LG prompt's effect on the config write.)

If the smoke test is too brittle (setup.sh is interactive), instead just visually confirm by running `bash setup.sh` interactively, answering `y` at the LangGraph prompt, and checking `.claude/hooks/harness.config.sh` for `HARNESS_LANGGRAPH="true"`. Then re-run with `n` and confirm `"false"`.

- [ ] **Step 5: Commit**

```bash
git add setup.sh
git commit -m "feat(lg): add LangGraph opt-in prompt to setup.sh

Asks once during setup; default no. Writes HARNESS_LANGGRAPH to
harness.config.sh. Re-running setup re-prompts so users can flip later."
```

---

## Task 3: Bump VERSION to 0.6.0

**Files:**
- Modify: `VERSION:1`

- [ ] **Step 1: Update VERSION**

```bash
echo "0.6.0" > VERSION
```

- [ ] **Step 2: Verify**

Run: `cat VERSION`
Expected: `0.6.0`

- [ ] **Step 3: Commit**

```bash
git add VERSION
git commit -m "chore: bump version to 0.6.0

Minor bump for the new /lg-* skill family. Matches precedent:
0.4.0 added /office-hours, 0.5.0 added /learn."
```

---

## Task 4: Write `/lg-cheatsheet` skill

This skill is the load-bearing reference. The other five skills load it via the `Skill` tool to pull in v1 facts and the footgun list. **Build this first** so the others can reference it.

**Files:**
- Create: `.claude/skills/lg-cheatsheet/SKILL.md`

**Length target:** ~400 lines.

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p .claude/skills/lg-cheatsheet
```

- [ ] **Step 2: Write `SKILL.md`**

Frontmatter (exact, load-bearing — this is what causes the skill to fire on user intent):

```yaml
---
name: lg-cheatsheet
description: Quick reference for LangChain v1 / LangGraph v1 / Deep Agents — mental model, v1-current API surface, footgun list, deprecated patterns, JS/TS specifics, production checklist. Use when the user asks "what's the right way to do X in LangGraph", "how do streaming/checkpointers/HITL work", or any general LangGraph reference question. Other lg-* skills load this for shared context.
user-invocable: true
---
```

After the frontmatter, include the standard `<update-check>` block, then the standard `<langgraph-gate>` block (both copied verbatim from the "Conventions" section above).

Then the body — 17 sections, each a `## N. Title` heading. Use the exact section headers from spec §3.1 in this order:

1. `## 1. Mental model` — the 3-layer model (LangChain framework / LangGraph runtime / Deep Agents harness) plus LangSmith for observability. Include a short paragraph for each layer with import path examples.
2. `## 2. The v1-current API surface` — `createAgent` from `langchain` is the entry point (NOT `createReactAgent` from `@langchain/langgraph/prebuilt`). Middleware is the v1 extensibility surface. `message.contentBlocks` provider-agnostic typed view. Structured output now in agent loop. Stream-event node renamed `"agent"` → `"model"`. `context` parameter replaces `config.configurable`. Node 20+ required.
3. `## 3. State + reducers` — `Annotation.Root({...})`, `MessagesAnnotation.spec` spread for chat-shaped state, default reducer = overwrite (silent footgun). Show a 5-line code block with `typeof State.State` / `typeof State.Update`.
4. `## 4. Streaming map` — Runnable `stream` / `streamEvents` vs LangGraph `streamMode` enum (`values` / `updates` / `messages` / `messages-tuple` / `custom` / `debug` / `events` / `tasks` / `checkpoints`). Include the recommended FE pattern: multiplex `["messages","updates"]`. Note `subgraphs: true` flag for child token streams.
5. `## 5. Tools` — `tool()` from `@langchain/core/tools` + Zod schema; `model.bindTools(tools)`; `ToolNode` runs in parallel by default; error-mode config (`continue` / `error` / custom function).
6. `## 6. Persistence + memory three-layer` — checkpointer (per-thread; `MemorySaver` dev, `PostgresSaver` / `SqliteSaver` / `RedisSaver` / `MongoDBSaver` prod) + `BaseStore` (cross-thread, namespaced KV) + `summarizationMiddleware` (length). One short code block per layer.
7. `## 7. HITL` — `interrupt()` from `@langchain/langgraph` + `Command({ resume, update?, goto? })`. **Critical footgun callout: nodes restart on resume, so pre-interrupt code re-runs — guard external side effects.** Multi-interrupt resume map.
8. `## 8. Multi-agent` — `createSupervisor` from `@langchain/langgraph-supervisor`, `createSwarm` / `createHandoffTool` from `@langchain/langgraph-swarm`, `Send` for parallel fanout, `Command({ goto })` for handoff.
9. `## 9. Subgraphs` — shared-state-key auto-merge; subgraph streaming requires `subgraphs: true` option on `.stream()` and `.getState()`.
10. `## 10. Time travel` — replay via `app.invoke(null, target.config)`; `updateState` produces a fork (history is immutable).
11. `## 11. Deep Agents` — `deepagents` npm package; `createDeepAgent({ model, tools, systemPrompt, subAgents, middleware })`; four pillars (planning / sub-agents / FS / opinionated prompt); FS backends (`StateBackend` ephemeral, `StoreBackend` cross-thread, `Filesystem`, `Sandbox` — Daytona/Deno/Modal); v0.5 async sub-agents; `recursionLimit: 10000` default — bound explicitly.
12. `## 12. LangSmith setup` — env vars (`LANGSMITH_TRACING` / `LANGSMITH_API_KEY` / `LANGSMITH_PROJECT`); **`LANGCHAIN_CALLBACKS_BACKGROUND=false` in serverless** (else traces lost); `traceable()` for custom spans. Include the **"When you actually need it"** callout from spec §3.1 verbatim:

   ```markdown
   **When you actually need it:**
   - **Required for code to run:** never. Code runs cleanly with the env vars unset.
   - **Required for evals:** depends on mode (`/lg-eval` supports local-only Vitest/Jest mode without LangSmith; LangSmith-backed and hybrid modes need it).
   - **Recommended:** any multi-step agent with 5+ tool calls, all Deep Agents (the docs ship a `langsmith fetch` CLI specifically because Deep Agent traces are too long to read manually), production debugging, team collaboration, regression eval over weeks of iteration.
   - **Not needed:** 2-tool prototype agents, throwaway scripts, single-shot LLM calls.
   ```

13. `## 13. Evals` — dataset + target + evaluator; trajectory checks for agents; Vitest/Jest harness; `client.evaluate()` programmatic; the `evaluate-complex-agent` recipe; both local-only and LangSmith-backed modes possible.
14. `## 14. Top 10 footguns` — bullet list of the ten footguns from spec §3.1 sec 14 verbatim:
    - Reducer omission → silent overwrite.
    - Node-restart on resume → pre-interrupt side effects double-fire.
    - `MemorySaver` lost on serverless cold start.
    - Subgraph streaming requires `subgraphs: true`.
    - `Send` payload ≠ parent state.
    - Pre-binding tools breaks structured output.
    - Missing `subgraphs: true` on `getState()`.
    - Unbounded `recursionLimit` in Deep Agents.
    - Deep Agent FS persistence — `StateBackend` is ephemeral.
    - Message ID dedup in `MessagesAnnotation`.
    - Serverless `LANGCHAIN_CALLBACKS_BACKGROUND=true` losing traces.
15. `## 15. Deprecation list — DO NOT USE` — bullet list:
    - `createReactAgent` from `@langchain/langgraph/prebuilt` → use `createAgent` from `langchain`.
    - `AgentExecutor`, `initializeAgentExecutorWithOptions`, `createOpenAIFunctionsAgent` from `langchain/agents` → `createAgent`.
    - `langchain/chains` (legacy) → moved to `@langchain/classic/chains`.
    - LCEL pipe-chains for agentic flows → `createAgent` + middleware.
    - `dist/` direct imports → public entrypoints only (bundler output changed in v1).
    - `MemorySaver` in production → swap for `Postgres`/`Sqlite`/`Redis`/`Mongo` saver.
    - `config.configurable` for app-state → use new `context` parameter.
    - Legacy `./callbacks` entrypoint → use Runnable observability.
16. `## 16. Production checklist` — caching, rate limits, retries, fallbacks (`withFallbacks`), structured output (provider-native first), validators / guardrails (middleware), HITL, durability — bullet form, what to wire on day 1.
17. `## 17. Refresh hint` — closing block:

    ```markdown
    Last verified: 2026-04-26 against LangGraph v1.x / LangChain v1 / deepagents v0.5.

    To refresh:
    - https://github.com/langchain-ai/langgraphjs/releases
    - https://github.com/langchain-ai/langchainjs/releases
    - https://github.com/langchain-ai/deepagentsjs/releases
    - https://docs.langchain.com/oss/javascript/releases/changelog
    ```

The body is heavy on bullet form and short code blocks. Aim for ~400 lines total. Each section is 15-25 lines.

- [ ] **Step 3: Verify the file is well-formed**

Run: `head -10 .claude/skills/lg-cheatsheet/SKILL.md`
Expected: starts with `---\nname: lg-cheatsheet\n...` (frontmatter present).

Run: `wc -l .claude/skills/lg-cheatsheet/SKILL.md`
Expected: 350-450 lines.

Run: `grep -c '^## ' .claude/skills/lg-cheatsheet/SKILL.md`
Expected: 17 (one per numbered section).

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/lg-cheatsheet/SKILL.md
git commit -m "feat(lg): add /lg-cheatsheet reference skill

The load-bearing reference for the lg-* skill family. 17 sections
covering v1 API surface, footguns, deprecations, and the LangSmith
'when you actually need it' callout. Loaded by other lg-* skills via
the Skill tool to share context."
```

---

## Task 5: Write `/lg-design` skill

**Files:**
- Create: `.claude/skills/lg-design/SKILL.md`

**Length target:** ~250 lines.

- [ ] **Step 1: Create directory and write `SKILL.md`**

```bash
mkdir -p .claude/skills/lg-design
```

Frontmatter (exact):

```yaml
---
name: lg-design
description: Design a LangGraph agent before writing code. Asks structured questions about purpose, tools, persistence, HITL, streaming, memory; picks the right pattern (createAgent vs raw StateGraph vs Deep Agent vs supervisor/swarm); produces a design doc. Use when the user says "design an agent", "I'm building an agent that does X", "help me architect this LangGraph", or before any agent implementation work.
user-invocable: true
---
```

Body sections (use these exact `## Phase N` headings):

`## Phase 0: Load shared context` — invoke `/lg-cheatsheet` via the `Skill` tool to load the v1 facts. Single-line instruction.

`## Phase 1: Detect context` — bash to find the latest sprint dir:

```bash
LATEST_SPRINT=$(ls -d docs/plans/*-w* 2>/dev/null | sort -V | tail -1)
SPRINT_PLANS_DIR="${LATEST_SPRINT}/sprint-plans"
```

If `$LATEST_SPRINT` is non-empty and `$SPRINT_PLANS_DIR` exists, **sprint mode**: default output is `${SPRINT_PLANS_DIR}/<slug>-graph-design.md`. Otherwise **standalone mode**: default output is `docs/lg-designs/$(date +%Y-%m-%d)-<slug>.md`. Tell the user which mode the skill is in.

`## Phase 2: The eight forcing questions` — ask these **one at a time** using AskUserQuestion. Wait for the response before asking the next:

1. **Purpose** — "What does this agent do? One sentence."
2. **Trigger** — multi-choice: Interactive chat / API request (sync) / Cron / Webhook / Batch / Other.
3. **External surface area** — "What does it touch? APIs, DBs, files, MCP servers — list them." (free-form)
4. **Single agent or multi-agent** — multi-choice: Single agent / Supervisor + workers / Swarm (peer handoff) / Hierarchical / DIY with `Send`+`Command`.
5. **Run length** — multi-choice: Sub-second / Seconds / Minutes / Hours-days. Drives durability decisions.
6. **HITL** — multi-choice: None / Tool-call approval / Draft review (edit state) / Arbitrary checkpoint / Multiple.
7. **Streaming** — multi-choice: None / Token-level (chat UI) / Node-level (progress events) / Both.
8. **Memory** — multi-choice: Thread-only chat history / Cross-thread user facts (BaseStore) / Both / Plus summarization for length.

`## Phase 3: Pattern recommendation` — explicit decision tree, present to the user with reasoning:

- Simple tool-using agent + message-shaped state → **`createAgent`** from `langchain`.
- Custom topology / non-message state / branching control flow → **raw `StateGraph`**.
- Long-horizon planning + sub-agents + virtual FS → **Deep Agents** (`createDeepAgent`).
- Multi-agent coordination → **`createSupervisor`** or **`createSwarm`**.
- Combinations possible (`createAgent` *inside* a parent `StateGraph` is the common hybrid).

`## Phase 4: Graph design` — produce a structured design with these sub-sections (ask the user for confirmation on each before moving on):

- **State schema** — channels with reducers; `MessagesAnnotation.spec` spread.
- **Nodes & edges** — responsibility per node.
- **Tool list** — Zod schema sketches; parallel-tool-call posture.
- **Persistence** — checkpointer choice; `thread_id` strategy; when `BaseStore` enters.
- **HITL plan** — where `interrupt()` fires; `Command({ resume })` shape.
- **Streaming plan** — which modes the FE consumes; `useStream` if React.
- **Eval plan** — dataset shape; trajectory check examples; regression hook.
- **Middleware** — built-ins (`summarizationMiddleware`, `humanInTheLoopMiddleware`, `todoListMiddleware`); custom hooks (`wrapModelCall` / `wrapToolCall` / `beforeAgent` / `afterAgent`).
- **Observability** — LangSmith env vars; `LANGCHAIN_CALLBACKS_BACKGROUND` for the deployment target.

`## Phase 5: Premise challenge` — push back before locking. Ask each, accept user's response:

- "Could `createAgent` cover this without dropping to `StateGraph`?" (default: yes)
- "Are sub-agents actually needed or is this one agent with more tools?"
- "Is `MemorySaver` really fine for prod?" (default: no)
- "Will the FE actually consume the streaming mode you picked?"

`## Phase 6: Write the design doc` — to the path computed in Phase 1. Template (use as a heredoc):

````markdown
# Agent Design: <slug>

Generated by /lg-design on <date>
Branch: <git branch>
Mode: <sprint | standalone>

## Purpose
<one sentence>

## Trigger
<from Q2>

## External Surface Area
<from Q3>

## Pattern: <createAgent | StateGraph | Deep Agent | Supervisor | Swarm>

## State Schema
```ts
import { Annotation, MessagesAnnotation } from "@langchain/langgraph";

export const State = Annotation.Root({
  ...MessagesAnnotation.spec,
  // ...other channels with reducers
});
```

## Nodes & Edges
<table or list, responsibility per node>

## Tools
<list with Zod schema sketches>

## Persistence
<checkpointer choice + thread strategy + BaseStore use>

## HITL
<where interrupt() fires + Command shape>

## Streaming
<modes consumed + FE shape>

## Eval
<dataset + trajectory checks>

## Middleware
<list>

## Observability
<LangSmith env vars + LANGCHAIN_CALLBACKS_BACKGROUND posture>

## Premises (agreed during /lg-design)
<from Phase 5>

## Open questions
<anything unresolved>
````

`## Phase 7: Hand off` — final message to the user:

> "Design saved to `<path>`. Next: `/lg-scaffold <path>` to generate code."

If sprint mode, also recommend: "Link this design from your sprint plan's `## Skills` section."

- [ ] **Step 2: Verify file**

Run: `head -10 .claude/skills/lg-design/SKILL.md` — expect frontmatter with `name: lg-design`.

Run: `grep -c '^## Phase' .claude/skills/lg-design/SKILL.md` — expect 8 (Phase 0-7).

Run: `wc -l .claude/skills/lg-design/SKILL.md` — expect 200-300 lines.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/lg-design/SKILL.md
git commit -m "feat(lg): add /lg-design architecture-conversation skill

Eight forcing questions, pattern recommendation tree, premise
challenge, design-doc template. Detects open sprint context and
routes output accordingly."
```

---

## Task 6: Write `/lg-scaffold` skill

**Files:**
- Create: `.claude/skills/lg-scaffold/SKILL.md`

**Length target:** ~350 lines.

- [ ] **Step 1: Create directory and write `SKILL.md`**

```bash
mkdir -p .claude/skills/lg-scaffold
```

Frontmatter:

```yaml
---
name: lg-scaffold
description: Scaffold a new LangChain/LangGraph agent in TypeScript. Generates runnable code using LangChain v1 / LangGraph v1 patterns — `createAgent` (or raw `StateGraph` / Deep Agent) + tools + checkpointer + optional LangSmith tracing + streaming wiring. Use when the user says "scaffold an agent", "build me a LangGraph agent that does X", "create a Deep Agent", "start a new agent", or hands off from `/lg-design` with a design path.
user-invocable: true
---
```

Body sections (exact phase headings):

`## Phase 0: Load shared context` — invoke `/lg-cheatsheet` via Skill tool.

`## Phase 1: Input mode` — three branches:

- `/lg-scaffold <design-doc-path>` → read the design, scaffold from it.
- `/lg-scaffold "<one-liner>"` → ask 2-3 fast questions, scaffold the simple case.
- `/lg-scaffold` (no args) → ask: "Do you have a design doc, or want quick mode?"

`## Phase 2: Detect target project shape` — read `package.json`:

- Node version (`engines.node`); warn if `<20` since v1 requires Node 20+.
- Existing LangChain deps (`langchain`, `@langchain/langgraph`, `@langchain/openai`, `@langchain/anthropic`, `@langchain/core`, `langsmith`); generate `npm install` (using `$HARNESS_PKG_MGR`) for missing.
- TS or JS, ESM or CJS.
- Source dir from `harness.config.sh` (`HARNESS_SRC_DIRS`).

`## Phase 3: Pick file footprint` — propose this layout, get user nod:

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

Single-file mode (just `index.ts` + `graph.test.ts`) for the simplest cases (1-2 tools, no middleware).

`## Phase 4: Generate from template` — pick the template per pattern:

- **`createAgent`** template — `import { createAgent } from "langchain";` + plain model + tools list + middleware array + checkpointer + structured-output schema if requested. **Critical: do NOT pass a model already bound with tools (`model.bindTools(...)`); pass plain model + separate `tools` list.**
- **Raw `StateGraph`** template — `Annotation.Root` with reducers, `MessagesAnnotation.spec` spread, nodes typed via `typeof State.State` and `typeof State.Update`, `ToolNode` + `tools_condition`. Spec §3.3 has the exact code shape.
- **Deep Agent** template — `import { createDeepAgent } from "deepagents";` + sub-agent specs + FS backend choice (`StateBackend` ephemeral default; `StoreBackend` if cross-thread persistence chosen; `FilesystemBackend` for disk; sandbox backends for isolation). **Set `recursionLimit` explicitly — do not leave it at 10000 default.**
- **Multi-agent** template — `createSupervisor` from `@langchain/langgraph-supervisor` or `createSwarm` from `@langchain/langgraph-swarm`; or hand-rolled `Send` / `Command` if the design called for it.

For each pattern, include in the generated `graph.ts` a comment block linking back to the design doc (if scaffolded from one) and a one-liner referencing the relevant `/lg-cheatsheet` section.

`## Phase 5: Wire streaming` — if streaming was in the design, generate the consumer skeleton:

- Express/Fastify route → SSE handler that yields `["messages","updates"]` modes.
- Next.js route handler → ReadableStream pulling from `app.stream()`.
- React component → `useStream` hook example.
- None → skip.

If subgraphs are present, set `subgraphs: true` on the stream call.

`## Phase 6: Wire observability (opt-in)` — ask once: *"Wire LangSmith from day 1? Recommended for any multi-step agent; skip for a 2-tool prototype. (y/N)"*. Default no.

- **Yes branch:** generate `.env.example` with:
  ```
  LANGSMITH_TRACING=true
  LANGSMITH_API_KEY=
  LANGSMITH_PROJECT=<slug>
  # Serverless deployments only — uncomment to flush traces before exit
  # LANGCHAIN_CALLBACKS_BACKGROUND=false
  ```
  (If serverless target was confirmed in the design, uncomment the `LANGCHAIN_CALLBACKS_BACKGROUND` line and add an explanatory comment.)

- **No branch:** generate `.env.example` with:
  ```
  # LangSmith tracing — uncomment to enable.
  # See /lg-cheatsheet §12 for when LangSmith is worth wiring.
  # LANGSMITH_TRACING=true
  # LANGSMITH_API_KEY=
  # LANGSMITH_PROJECT=<slug>
  ```
  Code runs cleanly without these set.

`## Phase 7: Generate the smoke test` — `graph.test.ts` template:

```ts
import { describe, it, expect } from "vitest";  // or jest
import { MemorySaver } from "@langchain/langgraph";
import { createGraph } from "./graph";

describe("<slug> graph", () => {
  it("invokes without error and produces an AIMessage", async () => {
    const graph = createGraph({ checkpointer: new MemorySaver() });
    const result = await graph.invoke(
      { messages: [{ role: "user", content: "<smoke test input>" }] },
      { configurable: { thread_id: "smoke-test-1" } }
    );
    expect(result.messages.at(-1)?.role).toBe("assistant");
    expect(result.messages.at(-1)?.content).toBeTruthy();
  });
});
```

Use `vitest` or `jest` based on what's already in `package.json` (default vitest if neither).

`## Phase 8: Run smoke test` — execute `$HARNESS_TEST_CMD` against the new directory.

```bash
source .claude/hooks/harness.config.sh
if [ -z "$HARNESS_TEST_CMD" ]; then
  echo "No test command configured (HARNESS_TEST_CMD empty). Run the new test manually."
else
  $HARNESS_TEST_CMD src/agents/<slug>
fi
```

If the command exists but fails, surface the error and offer to fix. If it succeeds, print a one-line "OK: smoke test passed".

`## Phase 9: Hand off` — final message:

> "Scaffold done at `src/agents/<slug>/`. Next: `/lg-add <capability>` to wire HITL/persistence/streaming/sub-agents/middleware. Set up evals: `/lg-eval`."

- [ ] **Step 2: Verify file**

Run: `head -10 .claude/skills/lg-scaffold/SKILL.md` — frontmatter present.
Run: `grep -c '^## Phase' .claude/skills/lg-scaffold/SKILL.md` — expect 10 (Phase 0-9).
Run: `wc -l .claude/skills/lg-scaffold/SKILL.md` — expect 300-400 lines.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/lg-scaffold/SKILL.md
git commit -m "feat(lg): add /lg-scaffold code-generation skill

Generates runnable v1 agent code from a design doc or one-liner.
Templates for createAgent, raw StateGraph, Deep Agent, supervisor,
swarm. LangSmith opt-in (default no). Generates and runs smoke test."
```

---

## Task 7: Write `/lg-add` skill

**Files:**
- Create: `.claude/skills/lg-add/SKILL.md`

**Length target:** ~400 lines (seven capability switches each need a focused playbook).

- [ ] **Step 1: Create directory and write `SKILL.md`**

```bash
mkdir -p .claude/skills/lg-add
```

Frontmatter:

```yaml
---
name: lg-add
description: Add a capability to an existing LangGraph agent — HITL (`interrupt()` / humanInTheLoopMiddleware), persistence (checkpointer + thread strategy), streaming (token + node events), sub-agents, custom tools, middleware (summarization, PII redaction, rate-limit), or BaseStore for cross-thread memory. Use when the user says "add HITL to my agent", "make this graph durable", "wire streaming", "add a sub-agent", "attach a checkpointer", or any "add X to my LangGraph" phrasing.
user-invocable: true
---
```

Body sections (exact phase headings):

`## Phase 0: Load shared context` — invoke `/lg-cheatsheet`.

`## Phase 1: Identify target` — invocation forms:

- `/lg-add <capability> <path>` → both args explicit.
- `/lg-add <capability>` → glob `src/**/{graph,index}.ts` for graphs, ask if multiple.
- `/lg-add` → ask both questions.

Capability set: `hitl` | `persist` | `stream` | `subagent` | `tool` | `middleware` | `store`.

`## Phase 2: Read target graph` — extract:

- **Pattern** — `createAgent` / `StateGraph` / Deep Agent (detect by import paths and exported value).
- **State schema** (if `StateGraph`).
- **Existing nodes**.
- **Existing checkpointer** (in `compile({ checkpointer })` call).
- **Existing middleware** (in `createAgent({ middleware })` array).
- **Deprecated patterns** — if `createReactAgent` from `@langchain/langgraph/prebuilt` is detected, print a warning and recommend `/lg-review` first. Don't block; user may have a reason.

`## Phase 3: Capability switch` — branch on `<capability>`. Each branch is its own H3 sub-section.

`### 3.1 hitl` — Human-in-the-loop:

- **createAgent path:** add `humanInTheLoopMiddleware` to the `middleware` array. Provide a config callback that decides which tool calls to gate (default: all). Generate the resume handler example.
- **StateGraph path:** insert `interrupt()` call at the right node. Ensure a checkpointer is present (require user to add one if not — block this capability behind it). Generate the resume handler.
- **Print the idempotency warning verbatim:**
  > "Pre-interrupt code re-runs on resume. Guard external side effects (HTTP calls, DB writes, email sends) with idempotency keys or move them after `interrupt()`."

`### 3.2 persist` — Checkpointer:

- Ask: `MemorySaver` (dev only) / `SqliteSaver` (single-process) / `PostgresSaver` (prod) / `RedisSaver`.
- Generate install command for the chosen package using `$HARNESS_PKG_MGR`:
  - Memory: ships with `@langchain/langgraph` (no install).
  - Sqlite: `@langchain/langgraph-checkpoint-sqlite`.
  - Postgres: `@langchain/langgraph-checkpoint-postgres`.
  - Redis: `@langchain/langgraph-checkpoint-redis`.
- For Postgres, add `await saver.setup()` once-at-boot.
- Add `thread_id` to invoke call sites if missing — show the user where they are and edit them.

`### 3.3 stream` — Streaming:

- Detect FE shape. Read `package.json` for: `next`, `express`, `fastify`, `react`. Ask if none clear.
- Generate the consumer skeleton based on FE:
  - Next.js → `app/api/<slug>/route.ts` with `ReadableStream`.
  - Express/Fastify → SSE route handler.
  - React → `useStream` example component.
- Default to multiplexing `["messages","updates"]`.
- If subgraphs present, pass `subgraphs: true` to `.stream()`.

`### 3.4 subagent` — Sub-agents:

- **Deep Agents path:** add a `SubAgent` spec object to `subAgents` array; suggest sync vs `AsyncSubAgent` based on expected duration.
- **createAgent / StateGraph path:** scaffold a separate sub-graph file + a parent supervisor edge. Use `Command({ goto })` for handoff.

`### 3.5 tool` — Custom tool:

- Ask name, description, schema fields.
- Generate `tool()` call with Zod schema in `tools.ts` (or inline if single-file).
- Wire into the agent's `tools` list.
- Generate `tool.test.ts` with one happy-path test and one schema-validation test.

`### 3.6 middleware` — Middleware:

- Ask: prebuilt or custom?
- Prebuilt options: `summarizationMiddleware`, `humanInTheLoopMiddleware`, `todoListMiddleware`, PII redaction, rate-limit. Show their import paths.
- Custom: scaffold a function with the four hooks (`wrapModelCall`, `wrapToolCall`, `beforeAgent`, `afterAgent`). Only fill in the ones the user wants.

`### 3.7 store` — BaseStore (cross-thread memory):

- Pick implementation: `InMemoryStore` (dev) or `PostgresStore` (prod).
- Generate install for the chosen package.
- Inject `config.store` into nodes that need it via `runnable.invoke(input, { configurable: { thread_id }, store })` pattern.
- Default namespace strategy: `["users", userId, "<facet>"]`.

`## Phase 4: Make edits` — use `Edit` tool. Post-edit hook re-runs Prettier automatically; no manual formatting needed.

`## Phase 5: Update tests` — extend `graph.test.ts` (or generate `<capability>.test.ts`) with a smoke test for the new capability:

- `hitl` — invoke, expect `interrupt`-shaped result, resume with `Command({ resume })`, expect completion.
- `persist` — invoke twice with same `thread_id`, expect message history continuity.
- `stream` — `app.stream()` yields chunks; assert at least one `messages` event.
- `subagent` — invoke, expect sub-agent's tool to fire.
- `tool` — happy path + schema validation.
- `middleware` — middleware hook fires (mock or count).
- `store` — write then read via store; assert namespace isolation.

`## Phase 6: Run tests` — `$HARNESS_TEST_CMD`. Fix or surface.

`## Phase 7: Print follow-up` — capability-specific. Examples:

- `hitl` → "Resume handler at `<path>:<line>`. Idempotency note: pre-interrupt code re-runs on resume — guard external side effects."
- `persist` → "Checkpointer wired. `thread_id` strategy: `<chosen>`. For prod, set the connection-string env var before deploy."
- `stream` → "Stream consumer at `<path>`. FE multiplexes `messages`+`updates`."
- (etc for the rest)

- [ ] **Step 2: Verify file**

Run: `head -10 .claude/skills/lg-add/SKILL.md` — frontmatter.
Run: `grep -c '^### 3\.' .claude/skills/lg-add/SKILL.md` — expect 7 (one per capability).
Run: `wc -l .claude/skills/lg-add/SKILL.md` — expect 350-450 lines.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/lg-add/SKILL.md
git commit -m "feat(lg): add /lg-add capability-modifier skill

Seven capability switches: hitl, persist, stream, subagent, tool,
middleware, store. Reads existing graph, makes targeted edits,
generates per-capability smoke tests."
```

---

## Task 8: Write `/lg-eval` skill

**Files:**
- Create: `.claude/skills/lg-eval/SKILL.md`

**Length target:** ~350 lines (dual-mode templates).

- [ ] **Step 1: Create directory and write `SKILL.md`**

```bash
mkdir -p .claude/skills/lg-eval
```

Frontmatter:

```yaml
---
name: lg-eval
description: Set up evals for a LangGraph/LangChain agent in either local-only mode (Vitest/Jest assertions, no upload) or LangSmith-backed mode (datasets, experiment tracking, regression bound to a dataset, online evals against prod traces). Trajectory checks (right tools called in right order), final-answer correctness, smoke/hallucination checks, custom evaluators (rule-based + LLM-as-judge). Use when the user says "add evals", "write a regression test for my agent", "set up LangSmith evals", "check the agent's trajectory", or "I broke something — write the test first".
user-invocable: true
---
```

Body sections — follows spec §3.5 exactly. Phase headings:

`## Phase 0: Load shared context` — invoke `/lg-cheatsheet`.

`## Phase 1: Detect target` — `/lg-eval <agent-path>` or skill globs `src/agents/**` and asks. Read the agent file to understand state shape, tools, pattern.

`## Phase 2: Pick eval mode` — single-select via AskUserQuestion. **This is the load-bearing decision.**

- **Local-only** — Vitest/Jest assertions on agent output. No LangSmith account, no upload. Best for: prototyping, CI without external dependencies, simple agents with deterministic-ish output.
- **LangSmith-backed** — full experiment tracking, datasets in the dashboard, online evals against prod traces, dataset-bound regressions. Best for: multi-step agents, Deep Agents, anything iterated for weeks.
- **Hybrid** — local fixtures committed to git, evaluators usable both ways; `$HARNESS_PKG_MGR run eval` runs locally, `$HARNESS_PKG_MGR run eval:remote` uploads to LangSmith. Best for: shipping projects that need both PR-time signal and dashboard view.

`## Phase 3: Detect prerequisites` (mode-dependent):

- **All modes:** test runner (Vitest or Jest) — read `package.json`. Default Vitest if neither. Generate install for `langsmith` package if mode is LangSmith-backed or hybrid (the `evaluate()` helper lives there even when running locally — it accepts a no-op LangSmith client).
- **LangSmith-backed / hybrid:** check for `LANGSMITH_API_KEY` in `.env`/`.env.local`/process env. **If missing, prompt user to add (don't write secrets).** If user declines, downgrade to local-only mode and continue with a one-line note explaining the downgrade.
- **Local-only:** no API key needed. Skip API-key prompts.

`## Phase 4: Eval check picker` — multi-select via AskUserQuestion:

- Final-answer correctness (LLM-as-judge or exact match).
- Trajectory check (tool-call ordering / tool absence).
- Regression suite (dataset-bound evaluators auto-run on every experiment).
- Online eval — **only available in LangSmith-backed/hybrid modes**; greyed out (do not show) in local-only.
- Smoke / hallucination check (no empty AIMessage; respects `recursionLimit`).

`## Phase 5: Dataset scaffolding` (mode-dependent):

- **Local-only:** generate `evals/datasets/<slug>.ts` — a TS array of `{ input, reference }` objects. Pre-populate with 3 example rows derived from the agent's purpose.
- **LangSmith-backed:** generate `evals/upload-<slug>.ts` — a script using `client.createDataset(...)` + `client.createExamples(...)`. Inline fixtures NOT generated.
- **Hybrid:** generate inline fixtures committed to git, plus a sync script `evals/sync-<slug>.ts` (and a `eval:sync` package.json script using `$HARNESS_PKG_MGR`).

`## Phase 6: Evaluator scaffolding` (same shape regardless of mode — evaluators are pure functions):

For each picked check, generate the evaluator:

- **Rule-based** — TS function `(run, example) => { score: number, comment: string }`. Trajectory checks parse `run.outputs.messages` for `tool_calls` ordering.
- **LLM-as-judge** — prompt template + ChatModel call returning `{ score, comment }`. In LangSmith mode, wrap with `LLMEvaluator` from `langsmith/evaluation`; in local-only, call the model directly.
- **Structured-output check** — Zod schema validation against final state.

`## Phase 7: Test harness` (mode-dependent shape):

- **Local-only:** generate `evals/<slug>.eval.test.ts` using plain Vitest/Jest. Iterate the dataset, call the agent, run each evaluator, `expect()` the score thresholds. Runs as part of the regular test suite or via the `eval` script.
- **LangSmith-backed / hybrid:** generate `evals/<slug>.eval.ts` calling `evaluate(agent, { data, evaluators, experimentPrefix })`. Hybrid generates **both** files.

Show explicit `import { evaluate } from "langsmith/evaluation"` or `import { describe, it, expect } from "vitest"` based on mode.

`## Phase 8: Wire to CI` — add an `eval` script to `package.json` (separate from the `test` script). Use `$HARNESS_PKG_MGR run eval` for invocation. For hybrid, also add `eval:sync` and `eval:remote`. Optionally generate a GitHub Action triggered on PR-tag `eval`. **For local-only mode, the GitHub Action runs cleanly without secrets** — no `LANGSMITH_API_KEY` needed in repo secrets.

`## Phase 9: First run` — execute `$HARNESS_PKG_MGR run eval`:

- **Local-only:** assertions pass/fail via the test runner; print pass/fail summary.
- **LangSmith-backed / hybrid:** surface LangSmith experiment URL. If `LANGSMITH_API_KEY` missing at this point (user added then removed, or env wonky), stop and prompt instead of silently failing.

`## Phase 10: Print follow-up`:

> "Mode: `<local-only | langsmith | hybrid>`. Dataset at `evals/datasets/<slug>.ts`, evaluators at `evals/<slug>.eval.ts`, [experiment URL if LangSmith]. To add an evaluator: re-run `/lg-eval add-evaluator`."

- [ ] **Step 2: Verify file**

Run: `head -10 .claude/skills/lg-eval/SKILL.md` — frontmatter.
Run: `grep -c '^## Phase' .claude/skills/lg-eval/SKILL.md` — expect 11 (Phase 0-10).
Run: `wc -l .claude/skills/lg-eval/SKILL.md` — expect 300-400 lines.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/lg-eval/SKILL.md
git commit -m "feat(lg): add /lg-eval evals skill

Three modes: local-only (Vitest/Jest, no upload), LangSmith-backed
(experiments + datasets), hybrid (both). Trajectory checks,
final-answer correctness, regression suite, smoke/hallucination
checks. Mode picker downgrades gracefully to local-only if
LANGSMITH_API_KEY missing."
```

---

## Task 9: Write `/lg-review` skill

**Files:**
- Create: `.claude/skills/lg-review/SKILL.md`

**Length target:** ~350 lines.

- [ ] **Step 1: Create directory and write `SKILL.md`**

```bash
mkdir -p .claude/skills/lg-review
```

Frontmatter:

```yaml
---
name: lg-review
description: Review existing LangChain/LangGraph code for v1 best practices, deprecated patterns, and footguns. Catches legacy `createReactAgent`/`AgentExecutor`/`langchain/agents`, missing reducers, `MemorySaver` in production, pre-bound tools breaking structured output, missing observability, missing `subgraphs: true`, node-restart idempotency hazards, unbounded `recursionLimit`. Doubles as the migration scout for v0→v1 upgrades. Use when the user says "review my agent", "is this LangGraph code current", "audit this for footguns", "help me migrate from v0", or "find the bug in my graph".
user-invocable: true
---
```

Body — follows spec §3.6 exactly. Phase headings:

`## Phase 0: Load shared context` — invoke `/lg-cheatsheet`.

`## Phase 1: Scope` — `/lg-review <path>` (file/dir) or `/lg-review` (asks; defaults to `src/agents/**`). **Read-only by default — no edits without explicit user OK in Phase 5.**

`## Phase 2: Static checks` — run a pass per category. Each finding cites `file:line`. Use Grep tool to find each pattern; do NOT exec arbitrary code.

`### 2.1 Deprecation pass (BLOCKING)`

For each pattern below, grep the target paths. For each match, record `file:line` and the recommended replacement.

| Pattern | Recommended replacement |
|---|---|
| `from ['"]@langchain/langgraph/prebuilt['"]` (when importing `createReactAgent`) | `import { createAgent } from "langchain";` |
| `AgentExecutor`, `initializeAgentExecutorWithOptions`, `createOpenAIFunctionsAgent` | `createAgent` from `langchain` |
| `from ['"]langchain/agents['"]`, `from ['"]langchain/chains['"]` | `langchain` (top-level) or `@langchain/classic/chains` |
| LCEL pipe-chains as agent loops (`prompt.pipe(llm).pipe(parser)` repeating with retry logic) | `createAgent` + middleware |
| `dist/` direct imports from any `@langchain/*` package | public entrypoints only |
| `config.configurable` carrying app state (vs `thread_id`/`store`) | new `context` parameter |

`### 2.2 Correctness pass (BLOCKING)`

| Pattern | Why it's wrong |
|---|---|
| `Annotation<<X[]>>({...})` channel without a reducer | silent overwrite per node |
| `Annotation.Root({...})` for chat-shaped state without `MessagesAnnotation.spec` spread | no append, no dedupe |
| `{ role: "user", content: "..." }` raw objects (vs `HumanMessage`/`AIMessage` constructors) | message ID dedup broken |
| `model.bindTools(tools)` then `createAgent({ llm: bound, tools })` | structured-output collision |
| `interrupt()` in a node where pre-interrupt code calls `fetch`/`db.x()`/`sendMail()` without an idempotency guard | restart hazard |
| `new Send("name", state)` where the payload references parent state shape (vs the target's input shape) | mismatch |

`### 2.3 Production pass (WARNING)`

| Pattern | Recommendation |
|---|---|
| `MemorySaver` outside `*.test.ts` / `dev.ts` | `Postgres`/`Sqlite`/`Redis` saver |
| Missing `LANGSMITH_TRACING` setup or `traceable()` on hot paths | wire LangSmith (per `/lg-cheatsheet` §12 guidance) |
| Serverless deploy target without `LANGCHAIN_CALLBACKS_BACKGROUND=false` | set the env var or traces will be lost |
| `recursionLimit` left at default (10000) in Deep Agents | bound explicitly — money/time risk |
| Subgraph in graph but `.stream()` / `.getState()` without `subgraphs: true` | child events invisible |
| Stateful agent with no checkpointer at all | no resume, no HITL, no replay |
| No `withFallbacks([backup])` on production model calls | single point of failure |
| Tools that hit external systems with no retry config | flaky |

`### 2.4 Style pass (NIT)`

| Pattern | Fix |
|---|---|
| `: any` in node return types | `typeof State.Update` |
| Tool descriptions < 1 sentence | LLM tool-pick quality suffers |
| Tool schemas not Zod | lose JSON-schema introspection |
| `as any` casts in graph construction | break type safety |

`## Phase 3: Synthesize` — produce a punch list grouped by severity:

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

Save the punch list to `docs/lg-reviews/$(date +%Y-%m-%d)-<slug>.md` for audit trail.

`## Phase 4: Migration mode detection` — count BLOCKING deprecation hits. If ≥3, offer:

> "This looks like a v0→v1 migration. Run a full migration in one pass? Yes / Step-by-step / Just print the plan."

If yes, continue to Phase 5 with a migration-pass-style fix mode (apply all BLOCKING deprecations, then BLOCKING correctness, then WARNINGs in one round, run tests after each group).

`## Phase 5: Offer fixes` — AskUserQuestion: *"Want me to apply the BLOCKING fixes? (y/n/select)"*. If yes, switch to write-mode and apply with `Edit`. WARNINGs and NITs default to "leave for user". Re-run `$HARNESS_TEST_CMD` after fixes.

`## Phase 6: Final report` — print the punch list (whether or not fixes were applied), saved to `docs/lg-reviews/$(date +%Y-%m-%d)-<slug>.md`.

- [ ] **Step 2: Verify file**

Run: `head -10 .claude/skills/lg-review/SKILL.md` — frontmatter.
Run: `grep -c '^## Phase' .claude/skills/lg-review/SKILL.md` — expect 7 (Phase 0-6).
Run: `wc -l .claude/skills/lg-review/SKILL.md` — expect 300-400 lines.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/lg-review/SKILL.md
git commit -m "feat(lg): add /lg-review audit skill

Read-only static analysis of LangChain/LangGraph code against v1
best practices. Four passes: deprecation (BLOCKING), correctness
(BLOCKING), production (WARNING), style (NIT). Doubles as v0→v1
migration scout when ≥3 deprecation hits found."
```

---

## Task 10: Patch `/plan-sprint` for LangGraph awareness

**Files:**
- Modify: `.claude/skills/plan-sprint/SKILL.md`
- Read first to identify exact insertion points before editing.

- [ ] **Step 1: Read the existing skill to find injection points**

Run: `wc -l .claude/skills/plan-sprint/SKILL.md` — confirm size hasn't changed since spec was written (currently 237 lines).

Find where the plan template is defined. Run: `grep -n '^### Plan template\|^## File Footprint\|^## Test Plan\|^## Implementation' .claude/skills/plan-sprint/SKILL.md`

Confirm injection points:
- New phase block goes between Phase 1 (Gather context) and Phase 2 (Propose the breakdown). Detection happens in Phase 1.5.
- New `## Skills` section in plan template goes between `## Implementation` and `## Test Plan` (around current line 130).

- [ ] **Step 2: Add the agent-detection step**

Insert this block right after Phase 1 ("Gather context") and before Phase 2 ("Propose the breakdown"):

```markdown
## Phase 1.5: LangGraph awareness (skip if no agent work)

For each goal/project, check whether it involves LangChain/LangGraph agent work. Match against this regex (case-insensitive):

```
/(langgraph|langchain|deep ?agent|\b(ai|llm|chat) ?agent\b|tool ?calling|HITL|interrupt\(\)|checkpointer|state ?graph|create ?agent)/i
```

(Bare `\bagent\b` is intentionally excluded — the harness uses "agent" for sub-agents like validator/builder. Require an LLM-context qualifier or LangGraph-specific term to avoid false positives.)

If the goal matches:

1. **Recommend pre-planning architecture.** Tell the user: *"This goal involves agent work. Recommend running /lg-design first to produce a graph design before the plan locks. Run now?"* (AskUserQuestion: Yes / No / Skip.)

2. **If yes**, invoke `/lg-design` via the `Skill` tool. The skill detects the open sprint dir and writes its design doc to `docs/plans/YYYY-wNN/sprint-plans/<slug>-graph-design.md`. Wait for it to complete, then resume here with the design doc path.

3. **When generating the per-goal plan in Phase 3**, populate the `## Skills` section (see updated plan template) with `lg-*` skill references for each capability the goal needs. The graph design doc, if produced, gets linked from the goal's plan body.
```

- [ ] **Step 3: Add the `## Skills` section to the plan template**

Find the plan template block in the file (around line 99-150, between `### Plan template` and the end of Phase 3). Insert this block right after the `## Implementation` section in the template, before `## Test Plan`:

```markdown
## Skills

(For LangGraph/agent work only — omit if not applicable.)

- `/lg-scaffold` — generate v1 code from the design doc
- `/lg-add <capability>` — for each capability listed below
- `/lg-eval` — set up the eval harness referenced in success criteria

Design doc: <path to graph-design.md, if produced by /lg-design>
```

- [ ] **Step 4: Verify the patch**

Run: `wc -l .claude/skills/plan-sprint/SKILL.md` — expect ~250-260 (was 237 before).

Run: `grep -n '^## Phase 1\.5\|^## Skills$\|langgraph|langchain' .claude/skills/plan-sprint/SKILL.md` — expect at least 3 lines (the new phase header, the new template section header, and the regex).

Run: `grep -c '/lg-design\|/lg-scaffold\|/lg-add\|/lg-eval' .claude/skills/plan-sprint/SKILL.md` — expect ≥4.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/plan-sprint/SKILL.md
git commit -m "feat(plan-sprint): detect LangGraph goals, recommend /lg-design

Adds Phase 1.5: agent-work detection regex and a recommendation to
run /lg-design before locking the plan. Adds a ## Skills section to
the plan template so build-plan and downstream lg-* skills get the
right cross-references."
```

---

## Task 11: Patch `/build-plan` description note

**Files:**
- Modify: `.claude/skills/build-plan/SKILL.md:1-5` (frontmatter only)

- [ ] **Step 1: Read current frontmatter**

Run: `head -5 .claude/skills/build-plan/SKILL.md`

Expected current content:

```yaml
---
name: build
description: Execute a sprint plan end-to-end — branch, implement, test, verify in browser, commit incrementally, and prepare for PR. Pass it a sprint plan document path.
user-invocable: true
---
```

- [ ] **Step 2: Edit the description to add the lg-* note**

Replace the `description:` line with:

```yaml
description: Execute a sprint plan end-to-end — branch, implement, test, verify in browser, commit incrementally, and prepare for PR. Pass it a sprint plan document path. When plan steps involve LangGraph/LangChain agent work, /lg-* skills auto-fire (lg-scaffold, lg-add, lg-eval, lg-review).
```

- [ ] **Step 3: Verify**

Run: `head -5 .claude/skills/build-plan/SKILL.md`
Expected: the description line includes "When plan steps involve LangGraph".

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/build-plan/SKILL.md
git commit -m "docs(build-plan): note that lg-* skills auto-fire on agent work

No behavior change — auto-fire is by description-match. This line
just makes the cross-reference visible in the skill registry."
```

---

## Task 12: Update README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add LangGraph mention under "What you get"**

Find the "What you get" section (currently around line 39). Right after the bullet about `/learn` (currently around line 49), add:

```markdown
**LangGraph track (opt-in).** Six `/lg-*` skills for building LangChain v1 / LangGraph v1 / Deep Agents work in TS — design (`/lg-design`), scaffold (`/lg-scaffold`), capability adds (`/lg-add`), evals (`/lg-eval`), audit (`/lg-review`), and a v1-current cheatsheet. Default off; enable during `./setup.sh`.
```

- [ ] **Step 2: Add an "lg-*" row in the All skills table**

Find the "All skills" details block (currently around line 117). After the existing Operations subsection, add a new subsection:

```markdown
**LangGraph (opt-in via `./setup.sh`)**

| Skill | When | Purpose |
|---|---|---|
| `/lg-design` | Before agent code | Design conversation, picks pattern, produces design doc |
| `/lg-scaffold` | New agent | Generates runnable v1 code (createAgent / StateGraph / Deep Agent) |
| `/lg-add` | Existing agent | Adds HITL / persistence / streaming / sub-agent / tool / middleware / store |
| `/lg-eval` | After scaffold | LangSmith or local-only eval harness with trajectory checks |
| `/lg-review` | Anytime | Audits for v1 best practices, deprecated patterns, footguns |
| `/lg-cheatsheet` | Reference | v1 API, footgun list, deprecation list |
```

- [ ] **Step 3: Verify**

Run: `grep -c '/lg-' README.md` — expect ≥10 (one per row + the "What you get" mention).

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(readme): add LangGraph track to skills table

Six new opt-in skills under /lg-*. README now lists them in the
All skills section and mentions the track under What you get."
```

---

## Task 13: End-to-end smoke verification

**Files:** none modified — this task verifies the previous twelve.

- [ ] **Step 1: Run harness-health to verify nothing regressed**

```bash
bash bin/harness-update-check
```

Expected: no error output (or `JUST_UPGRADED 0.5.0 0.6.0` if first run after VERSION bump).

If `/harness-health` skill exists and is invocable:

```bash
# In a Claude Code session: invoke /harness-health
# Expect: green checks for hooks executable, settings wired, config populated
```

- [ ] **Step 2: Verify all six new skill files have the required structure**

```bash
for skill in lg-cheatsheet lg-design lg-scaffold lg-add lg-eval lg-review; do
  file=".claude/skills/${skill}/SKILL.md"
  echo "=== $file ==="
  if [ ! -f "$file" ]; then
    echo "  MISSING"
    continue
  fi
  # Frontmatter present
  head -5 "$file" | grep -q "^name: $skill" && echo "  ✓ frontmatter name" || echo "  ✗ frontmatter name"
  head -10 "$file" | grep -q "^user-invocable: true" && echo "  ✓ user-invocable" || echo "  ✗ user-invocable"
  # Update-check block
  grep -q "<update-check>" "$file" && echo "  ✓ update-check" || echo "  ✗ update-check"
  # LangGraph gate
  grep -q "<langgraph-gate>\|HARNESS_LANGGRAPH" "$file" && echo "  ✓ langgraph-gate" || echo "  ✗ langgraph-gate"
done
```

Expected: every check prints `✓` for every skill.

- [ ] **Step 3: Verify the opt-in path exits cleanly when `HARNESS_LANGGRAPH=false`**

```bash
HARNESS_LANGGRAPH=false bash -c 'source .claude/hooks/harness.config.sh; [ "$HARNESS_LANGGRAPH" = "true" ] && echo OK || echo OPT_IN_REQUIRED'
```

Expected: `OPT_IN_REQUIRED`.

- [ ] **Step 4: Verify the opt-in path passes when `HARNESS_LANGGRAPH=true`**

```bash
HARNESS_LANGGRAPH=true bash -c '[ "$HARNESS_LANGGRAPH" = "true" ] && echo OK || echo OPT_IN_REQUIRED'
```

Expected: `OK`.

- [ ] **Step 5: Verify VERSION**

Run: `cat VERSION`
Expected: `0.6.0`

- [ ] **Step 6: Manual session test (recommended but not commitable)**

In a fresh Claude Code session inside this repo:

1. Invoke `/lg-cheatsheet` — should fire and load the reference (or print the opt-in hint if `HARNESS_LANGGRAPH=false`).
2. Run `./setup.sh` and answer `y` to the LangGraph prompt.
3. Re-invoke `/lg-cheatsheet` — should now load the full content.
4. Try `/lg-design` against a dummy goal ("design an agent that summarizes RSS feeds"). Confirm the eight questions fire one at a time.

Document the session result inline (no file artifact).

- [ ] **Step 7: Final commit**

If all verifications pass, no further code changes are needed. If any failed, return to the relevant task and fix.

```bash
# No file changes; this is a verification step only.
echo "Smoke verification complete — all 13 tasks done."
```

---

## Execution notes

- **Order matters for skills:** `lg-cheatsheet` first (Task 4), then the others (Tasks 5-9). The other skills `Skill`-invoke `lg-cheatsheet`, so it must exist when they're tested. Tasks 1-3 (plumbing) can happen before, after, or in parallel — they're independent of skill content.
- **Tasks 10-12** (patches to existing skills + README) only depend on the new skill files existing by name. They can happen any time after Task 9.
- **Task 13** (smoke) runs last.
- **Parallelizable groups:**
  - Group A (foundation, sequential): Task 1 → Task 2 → Task 3
  - Group B (skills, sequential within group, parallel-safe across files since each is its own file): Task 4 → (Tasks 5, 6, 7, 8, 9 in parallel)
  - Group C (integration, parallel-safe): Tasks 10, 11, 12 in parallel
  - Group D (verification): Task 13
- Each task ends with a commit. **Commit frequently — never batch unrelated changes into a single commit.**
- If a step's verification command fails, **stop and diagnose root cause** before fixing. Don't paper over.
