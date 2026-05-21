# Per-dimension narrative — `/grade-codebase` step 7

A letter grade lands as judgment. Defend it.

**For every dimension you scored**, write a short narrative section that does four things:

1. **Translate the rubric's "Plain-English case" into this codebase.** Don't just quote the rubric — name the specific files / commands / patterns in *this* repo that the case applies to. If the rubric's example doesn't apply (e.g. the rubric mentions `pnpm test` and this is a Cargo workspace), substitute the equivalent from this repo's discovery preamble.
2. **Cite the evidence that drove the letter.** Specific file paths, command runtimes, grep counts. "D2 scored C because `make test` ran in 4m 17s; the agent will run this 3–5× per task." Numbers beat adjectives.
3. **Quantify the cost where you can.** Use the rubric's "Cost of leaving this alone" framings with the actual numbers from this codebase plugged in. State your assumptions ("at Claude Sonnet token rates ~$3/M output"). Where quantification would be fake-precise, say "the cost shows up as…" and describe the failure mode.
4. **Acknowledge the most likely objection.** Pull from the rubric's "Common objections" table — pick the one most likely to apply to *this* codebase, not the textbook one. If you saw evidence of an objection's *legitimate* part (e.g., this repo is a prototype, this team isn't using agents yet), say so up front.

## Audience

A skeptical senior engineer and their engineering manager. They've heard agent pitches and bounced. Tone is direct, technical, no salesy language ("supercharge", "10x"). Concede tradeoffs honestly.

## Length

100–200 words per dimension. The skeptic should finish reading and either agree, or have a *specific* counter-argument — not a vague "this feels like overkill."

## Honesty rules

- **Do not invent evidence to defend a grade.** If you scored D2 a B but can't cite a specific reason in this repo, the score is wrong — re-grade rather than confabulate.
- **Quantify honestly or not at all.** If a number would be fake-precise, write "hard to quantify; the cost shows up as …" instead of fabricating one.
- **Pick the objection that fits this repo.** Not the most flattering to refute. If this repo is genuinely a 3-person prototype and D6 hermeticity is overkill, say so — the rubric explicitly allows scope-appropriate caveats.
- **Cite the discovery preamble**, not assumed defaults. "D4 was graded against `.gitlab-ci.yml`" beats "D4 was graded against CI" beats silently grading against `.github/workflows/` when GitLab is the forge.

## What good looks like (excerpt)

> **D2 — Build/test/lint loop — B**
>
> The canonical loop here is `cargo test --workspace` (discovered in `Cargo.toml` + `xtask/src/main.rs`). It runs in 38 seconds on a warm cache, 2m 12s cold. An agent will run this 3–5× per task; the warm-cache path is fast enough that the agent won't skip it, which is the load-bearing property. The lint loop (`cargo clippy --all-targets`) adds another 24s.
>
> The B (not A) is because cold-cache time exceeds the rubric's 60s threshold and there's no test-result caching keyed on changed files. Cost shows up when CI runs from a cold container: each failed CI iteration burns ~$0.40 in agent tokens just on the test-output context plus 3 minutes of wall-clock. At 50 agent PRs/month and 15% retry rate, that's ~$3 and 22 minutes of CI delay — small but non-zero.
>
> Most likely objection: "Cold-cache is rare in dev — only CI sees it." Fair, but the agent runs against CI for the failure-mode signal, and CI cold-cache is most of CI. If you don't use cloud agents, this objection holds and the grade should be read as A-with-an-asterisk.
