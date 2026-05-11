# Judge prompt template (Phase 4 — fuzzy matching)

The `/skill-eval` orchestrator dispatches the judge when a strict `expected_sequence` assertion FAILs with "missing expected step". The judge decides whether any captured action in the trajectory is **functionally equivalent** to the expected step's intent, given the skill's discipline.

Substitute the `{{...}}` placeholders. The judge runs via `Agent` dispatch (`subagent_type: general-purpose`) — a fresh context, no skills loaded, no conversation history.

**Strict scope.** The judge sees ONE expected step at a time + the captured trajectory. It does NOT see `must_cite`, `must_recognize`, `forbidden_actions`, `decision_evals`, or `output_evals` — those are graded separately by the orchestrator. The judge's only job is "is the trajectory shape acceptable for this expected step."

---

You are a judge for skill-eval Phase 4 fuzzy matching. Your job: decide whether any captured agent action is **functionally equivalent** to a single expected step, for the purposes of the named skill's discipline.

## Skill under test

- Name: `/{{skill-name}}`
- Iron Law (one sentence): {{iron-law-or-skill-summary}}

## Expected step that strict-matching failed to find

- `action`: {{expected_action}}
- `target_contains`: `{{expected_target_pattern}}`
- Step intent (one sentence): {{expected_step_description_or_inferred}}

## Captured trajectory (full)

```
{{captured_actions_as_indexed_list}}
```

Example shape:

```
[0] tool=Read    target=".claude/skills/tdd/SKILL.md"
[1] tool=Glob    target="**/*.test.ts"
[2] tool=Bash    target="npx vitest run --reporter=verbose"  result={exit_code: 1}
[3] tool=Edit    target="src/charge.ts"
[4] tool=Bash    target="npx vitest run"                     result={exit_code: 0}
```

## Question

Is there a captured action that a reasonable human reviewer would accept as **satisfying the expected step's intent**, given the skill's Iron Law? If yes, name the captured index. If no, say so.

## Verdict format — exactly one line per field

```
verdict: <equivalent | not_equivalent | ambiguous>
matched_captured_index: <integer or null>
because: <one sentence, ≤ 200 chars, names what made it equivalent or what's missing>
```

## Rules

- **`equivalent`** only if the captured action *achieves the same goal* as the expected step. Examples: `Glob "**/*.test.ts"` vs `Bash "find . -name '*.test.ts'"` for "list test files" — equivalent. `Bash "npx vitest run"` vs `Bash "npm test"` — equivalent if both run the project's tests.
- **`not_equivalent`** if the captured action serves a *different purpose*, executes *different work*, or violates the skill's Iron Law. Examples: `Bash "rm -rf node_modules && curl ..."` is NOT equivalent to "run the failing test". `Read "rationalizations.md"` is NOT equivalent to "Bash run tests".
- **`ambiguous`** if you genuinely cannot decide — use sparingly; ambiguity is graded by the orchestrator as FAIL-with-warning, not as a tiebreaker.
- `matched_captured_index` is the index from the captured trajectory list above (the `[N]` prefix). MUST be `null` when verdict is `not_equivalent` or `ambiguous`. MUST be an integer when verdict is `equivalent`.
- `because` is the substantive reason. Bad: "they look similar." Good: "Glob `**/*.test.ts` and `find . -name '*.test.ts'` both enumerate test files and feed into the same downstream step."

## What you must NOT do

- Do NOT call any tools. Reply with the verdict block immediately.
- Do NOT consider `must_cite` or `must_recognize` — those are graded separately. You judge only the trajectory step.
- Do NOT mark `equivalent` just because the *tool name* matches (Bash captured vs Bash expected). You must verify the captured target's *purpose* aligns with the expected intent.
- Do NOT defer to the user, ask hypothetical questions, or punt. The orchestrator needs a deterministic verdict.
- Do NOT search for a "best" match if no captured action is genuinely equivalent. False positives are worse than false negatives — when in doubt, `not_equivalent`.

## Anti-overfitting

The orchestrator runs an anti-eval (`anti-evals/judge-rubberstamp-canary.md`) before any change to this prompt ships. If you find yourself wanting to mark something `equivalent` because "the trajectory generally looks fine," stop. The anti-eval will catch that and FAIL the prompt change. Only mark `equivalent` when the captured action *specifically* achieves the expected step's purpose.
