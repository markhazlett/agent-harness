# /skill-eval — Open follow-ups

Status reference for Phase 4 items. **§E (Judge-LLM fuzzy matching) was implemented in Phase 4**; see `assertion-rules.md` § "Phase 4 — judge-LLM fuzzy matching (enforced)" and the kept-design-record below. **§F (Headless CI adapter) is deferred** pending Claude Code SDK headless mode; design questions retained for the re-check trigger.

## E. Judge-LLM fuzzy matching — IMPLEMENTED (Phase 4)

**Status:** Shipped. See `judge-prompt.md` (template), `assertion-rules.md` § Phase 4 (rules), `anti-evals/judge-rubberstamp-canary.md` (regression test), `SKILL.md` step 7a (when it fires).

**Decisions taken (kept for future readers and re-design):**

| Question | Decision |
|---|---|
| Q1. When does the judge fire? | Only-on-strict-fail, specifically on "missing expected step" failures. Other assertion types (forbidden_actions, decision_evals, must_cite, must_recognize, output_evals, expect_exit) are NOT routed through the judge. |
| Q2. What does the judge see? | One expected step + the full captured trajectory (indexed). Plus the skill's one-sentence Iron Law summary. The judge does NOT see must_cite/must_recognize/forbidden/decisions/output_evals — those are graded separately. |
| Q3. Verdict format? | Three-way: `equivalent \| not_equivalent \| ambiguous`. `equivalent` requires a non-null `matched_captured_index`. The orchestrator collapses to PASS-with-judge-note / FAIL / FAIL-with-warning. |
| Q4. Cost cap? | 5 judge dispatches per eval run (configurable via `SKILL_EVAL_JUDGE_CAP`). Verdicts cached at `/tmp/skill-eval-judge-cache.json`. `SKILL_EVAL_JUDGE=off` disables. |
| Q5. Where does the judge live? | `Agent` dispatch with `subagent_type: general-purpose`. Tight prompt template in `judge-prompt.md` sibling. Stays inside Claude Code, no new auth. |
| Q6. Negative-test discipline? | `anti-evals/judge-rubberstamp-canary.md` — a clearly-wrong TDD-scenario trajectory the judge MUST mark `not_equivalent`. Run before any PR touching `judge-prompt.md` ships. |

## F. Headless CI adapter — DEFERRED (blocked on Claude Code SDK headless mode)

**Problem.** `/skill-eval` requires Claude Code as the execution layer — that's the fidelity win. But CI runs without Claude Code. Today, eval coverage in CI stops at `bin/skill-eval --validate` (schema only). To run the actual scenarios in CI we need a second adapter.

**Re-check trigger.** Reopen this section when EITHER:

1. Claude Code ships an SDK with headless dispatch (`subagent_type` parity + tool palette parity + system prompt parity), OR
2. The harness has accumulated enough eval surface that the cost of NOT having CI coverage outweighs the fidelity loss of a Python mock.

**Sketch (kept for the re-design conversation).** A Python (or shell) runner that drives the Anthropic Messages API directly with mock tools, returning the same `<trajectory-report>` shape so the orchestrator's assertion engine can grade it. Earlier sketch (`bin/skill-eval-run`, deleted in Phase 2) approximated this.

**Design questions (answer before implementation when the re-check triggers fire).**

1. **Is this the resurrected Python runner or a different shape?**
   - Resurrected runner: known territory, known fidelity gap (mock tool descriptions diverge from real Claude Code's system prompt).
   - Different shape: run inside Claude Code SDK in headless mode (`claude-code --headless --skill skill-eval`)? Depends on Claude Code shipping a headless mode.
   - Recommendation: wait for Claude Code SDK headless mode rather than rebuild a Python mock. The "fidelity loss → tests catching wrong drift" argument from `skill-eval-spec.md` § "Why Claude Code, not headless" still applies.

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

When picking up F, open a GitHub issue referencing this file, then update this section with the issue link. Do not silently start work — F will absorb a meaningful chunk of a sprint.
