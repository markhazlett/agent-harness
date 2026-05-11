# /skill-eval — Open follow-ups (Phase 4 candidates)

This file enumerates work intentionally deferred from Phase 3 because each item needs an in-the-loop design conversation before implementation. The Phase 3 PR ships the four mechanically-clean items (forbidden_actions, decision_evals, output_evals, expect_exit/result); the two listed below carry architectural decisions and must not be implemented autonomously.

When picking these up, start by answering the design questions inline in this file, then draft a spec section in `.claude/docs/skill-eval-spec.md` before writing code or skill body.

## E. Judge-LLM fuzzy matching

**Problem.** Strict diffing against `expected_sequence` is brittle. A subagent may use `Glob` where the eval expected `Bash ls`; functionally identical, mechanically distinct. The current Phase 3 matcher fails such cases as missing-expected-step, producing false negatives that erode trust in the eval suite.

**Sketch.** When the strict matcher fails, optionally route the failing step + captured trajectory through a judge LLM that returns `equivalent | not_equivalent | ambiguous`. The orchestrator treats `equivalent` as PASS-with-note, `not_equivalent` as the original FAIL, `ambiguous` as FAIL-with-judge-warning.

**Design questions to answer before implementation.**

1. **When does the judge fire?**
   - Only after strict diff fails (cheap-fast-strict, expensive-slow-judge)?
   - Always, as a secondary signal even on strict-PASS (catch false positives)?
   - Configurable per-eval via a new `fuzzy_match: true | false` field on `expected_sequence` steps?
   - Recommendation to debate: only-on-strict-fail. Anything else multiplies token cost without proportional signal.

2. **What does the judge see?**
   - Just the failing assertion (single expected step + the candidate captured action)?
   - Full captured trajectory + the failing assertion + the skill body?
   - The eval.yaml plus the trajectory-report?
   - Trade-off: more context → better judgment, but more tokens and more places to drift.

3. **What is the judge's verdict format?**
   - Strict `equivalent | not_equivalent` boolean?
   - Three-way `equivalent | not_equivalent | ambiguous`?
   - Numeric score with a threshold?
   - The orchestrator needs a deterministic decision, so the format must collapse to PASS/FAIL with a tie-breaker rule.

4. **How do we cap cost and latency?**
   - Max judge calls per eval run (e.g., 3)?
   - Cache judge verdicts keyed by `(skill_hash, eval_id, step_index, captured_action_target)` so repeated runs don't re-bill?
   - A "judge mode" flag that disables judges in CI / `--quick` mode?

5. **Where does the judge live?**
   - Another Agent dispatch from `/skill-eval` (cheap, uses Claude Code already)?
   - Direct Anthropic API call from a bin/ script (needs API key, breaks the "no key needed" property)?
   - A separate `/skill-judge` skill (over-engineered for a sub-feature)?
   - Recommendation to debate: Agent dispatch with `subagent_type: general-purpose`, a tight prompt template in `judge-prompt.md` sibling. Stays inside Claude Code, no new auth, but capped at N calls per run.

6. **What's the negative-test discipline?**
   - How do we prevent the judge from "fuzzy-matching" everything to equivalent (the eval suite becomes meaningless)?
   - A red-team eval where a clearly-wrong trajectory must still FAIL?
   - Recommendation: ship E with at least one judge-anti-eval (a captured trajectory of "delete the database" must be judged `not_equivalent` to "run the test suite").

**Not yet implemented.** Do NOT add `fuzzy_match`, `judge_*`, or any judge plumbing to eval.yaml or assertion-rules.md until the questions above are resolved with the user.

## F. Headless CI adapter

**Problem.** `/skill-eval` requires Claude Code as the execution layer — that's the fidelity win. But CI runs without Claude Code. Today, eval coverage in CI stops at `bin/skill-eval --validate` (schema only). To run the actual scenarios in CI we need a second adapter.

**Sketch.** A Python (or shell) runner that drives the Anthropic Messages API directly with mock tools, returning the same `<trajectory-report>` shape so the orchestrator's assertion engine can grade it. Earlier sketch (`bin/skill-eval-run`, deleted in Phase 2) approximated this.

**Design questions.**

1. **Is this the resurrected Python runner or a different shape?**
   - Resurrected runner: known territory, known fidelity gap (mock tool descriptions diverge from real Claude Code's system prompt).
   - Different shape: run inside Claude Code SDK in headless mode (`claude-code --headless --skill skill-eval`)? Depends on Claude Code shipping a headless mode.
   - Recommendation to debate: wait for Claude Code SDK headless mode rather than rebuild a Python mock. The "fidelity loss → tests catching wrong drift" argument from `skill-eval-spec.md` § "Why Claude Code, not headless" still applies.

2. **How does it stay fidelity-aligned with Claude Code as Claude Code evolves?**
   - Pin a snapshot of Claude Code's system prompt + tool descriptions in the runner?
   - Auto-sync from a known location on every CI run?
   - Drift-detection: a smoke eval that fails when the snapshot is stale?
   - Recommendation: drift-detection eval is non-negotiable. Without it, the runner silently degrades.

3. **What signals does it use to detect drift?**
   - Compare a known-good captured trajectory hash against the new run — if they diverge, FAIL the CI smoke test, not the individual eval.
   - Compare the SDK version pin against the latest published version on every CI run.
   - Track per-eval flake rate over time; a sudden flake-rate spike means drift.

4. **What's the scope cut for v1?**
   - Trajectory evals only? Decision and output evals are filesystem-coupled and harder in mock.
   - One canary skill end-to-end before extending?
   - Recommendation: scope v1 to one rigid skill (e.g., `/tdd`), one trajectory eval, full pipeline. Prove the fidelity is acceptable on a real-world case before extending.

5. **Where does the adapter live?**
   - `bin/skill-eval-headless`? (consistent with `bin/skill-eval`)
   - `bin/skill-eval --headless` flag?
   - Separate repo (`agent-harness-ci`)?
   - Recommendation: `bin/skill-eval-headless` separate executable. Keeps the canonical `bin/skill-eval` Claude-Code-bound and short; the adapter can have its own dependencies (`anthropic` Python SDK, etc).

**Not yet implemented.** Do NOT recreate `bin/skill-eval-run` or any headless executor until at least Q1 + Q2 are answered with the user. The Phase 2 deletion of the Python runner was deliberate; resurrecting it requires the same level of intentionality.

## Tracking

When picking up E or F, open a GitHub issue referencing this file, then update this section with the issue link. Do not silently start work — both items will absorb a meaningful chunk of a sprint each.
