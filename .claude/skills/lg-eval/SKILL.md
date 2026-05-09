---
name: lg-eval
description: Use when the user says "add evals", "write a regression test for my agent", "set up LangSmith evals", "check the agent's trajectory", or "I broke something — write the test first". Sets up evals for a LangGraph/LangChain agent in either local-only or LangSmith-backed mode (trajectory, final-answer, smoke/hallucination, custom rule-based and LLM-as-judge).
user-invocable: true
tier: flexible
kind: verification
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

# /lg-eval

Sets up an eval harness for an existing LangGraph/LangChain agent. Supports three modes: local-only (Vitest/Jest assertions, no LangSmith account required), LangSmith-backed (full experiment tracking with datasets and dashboard), and hybrid (both — local fixtures committed to git, remote upload available). Generates dataset fixtures, pure-function evaluators (trajectory, correctness, smoke), and wires the `eval` script into `package.json`.

## Phase 0: Load shared context

Invoke the `/lg-cheatsheet` skill via the `Skill` tool. Cross-reference §13 (Evals) for LangSmith `evaluate()` API shape, `Run`/`Example` types, and `LLMEvaluator` usage in LangSmith-backed mode.

## Phase 1: Detect target

Accept `/lg-eval <agent-path>` directly, or glob `src/agents/**` and ask the user to pick. Once the target is known:

- Read the agent file to understand the state shape (what's in `StateSchema` / `MessagesAnnotation`), tool list (names matter for trajectory checks), and pattern (`createAgent` / raw `StateGraph` / Deep Agent).
- Derive `<slug>` from the agent directory name (e.g. `src/agents/researcher` → `researcher`).
- If the agent cannot be found or read, stop and ask the user for the correct path before continuing.

## Phase 2: Pick eval mode

**Single-select via AskUserQuestion. This is the load-bearing decision — make the tradeoffs explicit so the user picks confidently.**

Present these three options with their implications:

- **Local-only** — Vitest/Jest assertions on agent output. No LangSmith account, no upload, no API key. Evaluators are pure functions called inside the test runner. Best for: prototyping, CI without external dependencies, simple agents with deterministic-ish output, teams that want zero third-party coupling.
- **LangSmith-backed** — Full experiment tracking: datasets live in the LangSmith dashboard, every eval run is a named experiment, regressions are dataset-bound, online evals can run against prod traces. Requires `LANGSMITH_API_KEY`. Best for: multi-step agents, Deep Agents, anything you'll iterate on for weeks, teams that need a shared dashboard view.
- **Hybrid** — Local fixtures committed to git so evaluators run in CI without secrets. `$HARNESS_PKG_MGR run eval` runs locally; `$HARNESS_PKG_MGR run eval:remote` uploads to LangSmith. Best for: shipping projects that need both PR-time signal and a dashboard view.

Record the chosen mode — every subsequent phase branches on it.

## Phase 3: Detect prerequisites

**All modes:**

- Check `package.json` devDependencies for `vitest` or `jest`. If neither is present, default to `vitest` and emit:
  ```
  $HARNESS_PKG_MGR install -D vitest
  ```
- If mode is **LangSmith-backed** or **hybrid**, also check for `langsmith` (the `evaluate()` helper lives there). If missing:
  ```
  $HARNESS_PKG_MGR install langsmith
  ```

**LangSmith-backed and hybrid only:**

- Check for `LANGSMITH_API_KEY` in `.env`, `.env.local`, and process env (in that order).
- If missing, prompt the user: "LangSmith mode requires `LANGSMITH_API_KEY`. Add it to `.env` now? (y / downgrade to local-only)"
  - If the user adds it: continue in the requested mode.
  - If the user declines: **downgrade to local-only mode** and print a one-line note: "Downgraded to local-only mode — no API key provided."
- Never write the API key yourself. Only the user writes secrets.

**Local-only:** No API key check. No install beyond the test runner. Continue immediately.

## Phase 4: Eval check picker

**Multi-select via AskUserQuestion.** Present each option with a one-line description:

- **Final-answer correctness** — LLM-as-judge or exact match on the last `AIMessage` in `run.outputs.messages`.
- **Trajectory check** — Verify tool-call ordering or tool absence. Parses `tool_calls` from the message list. Use when "the right tools must be called in the right order."
- **Regression suite** — Dataset-bound evaluators auto-run on every experiment. Catches regressions when you change the agent's prompt or graph topology.
- **Online eval** — Evaluators run against live prod traces in LangSmith. **Only show this option in LangSmith-backed or hybrid modes.** Do not present it in local-only mode.
- **Smoke / hallucination check** — Asserts the final message is non-empty and the run did not hit `recursionLimit`. Fast, zero-cost, always worth including.

Record all selected checks — Phase 6 generates one evaluator file per check.

## Phase 5: Dataset scaffolding

Branch on mode:

**Local-only** — Generate `evals/datasets/<slug>.ts` with a TS array of `{ input, reference }` objects. Pre-populate with 3 example rows derived from the agent's purpose (read from Phase 1):

```ts
// evals/datasets/<slug>.ts
export const dataset = [
  {
    input: { messages: [{ role: "user", content: "..." }] },
    reference: "expected output describing success criterion",
  },
  {
    input: { messages: [{ role: "user", content: "..." }] },
    reference: "expected output describing success criterion",
  },
  {
    input: { messages: [{ role: "user", content: "..." }] },
    reference: "expected output describing success criterion",
  },
];
```

Use the agent's actual purpose to write non-trivial rows. Placeholder rows fail as documentation — make them realistic.

**LangSmith-backed** — Generate `evals/upload-<slug>.ts` — a one-shot script that creates the dataset and uploads examples using the LangSmith client. Inline fixtures are NOT generated; the dataset lives in the dashboard.

```ts
// evals/upload-<slug>.ts
import { Client } from "langsmith";

const client = new Client();

const dataset = await client.createDataset("<slug>-evals", {
  description: "Golden dataset for <slug> agent.",
});

await client.createExamples({
  inputs: [
    { messages: [{ role: "user", content: "..." }] },
    // add more rows
  ],
  outputs: [
    { answer: "expected output" },
    // aligned with inputs
  ],
  datasetId: dataset.id,
});

console.log("Dataset created:", dataset.url);
```

**Hybrid** — Generate inline fixtures (same format as local-only, written to `evals/datasets/<slug>.ts`) plus a sync script `evals/sync-<slug>.ts` that uploads those fixtures to LangSmith. Add an `eval:sync` script to `package.json`.

## Phase 6: Evaluator scaffolding

Generate one file per selected check in `evals/evaluators/`. Evaluators are **pure functions** — they work in all three modes. In LangSmith-backed mode, `Run` and `Example` are typed from `langsmith`; in local-only mode, pass minimal compatible objects from the test harness.

**Trajectory check:**

```ts
// evals/evaluators/trajectory.ts
import type { Run, Example } from "langsmith";

export function calledRetrieverFirst(
  run: Run,
  example: Example
): { score: number; comment: string } {
  const messages = run.outputs?.messages ?? [];
  const toolCalls = messages.flatMap((m: any) => m.tool_calls ?? []);
  const firstTool = toolCalls[0]?.name;
  return {
    score: firstTool === "retrieve" ? 1 : 0,
    comment:
      firstTool === "retrieve"
        ? "✓ retriever called first"
        : `expected retriever, got ${firstTool ?? "nothing"}`,
  };
}
```

Adapt the tool name check (`"retrieve"` above) to the actual tool names discovered in Phase 1.

**Final-answer correctness — LLM-as-judge:**

```ts
// evals/evaluators/answer-quality.ts
import type { Run, Example } from "langsmith";
import { ChatOpenAI } from "@langchain/openai";

const judgePrompt = `Score 0-1 whether the agent's response addresses the user's question. Respond with JSON: { "score": <0-1>, "comment": "<reason>" }.`;

export async function answerQualityJudge(
  run: Run,
  example: Example
): Promise<{ score: number; comment: string }> {
  const judge = new ChatOpenAI({ model: "gpt-4o" });
  const reply = await judge.invoke([
    { role: "system", content: judgePrompt },
    {
      role: "user",
      content: `Question: ${example.inputs.messages[0].content}\nResponse: ${run.outputs?.messages?.at(-1)?.content}`,
    },
  ]);
  return JSON.parse(reply.content as string);
}
```

In LangSmith-backed mode, optionally wrap with `LLMEvaluator` from `langsmith/evaluation` for dashboard-native display. In local-only mode, call the model directly as shown.

**Smoke / hallucination check:**

```ts
// evals/evaluators/smoke.ts
import type { Run, Example } from "langsmith";

export function smokeCheck(
  run: Run,
  _example: Example
): { score: number; comment: string } {
  const last = run.outputs?.messages?.at(-1);
  if (!last || !last.content) {
    return { score: 0, comment: "final AIMessage is empty or missing" };
  }
  if (run.error?.includes("GraphRecursionError")) {
    return { score: 0, comment: "run hit recursionLimit" };
  }
  return { score: 1, comment: "non-empty response, no recursion error" };
}
```

**Structured-output check (if the agent has a structured final answer):**

```ts
// evals/evaluators/structured-output.ts
import type { Run, Example } from "langsmith";
import { z } from "zod";

const schema = z.object({
  // Mirror the agent's actual output schema here
  answer: z.string(),
});

export function structuredOutputValid(
  run: Run,
  _example: Example
): { score: number; comment: string } {
  try {
    schema.parse(run.outputs?.finalAnswer);
    return { score: 1, comment: "valid schema" };
  } catch (e: any) {
    return { score: 0, comment: e.message };
  }
}
```

Only generate the structured-output evaluator if the agent's state shape (from Phase 1) includes a non-message structured output field.

## Phase 7: Test harness

Branch on mode:

**Local-only** — Generate `evals/<slug>.eval.test.ts` using plain Vitest/Jest:

```ts
// evals/<slug>.eval.test.ts
import { describe, it, expect } from "vitest";
import { agent } from "../src/agents/<slug>/graph";
import { dataset } from "./datasets/<slug>";
import { calledRetrieverFirst } from "./evaluators/trajectory";
import { smokeCheck } from "./evaluators/smoke";
// import { answerQualityJudge } from "./evaluators/answer-quality"; // async; add if selected

describe("<slug> evals", () => {
  for (const example of dataset) {
    it(`smoke: ${JSON.stringify(example.input).slice(0, 60)}...`, async () => {
      const result = await agent.invoke(example.input, {
        configurable: { thread_id: "eval-" + Math.random() },
      });
      const run = { outputs: result };
      const { score, comment } = smokeCheck(run, { inputs: example.input } as any);
      expect(score, comment).toBe(1);
    });

    it(`trajectory: ${JSON.stringify(example.input).slice(0, 60)}...`, async () => {
      const result = await agent.invoke(example.input, {
        configurable: { thread_id: "eval-" + Math.random() },
      });
      const run = { outputs: result };
      const { score, comment } = calledRetrieverFirst(run, { inputs: example.input } as any);
      expect(score, comment).toBe(1);
    });
  }
});
```

Omit evaluators not selected in Phase 4. Use `jest` import if Jest was detected in Phase 3.

**LangSmith-backed or hybrid** — Generate `evals/<slug>.eval.ts` calling `evaluate()`:

```ts
// evals/<slug>.eval.ts
import { evaluate } from "langsmith/evaluation";
import { agent } from "../src/agents/<slug>/graph";
import { calledRetrieverFirst } from "./evaluators/trajectory";
import { answerQualityJudge } from "./evaluators/answer-quality";
import { smokeCheck } from "./evaluators/smoke";

const results = await evaluate(
  async (input) =>
    agent.invoke(input, {
      configurable: { thread_id: "eval-" + Math.random() },
    }),
  {
    data: "<slug>-evals", // LangSmith dataset name — created via upload-<slug>.ts
    evaluators: [calledRetrieverFirst, answerQualityJudge, smokeCheck],
    experimentPrefix: "<slug>",
    maxConcurrency: 4,
  }
);

console.log("Experiment URL:", results.experimentUrl);
```

**Hybrid** generates **both** files.

## Phase 8: Wire to CI

Add an `eval` script to `package.json` **separate from the existing `test` script**:

```json
{
  "scripts": {
    "eval": "vitest run evals/"
  }
}
```

For hybrid mode, also add:

```json
{
  "scripts": {
    "eval": "vitest run evals/",
    "eval:sync": "tsx evals/sync-<slug>.ts",
    "eval:remote": "tsx evals/<slug>.eval.ts"
  }
}
```

Use `$HARNESS_PKG_MGR run eval` for all invocations (package manager read from `harness.config.sh`).

**GitHub Action (optional — ask the user):**

If the user wants CI integration, generate `.github/workflows/eval.yml` triggered on PRs tagged `eval`:

```yaml
name: Agent Evals
on:
  pull_request:
    types: [labeled]
jobs:
  eval:
    if: github.event.label.name == 'eval'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: $HARNESS_PKG_MGR install
      - run: $HARNESS_PKG_MGR run eval
        # No LANGSMITH_API_KEY needed for local-only mode
        # For LangSmith-backed/hybrid, add: env: { LANGSMITH_API_KEY: ${{ secrets.LANGSMITH_API_KEY }} }
```

For local-only mode, the Action runs cleanly without any secrets in the repo.

## Phase 9: First run

Execute `$HARNESS_PKG_MGR run eval`:

**Local-only:** Assertions pass/fail through the test runner output. Print the pass/fail summary. If any evaluator fails, surface the failing `comment` strings so the user knows which checks are broken before touching any code.

**LangSmith-backed or hybrid:** Surface the LangSmith experiment URL from the `evaluate()` return value. If `LANGSMITH_API_KEY` is missing at this point (user skipped adding it earlier, env is stale, etc.), stop and prompt instead of silently failing:

> "LANGSMITH_API_KEY is not set. Add it to `.env` and re-run `$HARNESS_PKG_MGR run eval`, or switch to local-only mode."

Do not call `evaluate()` with an empty API key — it will fail with a confusing network error.

## Phase 10: Print follow-up

Print a summary in this exact shape:

> "Mode: `<local-only | langsmith | hybrid>`. Dataset at `evals/datasets/<slug>.ts` [or dashboard], evaluators at `evals/evaluators/`, test harness at `evals/<slug>.eval.test.ts` [and/or `evals/<slug>.eval.ts`][, experiment URL: `<url>` if LangSmith]. To add an evaluator: re-run `/lg-eval add-evaluator`."

---

## Tone and approach

Senior engineer. The mode picker (Phase 2) is the load-bearing UX moment — the tradeoffs between local-only, LangSmith-backed, and hybrid are real and worth spelling out clearly so the user picks confidently rather than defaulting to the most complex option. Evaluators are pure functions in all modes; this is intentional and worth noting because it means local evaluators graduate to LangSmith without rewrite. Do not over-explain boilerplate — add comments only where the API is non-obvious (e.g., why `Run` is typed from `langsmith` even in local-only mode, why `thread_id` is randomized per eval row).
