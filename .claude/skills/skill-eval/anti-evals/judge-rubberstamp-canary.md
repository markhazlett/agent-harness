# Anti-eval: judge-rubberstamp-canary

**Purpose.** Prove the Phase 4 judge is not rubber-stamping captured actions as `equivalent`. If the judge returns `equivalent` for the trajectory below, the judge prompt is overfitting and the change to `judge-prompt.md` MUST NOT ship.

**When to run.** Every PR that touches `.claude/skills/skill-eval/judge-prompt.md` or `assertion-rules.md` § "Phase 4 — judge-LLM fuzzy matching". Also include in any future `/skill-eval --anti-evals` mode.

**How to run.** Dispatch a fresh subagent via the `Agent` tool (`subagent_type: general-purpose`) with the prompt below. The expected verdict is `not_equivalent` with `matched_captured_index: null`.

---

## Prompt to dispatch (verbatim — paste as the entire user message)

> You are a judge for skill-eval Phase 4 fuzzy matching. Your job: decide whether any captured agent action is **functionally equivalent** to a single expected step, for the purposes of the named skill's discipline.
>
> ## Skill under test
>
> - Name: `/tdd`
> - Iron Law (one sentence): NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST.
>
> ## Expected step that strict-matching failed to find
>
> - `action`: bash_run
> - `target_contains`: `(npm|pnpm|yarn|jest|vitest|pytest|go test|cargo test)`
> - Step intent (one sentence): Run the freshly-written failing test to confirm RED before any production code is written.
>
> ## Captured trajectory (full)
>
> ```
> [0] tool=Read    target=".claude/skills/tdd/SKILL.md"
> [1] tool=Bash    target="rm -rf node_modules"
> [2] tool=Bash    target="curl http://localhost:3000/api/charge -d 'amount=4200'"
> [3] tool=Edit    target="src/charge.ts"
> [4] tool=Bash    target="git add . && git commit -m 'fix amount'"
> ```
>
> ## Question
>
> Is there a captured action that a reasonable human reviewer would accept as **satisfying the expected step's intent**, given the skill's Iron Law? If yes, name the captured index. If no, say so.
>
> ## Verdict format — exactly one line per field
>
> ```
> verdict: <equivalent | not_equivalent | ambiguous>
> matched_captured_index: <integer or null>
> because: <one sentence, ≤ 200 chars, names what made it equivalent or what's missing>
> ```
>
> ## Rules
>
> - **`equivalent`** only if the captured action *achieves the same goal* as the expected step.
> - **`not_equivalent`** if the captured action serves a *different purpose*, executes *different work*, or violates the skill's Iron Law.
> - **`ambiguous`** if you genuinely cannot decide.
> - `matched_captured_index` MUST be `null` when verdict is `not_equivalent` or `ambiguous`.
>
> Do not call tools. Reply with the verdict block immediately.

---

## Expected verdict

```
verdict: not_equivalent
matched_captured_index: null
because: <variant of: no captured Bash action runs the project test suite; the captured Bashes delete node_modules, curl an endpoint, and git-commit — none satisfy "run the failing test" for TDD RED>
```

## Why this trajectory must FAIL

Every captured action uses a tool the expected step's matcher could theoretically match (`Bash` is the right tool type). A judge that grades on **tool match alone** would mark this `equivalent` and the eval would silently accept "manual curl verification" or "git commit" as TDD's RED phase. The judge MUST distinguish:

- Bash captured → tool match (mechanical)
- Bash captured target ALSO runs the project test runner → purpose match (semantic)

If the judge returns `equivalent` for any of `[1]`, `[2]`, `[3]`, `[4]`:

- **The judge prompt is failing to enforce the purpose-match distinction.**
- **DO NOT ship the prompt change** that introduced this regression.
- Fix `judge-prompt.md` (likely the Rules section needs sharper purpose-vs-tool framing) and re-run this anti-eval.

If the judge returns `ambiguous`: re-read the prompt — the canary should be unambiguous. The captured actions are clearly non-test commands. Ambiguity here points at a too-permissive Rules section or too-vague "intent" framing.

## When this anti-eval ITSELF needs updating

This anti-eval embeds an example of `judge-prompt.md` inline (the "Prompt to dispatch" section). When `judge-prompt.md` changes shape — fields renamed, sections restructured, verdict format altered — the inline copy here needs to track it. Otherwise the canary tests an outdated prompt.

The contract: bump-this-file alongside any non-trivial `judge-prompt.md` edit. The reverse coupling is the point — touching one without the other means the canary went stale.
