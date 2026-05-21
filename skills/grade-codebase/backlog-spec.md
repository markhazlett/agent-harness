# Backlog generation — `/grade-codebase` step 8 (full mode only)

Same persuasion shape as the narrative, applied to each fix-task.

## Per-item shape

- **Title** — verb-first ("Add `make test` aggregator target", not "Test command improvement"). Use the *discovered* task runner / forge in the title, not a hardcoded default.
- **Why this, why now** — 1–2 sentences. Pull from the rubric's §7 "Why it's still worth doing" column, grounded in this repo's evidence (file paths, runtimes, grep counts).
- **Common objection it answers** — pull from the rubric §7 objection column. State it verbatim so the user recognises themselves saying it.
- **Effort** — S (under a day) / M (under a week) / L (multi-week). Estimate against the team that will do the work, not against the agent — humans review and ship even if an agent does the keystrokes.
- **Agent handoff line** — one sentence the user can paste to an agent. Reference the report file, not the rubric: "Read `docs/agent-grade/latest.md` §D2, then implement: add a top-level `make test` target that runs `pnpm test`, `cargo test --workspace`, and `pytest services/*/tests/`."

## Ordering

Order by leverage:

```
leverage = dimension_weight × gap_from_A × (1 / effort_weight)
```

Effort weights: S=1, M=3, L=8. Surface the top 3 as **highest-leverage** at the top of the backlog section.

A single L-effort item that closes a 30-point gap on a 15%-weight dimension will outrank ten S-effort items that close 5-point gaps on 4%-weight dimensions — that's the right call. Don't soften the ordering to make the backlog feel more balanced.

## Tool-agnostic phrasing

Backlog items must reference the *discovered* toolchain (from `discovery.md` preamble), not the rubric's example tools. Bad: "Add a `package.json` `test` script." Good: "Add a top-level test command — `make test` is the most consistent with the existing `Makefile` in this repo." If the discovery preamble says "no task runner", the item names what to add ("introduce a `justfile` or `Makefile` at the repo root").

## What good looks like (one item)

> **2. Add cold-cache CI test-result caching — D2 — M effort**
>
> *Why now.* Cold-cache `cargo test` runs in 2m 12s vs 38s warm. Every agent PR triggers a cold-cache CI run; at the current PR rate (~12 agent PRs/week) that's 22 minutes/week of avoidable CI wall-clock plus ~$2/week in agent tokens spent on context shuffling during the wait.
>
> *Objection it answers.* "Cold-cache is rare in dev — only CI sees it." True; this fix is CI-only. Use `Swatinem/rust-cache` (the existing CI is GitHub Actions per the discovery preamble) keyed on `Cargo.lock` + `rust-toolchain.toml`.
>
> *Agent handoff.* Read `docs/agent-grade/latest.md` §D2 and the existing `.github/workflows/ci.yml`. Add `Swatinem/rust-cache@v2` before the test step. Don't touch the lint job in the same PR.

## Honesty rules carried over

- Don't invent backlog items to defend a grade. If a dimension scored a B and you can't think of a leverage-positive fix, say "no actionable items at this dimension's current grade" — that's honest.
- Don't recommend tools the repo isn't using. If the discovery preamble says "Pants", don't recommend a Nx migration unless the rubric specifically flagged the task-runner choice as the root cause.
- The agent handoff line is a real prompt the user might paste. Make it specific and bounded — no "improve the test setup" hand-waves.
