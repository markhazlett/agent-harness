---
name: lg-review
description: Review existing LangChain/LangGraph code for v1 best practices, deprecated patterns, and footguns. Catches legacy `createReactAgent`/`AgentExecutor`/`langchain/agents`, missing reducers, `MemorySaver` in production, pre-bound tools breaking structured output, missing observability, missing `subgraphs: true`, node-restart idempotency hazards, unbounded `recursionLimit`. Doubles as the migration scout for v0→v1 upgrades. Use when the user says "review my agent", "is this LangGraph code current", "audit this for footguns", "help me migrate from v0", or "find the bug in my graph".
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

# /lg-review

Read-only static audit of your LangChain/LangGraph code against v1 best practices and the current deprecation list. Analysis comes first — fixes are offered only after the full punch list is presented and the user explicitly approves. Results are saved to `docs/lg-reviews/` for audit trail.

## Phase 0: Load shared context

Invoke `/lg-cheatsheet` via the Skill tool before doing anything else:

```
Skill: lg-cheatsheet
```

The deprecation list (§15) and footgun list (§14) from the cheatsheet ARE the authoritative audit criteria for this review. The cheatsheet also carries the v1-current API surface (§2), which determines what counts as deprecated vs current. Do not proceed to Phase 1 until the cheatsheet context is loaded — the audit criteria live there, not here.

## Phase 1: Scope

Accept the target path from the invocation: `/lg-review <path>` where `<path>` is a file, directory, or glob.

If no path is provided, ask the user:

> "Which file or directory should I audit? (default: `src/agents/**`)"

Accept the default if the user presses enter without specifying. The default covers the standard scaffold output from `/lg-scaffold`.

**Read-only by default — no edits to any file without explicit user OK in Phase 5. Announce this constraint at the start of the audit.**

Note the target path. All Grep tool calls in Phase 2 scope to this path. If the path is a directory, grep recursively (pass the directory to Grep's `path` param). If it is a single file, grep that file only.

## Phase 2: Static checks

Run one pass per category below. Use the **Grep tool** to find each pattern — do NOT execute arbitrary code, do NOT use Bash with `grep` or `rg` as a fallback. Every finding must cite `file:line`. Track all findings in a running list; you will synthesize them in Phase 3.

Within each pass, run Grep for each pattern in the table. If a pattern finds nothing, note "none found" for that entry. Do not skip patterns. Run passes in order: 2.1, 2.2, 2.3, 2.4.

### 2.1 Deprecation pass (BLOCKING)

For each pattern, grep the target paths. Record `file:line` and the recommended replacement.

| Pattern | Recommended replacement |
|---|---|
| `from ['"]@langchain/langgraph/prebuilt['"]` (when importing `createReactAgent`) | `import { createAgent } from "langchain";` |
| `AgentExecutor`, `initializeAgentExecutorWithOptions`, `createOpenAIFunctionsAgent` | `createAgent` from `langchain` |
| `from ['"]langchain/agents['"]` or `from ['"]langchain/chains['"]` | `langchain` (top-level) or `@langchain/classic/chains` |
| LCEL pipe-chains as agent loops (`prompt.pipe(llm).pipe(parser)` with retry logic) | `createAgent` + middleware |
| `dist/` direct imports from any `@langchain/*` package (e.g. `@langchain/core/dist/`) | public entrypoints only |
| `config.configurable` carrying app state (vs `thread_id`/`store`) | new `context` parameter |
| `Annotation.Root` for state | `StateSchema` from `@langchain/langgraph` (legacy still works, prefer current) |

**Grep strategy for each:**

- `@langchain/langgraph/prebuilt` → pattern `langgraph/prebuilt`, output mode `content`, glob `**/*.ts`
- `AgentExecutor` → pattern `AgentExecutor|initializeAgentExecutorWithOptions|createOpenAIFunctionsAgent`, output mode `content`
- Legacy chain imports → pattern `from ['"]langchain/(agents|chains)`, output mode `content`
- LCEL pipe-chains → pattern `\.pipe\(`, output mode `content`, context 3 lines; flag when the surrounding code is an agent-loop (model call + parser with retry); ignore single-step transforms
- `dist/` imports → pattern `@langchain[^'"]+dist/`, output mode `content`
- `config.configurable` → pattern `config\.configurable`, output mode `content`; read context to confirm app state is being carried (not just `thread_id`)
- `Annotation.Root` → pattern `Annotation\.Root`, output mode `content`

Count total BLOCKING deprecation hits and store the count — Phase 4 uses it to decide whether to offer migration mode.

### 2.2 Correctness pass (BLOCKING)

| Pattern | Why it's wrong |
|---|---|
| `Annotation<<X[]>>({...})` channel without a reducer | silent overwrite per node |
| `Annotation.Root({...})` for chat-shaped state without `MessagesAnnotation.spec` spread (or `StateSchema` without `MessagesValue`) | no append, no dedupe |
| `{ role: "user", content: "..." }` raw objects (vs `HumanMessage`/`AIMessage` constructors) | message ID dedup broken |
| `model.bindTools(tools)` then `createAgent({ llm: bound, tools })` | structured-output collision |
| `interrupt()` in a node where pre-interrupt code calls `fetch`/`db.x()`/`sendMail()` without idempotency guard | restart hazard |
| `new Send("name", state)` where the payload references parent state shape (vs target's input shape) | mismatch |
| `recursionLimit` passed as `createDeepAgent({...})` constructor option | wrong placement; pass in `.invoke()` config |

**Grep strategy for each:**

- Missing reducer → pattern `Annotation<`, output `content`; read each channel declaration and flag channels that are array/list/set typed but lack a `reducer:` field
- `MessagesAnnotation.spec` spread → pattern `MessagesAnnotation`, output `content`; flag files that reference `MessagesAnnotation` without also spreading `MessagesAnnotation.spec` into the state
- Raw message objects → pattern `\{ role: ["']`, output `content`; any raw role/content object that is not wrapped in `HumanMessage`/`AIMessage`/`SystemMessage`
- Pre-bound tools collision → pattern `bindTools`, output `content`; check if the return value is then passed as `llm:` into `createAgent`
- `interrupt()` with side effects → pattern `interrupt\(\)`, output `content`, context 10 lines; read 10 lines above for `fetch(`, `await db.`, `sendMail`, or similar external calls; flag if no idempotency guard is visible
- `Send` payload mismatch → pattern `new Send\(`, output `content`, context 3 lines; read the payload argument and flag if it mirrors the parent graph's full state shape instead of the target node's input shape
- `recursionLimit` in constructor → pattern `recursionLimit`, output `content`; flag occurrences inside `createDeepAgent\(\{`; the only correct placement is in the `.invoke({...})` or `.stream({...})` config

### 2.3 Production pass (WARNING)

| Pattern | Recommendation |
|---|---|
| `MemorySaver` outside `*.test.ts` / `dev.ts` | `Postgres`/`Sqlite`/`Redis` saver |
| Missing `LANGSMITH_TRACING` setup or `traceable()` on hot paths | wire LangSmith (per `/lg-cheatsheet` §12 guidance) |
| Serverless deploy target without `LANGCHAIN_CALLBACKS_BACKGROUND=false` | set the env var or traces will be lost |
| Deep Agents `.invoke()` without explicit `recursionLimit` | framework default 25 will trigger `GraphRecursionError`; pass 50+ |
| Subgraph in graph but `.stream()` / `.getState()` without `subgraphs: true` | child events invisible |
| Stateful agent with no checkpointer at all | no resume, no HITL, no replay |
| No `withFallbacks([backup])` on production model calls | single point of failure |
| Tools that hit external systems with no retry config | flaky |

**Grep strategy for each:**

- `MemorySaver` in prod → pattern `new MemorySaver`, output `content`; cross-reference with filename — flag matches that are NOT in `*.test.ts`, `*.spec.ts`, `dev.ts`, or `dev/**`
- LangSmith setup → pattern `LANGSMITH_TRACING`, output `content`, path `.`; also pattern `traceable`, output `content`; flag when both are absent from the entire codebase
- Background callbacks → pattern `LANGCHAIN_CALLBACKS_BACKGROUND`, output `content`, path `.`; if absent, check for serverless markers (`vercel.json`, `netlify.toml`, Lambda handler, Deno Deploy) and flag if serverless context is detected
- `recursionLimit` in `.invoke()` → pattern `\.invoke\(`, output `content`, context 5 lines; for any `.invoke(` on a Deep Agent graph, read the config object and flag if `recursionLimit` is absent
- `subgraphs: true` → pattern `subgraphs:`, output `content`; also pattern `addNode.*compiled` to find subgraph node registration; flag graphs that have subgraph child nodes but stream/getState calls without `subgraphs: true`
- Checkpointer → pattern `checkpointer:`, output `content`; also pattern `thread_id`; flag graphs that accept `thread_id` in invoke config but have no `checkpointer:` in `.compile(`
- `withFallbacks` → pattern `new Chat(OpenAI|Anthropic|Google)`, output `content`; check nearby context for `.withFallbacks(`; flag production model instantiations without it
- Tool retry → pattern `fetch\(|axios\.`, output `content`, glob `**/tools*.ts`; flag when no retry wrapper (`withRetry`, `pRetry`, `axios-retry`) appears in scope

### 2.4 Style pass (NIT)

| Pattern | Fix |
|---|---|
| `: any` in node return types | `typeof State.Update` |
| Tool descriptions < 1 sentence | LLM tool-pick quality suffers |
| Tool schemas not Zod | lose JSON-schema introspection |
| `as any` casts in graph construction | break type safety |

**Grep strategy:**

- `any` return types → pattern `\): any|=> any`, output `content`, glob `**/*.ts`; flag occurrences in node function signatures
- Short tool descriptions → pattern `description:`, output `content`, glob `**/tools*.ts`; read each value and flag if it is fewer than ~40 characters (clearly under one sentence)
- Non-Zod schemas → pattern `tool\(`, output `content`, context 5 lines; flag `tool()` calls where the schema argument is not a `z.object(` call
- `as any` → pattern ` as any`, output `content`, glob `**/graph*.ts`; flag occurrences in graph construction files

## Phase 3: Synthesize

After all four passes are complete, produce a single punch list grouped by severity. List BLOCKING items first (deprecation hits before correctness hits), then WARNING, then NIT. Within each severity group, order by file then line number.

Format exactly as shown:

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

If a severity category is entirely clean, print it as:

```
BLOCKING (must fix)
  none found
```

Print the full punch list in the conversation before doing anything else in Phase 3.

**Common fix patterns for the punch list arrow (`→`):**

- Deprecated import: `import { createAgent } from "langchain";`
- Missing reducer on array channel: `reducer: (a, b) => [...a, ...b], default: () => []`
- Missing reducer on message channel: spread `...MessagesAnnotation.spec` into `Annotation.Root({ ... })`
- Raw message object: wrap in `new HumanMessage(content)` or `new AIMessage(content)`
- Pre-bound tools collision: pass unbound `llm` to `createAgent`; let the framework bind tools internally
- `interrupt()` restart hazard: move the external call after the `interrupt()`, or wrap in an idempotency check (`if (!state.emailSent) { ... }`)
- `MemorySaver` in prod: `new PostgresSaver(pool)` or `new SqliteSaver(db)` behind a `NODE_ENV` check
- Missing `subgraphs: true`: `graph.stream(input, { ...config, subgraphs: true })`

**Save the punch list** to `docs/lg-reviews/$(date +%Y-%m-%d)-<slug>.md` where `<slug>` is the agent directory name, file basename, or a slug derived from the target path (e.g. `research-agent` from `src/agents/research/`).

To save:
1. Run `mkdir -p docs/lg-reviews` via Bash if the directory does not exist.
2. Write the file with the Write tool. Include: target path audited, date, and the full punch list.

## Phase 4: Migration mode detection

Count BLOCKING deprecation hits from Phase 2.1 only (not correctness hits). If the count is ≥3, offer the following prompt verbatim:

> "This looks like a v0→v1 migration. Run a full migration in one pass? [Y]es / [S]tep-by-step / [P]rint the plan only."

**If `Y`:** continue to Phase 5 with migration-pass-style fix mode. Apply fixes in this strict order:
1. All BLOCKING deprecations (§2.1 hits) — update imports, rename API calls, update call sites
2. All BLOCKING correctness fixes (§2.2 hits) — add reducers, fix constructors, guard interrupts
3. WARNINGs (§2.3 hits) — swap savers, wire env vars

Run `$HARNESS_TEST_CMD` after each group. If a group's tests fail, stop and surface the full error before continuing to the next group.

**If `S`:** walk through each fix one-at-a-time in the same order (deprecation → correctness → warning). Before each edit, show the user:
- The `[Bn]` or `[Wn]` label
- The file:line
- The current code snippet (1-3 lines)
- The proposed replacement

Then ask: "Apply this fix? (y/n/skip)". Respect every answer. "Skip" moves to the next item without applying.

**If `P`:** print an ordered migration plan listing all BLOCKING items in the recommended application order. For each item, explain in one sentence what the fix involves (e.g. "Change import on line 14, then update 3 call sites that use `createReactAgent`"). Then exit — skip Phase 5.

If BLOCKING deprecation count is <3, skip the migration offer entirely and proceed directly to Phase 5.

## Phase 5: Offer fixes

Ask via AskUserQuestion:

> "Want me to apply the BLOCKING fixes? (y/n/select)"

Response handling:

- **`y`** — switch to write-mode. Apply all BLOCKING fixes using the Edit tool. For each edit, print a one-line note: "Editing `<file>:<line>` — <what changed>." Never apply WARNINGs or NITs in this mode.
- **`n`** — leave all files untouched. Skip to Phase 6 immediately. Acknowledge: "Leaving all files as-is."
- **`select`** — list each BLOCKING item with its `[Bn]` label and a one-line description. Ask: "Which item numbers to apply? (e.g. 1 3 5 or 'all')". Apply only the selected items.

WARNINGs and NITs default to "leave for user" unless the user explicitly says "select-all" or names them by label. Do not offer to apply WARNINGs or NITs unless the user asks.

After applying fixes, run the test command:

```bash
source "$(git rev-parse --show-toplevel)/.claude/hooks/harness.config.sh"
$HARNESS_TEST_CMD
```

If `HARNESS_TEST_CMD` is unset or empty, skip and print: "No test command configured; run tests manually."

If tests fail after applying fixes, surface the full error output and offer to investigate the failure before declaring the audit complete.

## Phase 6: Final report

Print the full punch list again, showing which items are resolved and which remain open. Use `✓` for resolved, `•` for open:

```
BLOCKING
  ✓ [B1] src/agent.ts:14  createReactAgent → createAgent (applied)
  • [B2] src/state.ts:22  missing reducer (skipped by user)

WARNING
  • [W1] src/agent.ts:48  MemorySaver in prod (left for user)

NIT
  • [N1] src/tools.ts:10  short tool description (left for user)
```

If fixes were applied, print a summary line per severity:

```
BLOCKING: 2 → 1 (1 applied, 1 skipped). WARNING: 1 remains. NIT: 1 remains.
```

If no fixes were applied, print: "No fixes applied. All items left for user."

End with: "Punch list saved to `docs/lg-reviews/<date>-<slug>.md`."

---

## Appendix: Grep invocation reference

Quick reference for the Grep tool calls used in Phase 2. Use `output_mode: "content"` for all unless noted.

**2.1 Deprecation:**
```
pattern: "langgraph/prebuilt"         glob: "**/*.ts"
pattern: "AgentExecutor|initializeAgentExecutorWithOptions|createOpenAIFunctionsAgent"
pattern: 'from ["\']langchain/(agents|chains)'
pattern: "\\.pipe\\("                  context: 3
pattern: "@langchain[^'\"]+dist/"
pattern: "config\\.configurable"      context: 3
pattern: "Annotation\\.Root"
```

**2.2 Correctness:**
```
pattern: "Annotation<"                context: 5
pattern: "MessagesAnnotation"         context: 5
pattern: "\\{ role: [\"']"
pattern: "bindTools"                  context: 5
pattern: "interrupt\\(\\)"            context: 10
pattern: "new Send\\("               context: 5
pattern: "recursionLimit"             context: 5
```

**2.3 Production:**
```
pattern: "new MemorySaver"
pattern: "LANGSMITH_TRACING"
pattern: "LANGCHAIN_CALLBACKS_BACKGROUND"
pattern: "\\.invoke\\("              context: 5
pattern: "subgraphs:"
pattern: "checkpointer:"             context: 3
pattern: "new Chat(OpenAI|Anthropic|Google)" context: 3
pattern: "fetch\\(|axios\\."         glob: "**/tools*.ts"
```

**2.4 Style:**
```
pattern: "\\): any|=> any"           glob: "**/*.ts"
pattern: "description:"              glob: "**/tools*.ts"  context: 2
pattern: "tool\\("                   context: 5
pattern: " as any"                   glob: "**/graph*.ts"
```

---

## Tone

Senior engineer. Concise, evidence-based. Every finding includes the file and line number — no vague claims. Read-only by default — never touch a file without explicit user approval. Grep first, conclude from evidence; do not flag patterns not actually found in the code. If a category is clean, say so — a clean category is a positive signal, not a gap.
