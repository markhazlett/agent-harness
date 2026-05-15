# Agent-Friendliness Rubric

## 1. Purpose & scope

This rubric grades how easy it is for an autonomous LLM coding agent (Claude Code, Cursor, Devin, Aider, OpenHands, Copilot Workspace, SWE-agent, etc.) to be productive in a given codebase *without constant human intervention*. It is read by the `/grade-codebase` skill, which mechanically scores a repository against the dimensions below and then uses model judgment for the residual.

"Agent-friendly" is **not** the same as "well-engineered for humans" — there is heavy overlap, but the asymmetries matter. Agents have a finite (and degrading) context window, no oral tradition, no ability to ping a coworker on Slack, and a tendency to fabricate file paths under pressure. They reward codebases that surface structure mechanically and punish codebases that hide it in tribal knowledge. We grade for the agent's vantage point.

The grade has one consumer (the user reading the report) and two purposes: (a) one-shot judgment of whether a codebase is currently tractable for autonomous work, and (b) a prioritized backlog of fixes that would move the grade up. Section 7 handles the second.

## 2. Methodology notes

**Sources surveyed.** Internal: `.claude/docs/harness-principles.md` (63 principles), the harness's `claude-md-template.md`, and the skills under `.claude/skills/` (notably `tdd`, `pre-deploy`, `debug`). External, anchored:

- Anthropic, [*Best practices for Claude Code*](https://www.anthropic.com/engineering/claude-code-best-practices) and [*How Claude Code works in large codebases*](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start).
- Simon Willison, [*Setting up a codebase for working with coding agents*](https://simonwillison.net/2025/Oct/25/coding-agent-tips/) — the tightest practitioner write-up we found.
- HumanLayer, [*12-Factor Agents*](https://github.com/humanlayer/12-factor-agents) — the production-reliability lens.
- The [AGENTS.md spec](https://agents.md/) (Agentic AI Foundation, Linux Foundation) and GitHub's [*How to write a great agents.md: lessons from over 2,500 repositories*](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/).
- Cognition, [*How Cognition uses Devin to build Devin*](https://cognition.ai/blog/how-cognition-uses-devin-to-build-devin) — what they changed in their *own* codebase to make it tractable.
- Mitchell Hashimoto, [*Vibing a Non-Trivial Ghostty Feature*](https://mitchellh.com/writing/non-trivial-vibing) and the [Zed conversation](https://zed.dev/blog/agentic-engineering-with-mitchell-hashimoto) — the architect-over-coder model.
- Aider, [Repository map](https://aider.chat/docs/repomap.html) — what an agent retrieval system actually wants from your tree.
- Sourcegraph, [*Lessons from building AI coding assistants: context retrieval and evaluation*](https://sourcegraph.com/blog/lessons-from-building-ai-coding-assistants-context-retrieval-and-evaluation) and [*How Cody understands your codebase*](https://sourcegraph.com/blog/how-cody-understands-your-codebase).
- Cursor, [Rules docs](https://cursor.com/docs/rules); [Karpathy's CLAUDE.md](https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md); Phoebe, [*Enforcing Architecture in an Agent-Driven Codebase*](https://www.phoebe.work/blog/enforcing-architecture-in-an-agent-driven-codebase); Augment, [*Harness Engineering for AI Coding Agents*](https://www.augmentcode.com/guides/harness-engineering-ai-coding-agents); Martin Fowler / Birgitta Böckeler, [*Context Engineering for Coding Agents*](https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html).
- Failure-mode literature: [*SWE-Bench Pro*](https://arxiv.org/abs/2509.16941) (long-horizon trajectory analysis), [*A Survey on Code Generation with LLM-based Agents*](https://arxiv.org/html/2508.00083v1), [SWE-EVO](https://arxiv.org/pdf/2512.18470).
- Hamel Husain, [*Evals Skills for Coding Agents*](https://hamel.dev/blog/posts/evals-skills/).

**Deliberately excluded.**

- *Test coverage percentage.* Coverage is a vanity metric; agents care that tests **run fast, fail loud, and are trivially invocable** — not that they touch 90% of lines. (Willison emphasizes runnability, not coverage.)
- *Lines of code, file count, repo age, star count, commit cadence.* Vanity signals that don't predict agent productivity. A 5000-line file with clear sections is fine; a 200-line file that imports half the codebase is not.
- *Presence of a LICENSE, CODE_OF_CONDUCT, or pretty README.* Human-facing hygiene, not agent-facing.
- *Monorepo vs. polyrepo* as a global verdict. Each architecture has agent-friendly and agent-hostile variants; we grade the *symptoms* (cross-cutting changes, dependency clarity) not the shape.
- *Documentation volume.* Willison: "LLMs can read code faster than humans … comprehensive documentation is useful for humans, less helpful for coding agents." We grade *runnable* docs (commands that work) and *triggering* docs (CLAUDE.md / AGENTS.md), not narrative prose.

**Bias to mechanical signals.** Where a signal can be measured by a shell command, we write the command. Judgment signals are kept to a strict minority (§5) so the skill stays auditable.

## 3. Dimensions

Eight dimensions, weights sum to 100%. Each dimension has signals (with measurement), an anti-signal list, and a rationale tied to a specific agent failure mode.

---

### D1. Onboarding context (15%)

**Definition.** Can the agent learn the project from a cold start using only files in the repo — no oral tradition, no Slack, no "ask the team."

**Why for agents specifically.** Agents have no continuity between sessions (HumanLayer 12-Factor §5, §12: stateless reducers; harness principle §39 on re-injection). A human absorbs tribal knowledge over weeks; the agent gets one shot per session. The CLAUDE.md / AGENTS.md pattern exists precisely because [GitHub's analysis of 2,500+ repos](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/) found this is the single highest-leverage file: "provide your agent a specific job or persona, exact commands to run, well-defined boundaries, and clear examples."

**Signals.**

| Signal | Measurement |
|---|---|
| `AGENTS.md` or `CLAUDE.md` at repo root | `test -f AGENTS.md || test -f CLAUDE.md` |
| File covers Commands / Testing / Project structure / Code style / Git workflow / Boundaries | grep for section headers; GitHub recommends [these six core areas](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/) |
| Length 50–500 lines (not empty, not a novel) | `wc -l` — over ~2 screens the middle gets ignored (`claude-md-template.md`) |
| Hierarchical agent docs in major subdirs (monorepo case) | `find . -name AGENTS.md -o -name CLAUDE.md` returns >1 in deep workspaces |
| Commands are copy-pasteable (real flags, no `<your-project>` placeholders) | run a sample; `grep -E '<[a-z-]+>'` |
| README "Quickstart" ends in a runnable command in <10 lines | judgment + grep |

**Weight justification (15%).** The single most-cited recommendation across every external source we surveyed. The agent reads this *first* every session; getting it wrong poisons the rest.

**Anti-signals.** A 100-page README. A wiki link with no content in the repo. Aspirational instructions ("we plan to add tests"). Generic AGENTS.md copy-pasted from a template with no project content. Commands written as prose rather than code blocks.

---

### D2. Build/test/lint loop (18%)

**Definition.** Can the agent run the project, exercise it, lint it, and get fast honest feedback — with **one command each**.

**Why for agents specifically.** This is the agent's verification loop. Without it the agent falls back to claiming success without evidence (harness principle §33 — the most common LLM coding failure). Willison: "Linters, type checkers, auto-formatters — give coding agents helpful tools to run and they'll use them." [Augment's harness engineering writeup](https://www.augmentcode.com/guides/harness-engineering-ai-coding-agents): LLM compliance is probabilistic; only deterministic outer-harness gates make it reliable at scale. Cognition's [Devin-on-Devin post](https://cognition.ai/blog/how-cognition-uses-devin-to-build-devin) credits tightening these gates as a top reason their PR throughput jumped.

**Signals.**

| Signal | Measurement |
|---|---|
| One-command install on clean checkout | run it; exit 0 in <5 min |
| One-command test exists and runs | `npm test` / `pytest` / `cargo test` / `make test` |
| Unit test suite finishes in <60s (target <30s) | `time` it; slow tests train the agent to skip them |
| Lint/format/typecheck single command, <30s | `npm run lint`, `ruff check`, `tsc --noEmit` |
| CI runs the same commands the agent runs locally | inspect `.github/workflows`, compare with AGENTS.md |
| Test failures include enough context to act on without re-running | sample; Willison: "stuffing extra data in the assertion is inexpensive" |
| Pre-commit hooks fail loud (don't silently auto-fix) | `.pre-commit-config.yaml` / `.husky` |

**Weight justification (18%).** The single biggest determinant of whether an agent can work unattended. A codebase with no test command is one where the agent must trust itself.

**Anti-signals.** Tests requiring manual setup (start a DB, set env vars, log into VPN) with no documented one-liner. Tests that pass when code is broken (no assertions). A 10-minute test suite. Lint config so strict the agent spends every iteration fighting style — or so absent it writes in five styles.

---

### D3. Code navigability & locality (15%)

**Definition.** Can the agent locate symbols, follow types, and change one thing without secret coupling pulling in five others.

**Why for agents specifically.** [SWE-Bench Pro's trajectory analysis](https://arxiv.org/abs/2509.16941) found that even strong models fail predominantly on "navigating large, unfamiliar codebases" and "high-precision edits across multiple files." Aider's [repo-map design](https://aider.chat/docs/repomap.html) treats code locality as a first-class retrieval problem — files connected by call edges get included together. HumanLayer's 12-Factor §3 warns that context past ~40% utilization enters a "dumb zone"; the agent must change things while loading only a few files. Hidden coupling is the killer.

**Signals.**

| Signal | Measurement |
|---|---|
| Statically-typed language, or strict type checker on (TypeScript strict, mypy strict, Sorbet) | `tsconfig.json` `"strict": true`; mypy strict config |
| Symbol search returns one definition for ~unique names | sample 5 functions; `grep -rn "def foo\b"` ≤2 sites |
| Module/feature folders are colocated (one feature = one folder, not split by tech layer across 5 dirs) | tree inspection; judgment |
| Average file <600 lines | `find . -name '*.ts' | xargs wc -l | awk '$1>1000'` |
| Imports explicit (no wildcards, no auto-loaders) | `grep -rE 'from .* import \*'` ~0 |
| Public API boundaries surfaced (`__all__`, barrel `index.ts`) | inspection |
| Names are honest: `validate_email` validates email | judgment; sampled |

**Weight justification (15%).** Locality directly governs how much context the agent must load to make a change. Bad locality = every change touches the dumb zone.

**Anti-signals.** Dynamic dispatch / DI containers without compile-time guarantees. Generated code with no clear regeneration command. "God objects." Same name used for 4 different things. Heavy metaclass/decorator/AST manipulation that hides control flow. Implicit cross-file globals.

---

### D4. Deterministic mechanical gates (12%)

**Definition.** Non-model gates that catch the agent's specific failure modes — drift, hallucination, style violations, half-done work.

**Why for agents specifically.** Forcing functions beat guidance (harness principle §2). The harness's `pre-deploy`, `tdd`, `verification-before-completion` skills exist because the model alone won't self-impose them. The codebase needs the same. [Phoebe](https://www.phoebe.work/blog/enforcing-architecture-in-an-agent-driven-codebase): "What can be inferred from the codebase should be handled by the Context Engine; rules files are reserved for what cannot be inferred." For the rest, ship enforcement.

**Signals.**

| Signal | Measurement |
|---|---|
| Formatter runs in CI in `--check` mode and fails the build | grep CI config |
| Type check is a hard gate in CI | grep CI for `tsc`, `mypy`, `cargo check` |
| Lint warnings cap (`--max-warnings 0` or equivalent) | grep |
| Architectural rules encoded (`eslint-plugin-import`, `import-linter`, `dependency-cruiser`, workspace dependency rules) | file + config inspection |
| Schema/migration validation is a gate (Prisma diff, Alembic, sqlc) | inspection |
| Secrets scanner on (gitleaks, trufflehog, GitHub secret scanning) | `.gitleaks.toml`, gh API |
| `git status` clean after a successful build (no untracked generated leakage) | run build, diff |

**Weight justification (12%).** Lower than the build/test loop because tests catch most of what a missing gate would miss. But for high-velocity agent work (many PRs/day) gates are the difference between net-positive and net-negative productivity.

**Anti-signals.** "Warnings as suggestions." Project-wide `eslint-disable`. CI checks with `continue-on-error: true`. A formatter installed but not enforced. Pre-commit hooks that auto-fix but never fail — agents silently bypass them.

---

### D5. Failure honesty (10%)

**Definition.** When something breaks, the codebase says what broke, where, and why. Errors are loud, specific, and reproducible.

**Why for agents specifically.** Willison: "If a manual or automated test fails the more information you can return back to the model the better." Harness principle §6 (Fail Loud): silent failures are future incidents; for agents they're also debugging dead-ends — the agent re-runs, sees the same vague output, and either guesses or claims success. [SWE-EVO's failure analysis](https://arxiv.org/pdf/2512.18470) identifies "swallowed errors" and "generic exception handlers" as top reasons agents fail to converge on a fix.

**Signals.**

| Signal | Measurement |
|---|---|
| No bare `except:` / `catch (_)` / `catch (e) {}` blocks | `grep -rnE 'except:|catch \(\)|catch \(_\)'` ≈ 0 |
| Errors include identifiers (which user, which file, which row), not just types | sample; judgment |
| Logging is structured (JSON or key=value), not freeform prose | inspect log call sites |
| Test assertions include messages, expected/actual diffs, repro hints | sample 10 tests |
| Stack traces survive boundaries (`raise X from e`, `errors.Wrap`, error wrapping) | grep |
| Reproducible bug-report format (issue template, or `--debug` flag dumping env+versions) | inspection |

**Weight justification (10%).** Critical but not high-leverage at the rubric level — the failure-honesty payoff compounds inside D2 (the loop) and D3 (debugging). 10% is enough to penalize codebases that swallow exceptions.

**Anti-signals.** Sentry tags as the only error context. `console.log("error")` with no detail. `try { … } catch { return null }`. Defaulting to empty string instead of throwing on missing config.

---

### D6. Reproducibility & environment hermeticity (8%)

**Definition.** Can the agent get to a working environment from a clean machine, deterministically, and rerun a failure?

**Why for agents specifically.** Agents (Devin, OpenHands, sandboxed Claude Code) operate in fresh containers constantly. Hermeticity isn't a luxury — it's the precondition for autonomous operation. [Cognition's Devin-on-Devin post](https://cognition.ai/blog/how-cognition-uses-devin-to-build-devin) cites environment-setup investment as one of the highest-leverage things they did to their own codebase. Sourcegraph's [agent context retrieval lessons](https://sourcegraph.com/blog/lessons-from-building-ai-coding-assistants-context-retrieval-and-evaluation) emphasize the same on the eval side.

**Signals.**

| Signal | Measurement |
|---|---|
| Pinned dependency versions (lockfile committed) | `test -f package-lock.json || yarn.lock || pnpm-lock.yaml || poetry.lock || uv.lock || Cargo.lock || go.sum` |
| Runtime version pinned | `.nvmrc`, `.python-version`, `rust-toolchain.toml`, `go.mod` go directive |
| Container or devcontainer config | `Dockerfile`, `.devcontainer/`, `flake.nix` |
| `.env.example` is the only env onboarding step | `test -f .env.example` |
| One command boots databases/queues/infra | `docker compose up`, `make dev-up` |
| No "ask Bob for the API key" instructions | grep for personal names in setup docs |

**Weight justification (8%).** A pinned lockfile is necessary but rarely sufficient. Weighting reflects that "environment broken" is a binary disqualifier for autonomous agents but rarely the *only* problem.

**Anti-signals.** "Works with Node 14 or 18 or 20." Unpinned `latest` Docker base images. Secret-manager dependencies that can't be stubbed for tests. Floating-point dependency on the developer's local Postgres. Setup scripts that assume macOS.

---

### D7. Change-safety affordances (12%)

**Definition.** Can the agent make a change, prove it didn't break anything, and recover when it does — with mechanisms the codebase provides rather than ones the agent invents?

**Why for agents specifically.** Hashimoto's Ghostty pattern: ["over-aggressively create commits"](https://zed.dev/blog/agentic-engineering-with-mitchell-hashimoto) so the agent has cheap rollback. Harness principle §30 (bite-sized tasks) + §32 (user review gates). Agents thrash without checkpoints; with them they self-bound. Karpathy's "Surgical Changes" principle in [CLAUDE.md](https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md) — the agent needs to know where the blast radius ends.

**Signals.**

| Signal | Measurement |
|---|---|
| Feature flags / gates for in-progress work | grep for a flag library (`unleash`, `launchdarkly`, `posthog`, `OpenFeature`) or convention |
| Migrations are atomic with rollback (or forward-only with documented backfill) | `find migrations -name '*down*'` or inspection |
| Branch protection on `main` (CI must pass, no force push) | `gh api repos/:owner/:repo/branches/main/protection` |
| Snapshot tests / golden files for stable-output surfaces | `find . -name '*.snap' -o -name '__snapshots__'` |
| Contracts/types at I/O boundaries (OpenAPI, GraphQL, protobuf, zod, pydantic) | file existence |
| Commits small and rebaseable (median <300 LOC over recent 50 commits) | `git log --shortstat -50` + awk |
| `git bisect` works (no flaky-by-time tests, no time-bombs) | judgment |

**Weight justification (12%).** Directly governs the cost of an agent's wrong turn. A codebase where each agent mistake costs an hour to undo is one where agents are a liability; where each costs 30 seconds, agents compound.

**Anti-signals.** Long-lived feature branches drifting for weeks. Manual migration steps in production. PRs requiring 5 reviewers. No way to deploy a small thing without a release train. Tests that depend on time/network/random without seeding.

---

### D8. Conventions discoverable from code, not lore (10%)

**Definition.** When the agent needs to know "how do we do X here?" it can find the answer by reading the codebase, not by being told.

**Why for agents specifically.** Willison: "even having just one or two tests in the style you like means agents will write tests in the style you like. There's a lot to be said for keeping your codebase high quality because the agent will then add to it in a high quality way." [Cursor's rules docs](https://cursor.com/docs/rules) and [Phoebe's writeup](https://www.phoebe.work/blog/enforcing-architecture-in-an-agent-driven-codebase) converge on: "What can be inferred from the codebase should be handled by the Context Engine; rules files are reserved for what cannot be inferred." Agents pattern-match; if the codebase contains one canonical example of every pattern, the agent reproduces it.

**Signals.**

| Signal | Measurement |
|---|---|
| Canonical example of each common operation (one feature endpoint, one CRUD slice, one job) the agent can clone | inspection |
| Consistent naming visible from `ls` (one casing for files, one for symbols) | sample; ratio of dominant casing |
| Tests live alongside code, or in a 1:1 mirror directory | `find` for `_test.{js,ts,py,go}` adjacent to source |
| Config centralized (one `config/`, one `settings.py`, not 30 scattered env reads) | grep env reads; should cluster |
| Common operations (logging, error wrapping, db access) go through one helper, not 5 | judgment + grep |
| A "where new code goes" answer is obvious from the tree | inspection |

**Weight justification (10%).** This is the dimension that scales: a well-conventioned codebase compounds *with* agent contributions; a poorly-conventioned one entropies *faster* with them. Lower than D1/D2 because effects show up over weeks, not minutes.

**Anti-signals.** Three different ORMs. Five HTTP-client patterns. Conventions documented but not exemplified. Conventions exemplified but contradicted by half the codebase. A `utils/` folder with 60 files.

---

## 4. Grading scale

Each dimension is scored A/B/C/D/F. The overall grade is the *weighted* letter average, rounded to the nearest letter.

| Letter | Numeric | Plain English |
|---|---|---|
| A | 90–100 | Agent ships work here with near-human autonomy. <5% of attempts hit environmental friction. |
| B | 75–89 | Agent productive but needs occasional human nudges (a missing command, a misleading test). ~15% friction loss. |
| C | 60–74 | Agent can work here but loses ~30% of attempts to environmental friction. Worth the agent only for well-scoped tasks. |
| D | 45–59 | Agent net-negative on most tasks. Each PR costs more to review than it saves. |
| F | <45 | Agent should not be deployed here unattended. Tribal knowledge dominates. |

**Roll-up.** Convert each dimension's letter to its midpoint (A=95, B=82, C=67, D=52, F=30). Weighted-average using dimension weights. Map back: ≥90 A, ≥75 B, ≥60 C, ≥45 D, else F.

**Per-dimension scoring rubric.**
- **A**: ≥80% of signals present and mechanical signals all pass. No anti-signals.
- **B**: ≥60% of signals present. ≤1 minor anti-signal.
- **C**: ≥40% of signals or critical mechanical signals fail. Anti-signals visible but not dominant.
- **D**: <40% of signals or a critical-path signal fails (e.g., no test command at all for D2).
- **F**: Dimension materially absent (no AGENTS.md/CLAUDE.md *and* no README for D1; tests don't run for D2).

## 5. Mechanical vs. judgment signals

The skill should automate the left column; it must ask the model for the right column.

| Mechanical (run a command) | Judgment (model assesses) |
|---|---|
| File existence (`AGENTS.md`, lockfile, `.env.example`, CI config) | Whether `AGENTS.md` is *useful* vs. a stub |
| Command runtime (test, lint, build) | Whether error messages are *informative* |
| Line counts, file counts, file size distribution | Whether modules are *cohesive* |
| Lockfile and runtime-version pinning | Whether names are *honest* |
| Grep for anti-patterns (`from x import *`, bare `except:`) | Whether conventions are *consistent* |
| `git log --shortstat` averages | Whether the canonical example is actually canonical |
| Branch protection via `gh api` | Whether feature flags are *used*, not just *installed* |
| Test suite exit code + wall time | Whether failure messages give enough context to act on |

Where a judgment signal is unavoidable, it counts for at most 50% of a dimension's score.

## 6. Anti-patterns / red flags (cap the grade at C or below)

Any one of these caps the *overall* grade at C, regardless of other dimensions. They break the agent's core loop.

1. **No test command, or test command doesn't work on a clean checkout.** The agent cannot self-verify.
2. **No lockfile or pinned runtime.** The agent's environment is non-deterministic between sessions.
3. **CI runtime >20 minutes for unit tests.** Feedback loop too slow; agent guesses.
4. **Tests that mutate shared state and require manual cleanup.** Agent stuck after first run.
5. **Secrets required for tests with no documented stub.** Agent cannot run anything end-to-end.
6. **Generated code committed without a regeneration command.** Agent edits the generated file; conflicts forever.
7. **`main` where `git log -p` shows >50% of recent commits broke the build.** Agent's "is it working" reference is unreliable.
8. **Bare `except:` / empty `catch` in hot paths.** Errors vanish; debugging impossible.
9. **`AGENTS.md`/`CLAUDE.md` contradicts the actual codebase** (says `npm test` when real is `yarn test`). Worse than no doc — actively misleads.
10. **A dependency on a developer's local machine state** (locally-installed CLI, `~/.config` file, login session) not part of setup.

## 7. Backlog generation hints

For each dimension, the kinds of tasks that move the grade up. The `/grade-codebase` skill's "full report" mode turns these into an agent-actionable backlog.

- **D1 Onboarding context.** Add `AGENTS.md` with the six core sections (Commands, Testing, Project structure, Code style, Git workflow, Boundaries). Trim README to <2 screens. Replace placeholders with real commands. For monorepos, add per-package `AGENTS.md`.
- **D2 Build/test/lint loop.** Add a `make help` / `pnpm run` index of canonical commands. Parallelize the test suite under 30s. Add in-memory or containerized fixtures for the database. Move slow integration tests behind a `--slow` flag.
- **D3 Code navigability & locality.** Turn on strict mode in the type-checker. Split files >1000 LOC into named modules. Replace barrel re-exports with direct imports on hot paths. Add an `eslint-plugin-import` / `import-linter` boundary check.
- **D4 Mechanical gates.** Enable formatter `--check` in CI. Add `--max-warnings 0`. Adopt a secret scanner. Add an architecture-rules linter (`dependency-cruiser`, `import-linter`, `arch-unit`).
- **D5 Failure honesty.** Audit `except`/`catch` for swallowed errors. Add structured logging. Write a "what to include in a bug report" issue template. Add error-context wrapping at boundaries.
- **D6 Reproducibility & hermeticity.** Pin the runtime. Commit a lockfile. Add a `Dockerfile` + `docker compose` for infra. Replace personal API keys with stubs or local-only secrets.
- **D7 Change-safety affordances.** Adopt feature flags for unfinished work. Enforce branch protection on `main`. Add snapshot tests for stable-output surfaces. Document migration rollback. Encourage smaller commits.
- **D8 Conventions discoverable from code.** Build one canonical example for each common operation (one CRUD endpoint, one job, one form). Consolidate to one helper for logging / errors / DB. Add a `docs/conventions.md` *only* with rules not enforceable by linter (per Phoebe's rule).

## 8. Open questions / known weaknesses

- **Eval gap.** This rubric grades the *substrate* (the codebase), not the *outcome* (how well a given agent does in it). A rigorous validation would run a fixed set of well-scoped tasks against representative repos at each grade and measure success rate. Until then, the weights are informed but not empirically tuned. Hamel Husain's [coding-agent evals work](https://hamel.dev/blog/posts/evals-skills/) is the closest analog and a potential future input.
- **Domain bias.** The rubric tilts toward web/services repos (TypeScript, Python, Go). Embedded, ML-training, infra-as-code, and game-engine codebases have different ergonomics (a CUDA codebase's "test" is a benchmark; a Terraform module's "verification" is a `plan` diff). The skill should branch on detected stack.
- **Conflict between agent and human ergonomics.** Mostly they align (Willison's thesis). Two exceptions we couldn't fully resolve: (a) **documentation volume** — humans want more, agents want less; (b) **abstraction depth** — humans tolerate dynamic dispatch and DI containers, agents lose track of them. We've sided with the agent in both cases (D1 caps length at 500 lines; D3 penalizes hidden control flow), but a human-only reviewer would push back.
- **Monorepo vs. polyrepo.** We deliberately avoided a verdict. Nx's [argument that monorepos are 4× faster for cross-cutting changes](https://nx.dev/blog/the-missing-multiplier-for-ai-agent-productivity) is real but downstream of D3 (locality) and D8 (conventions). A polyrepo with strong contracts at boundaries can score as well as a monorepo with tangled imports. We grade the symptoms, not the shape — meaning a polyrepo org running a fleet of related repos may score each one well individually while still suffering cross-repo friction the rubric doesn't see.
- **Tool-loop weight.** [The 12-Factor "small focused agents"](https://github.com/humanlayer/12-factor-agents) and the [SWE-Bench Pro long-horizon results](https://arxiv.org/abs/2509.16941) both argue that *task scoping* matters as much as codebase quality. We don't grade task scoping because it's not a property of the codebase — but a codebase that *invites* small tasks (well-modularized, good D3+D8) will look better than one forcing every change to span 12 files. The current weights probably under-credit this compounding.
- **Drift over time.** Karpathy's observation that agents introduce ["hypertrophy of code and abstractions"](https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md) means an A-graded codebase under continuous agent contribution can drift to B or C without anyone noticing. The rubric is a snapshot; it does not yet include a "drift detector" signal like "did the file-count grow 3× in 6 months without a commensurate feature increase?"
- **AGENTS.md vs. CLAUDE.md vs. .cursorrules.** [AGENTS.md is now the cross-tool open standard](https://agents.md/) (Linux Foundation), but Claude Code still preferentially reads `CLAUDE.md`, Cursor reads `.cursor/rules`. We treat any of them as evidence for D1; the skill should detect the user's primary agent and not penalize redundancy.
