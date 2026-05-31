# Agent-Friendliness Rubric

## 1. Purpose & scope

This rubric grades how easy it is for an autonomous LLM coding agent (Claude Code, Cursor, Devin, Aider, OpenHands, Copilot Workspace, SWE-agent, etc.) to be productive in a given codebase *without constant human intervention*. It is read by the `/grade-codebase` skill, which mechanically scores a repository against the dimensions below and then uses model judgment for the residual.

"Agent-friendly" is **not** the same as "well-engineered for humans" — there is heavy overlap, but the asymmetries matter. Agents have a finite (and degrading) context window, no oral tradition, no ability to ping a coworker on Slack, and a tendency to fabricate file paths under pressure. They reward codebases that surface structure mechanically and punish codebases that hide it in tribal knowledge. We grade for the agent's vantage point.

The grade has one consumer (the user reading the report) and two purposes: (a) one-shot judgment of whether a codebase is currently tractable for autonomous work, and (b) a prioritized backlog of fixes that would move the grade up. Section 7 handles the second.

## 2. Methodology notes

**Sources surveyed.** Internal: `.claude/docs/harness-principles.md` (63 principles), the harness's `claude-md-template.md`, and the skills under `.claude/skills/` (notably `tdd`, `pre-deploy`, `debug`). External sources are organised by cluster below. The v2 deepening pass roughly tripled the citation count (~17 → ~60+); §9 catalogues additions and what changed.

**Vendor / lab engineering writing.**
- Anthropic, [*Best practices for Claude Code*](https://www.anthropic.com/engineering/claude-code-best-practices), [*How Claude Code works in large codebases*](https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start), [*Building Effective AI Agents: Architecture Patterns*](https://resources.anthropic.com/hubfs/Building%20Effective%20AI%20Agents-%20Architecture%20Patterns%20and%20Implementation%20Frameworks.pdf), [*Agent Skills overview*](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview), the [Claude Code worktrees docs](https://code.claude.com/docs/en/worktrees), and the [Claude Code sandboxing release](https://www.infoq.com/news/2025/11/anthropic-claude-code-sandbox/).
- OpenAI, [Codex product page](https://openai.com/codex/), [Codex AGENTS.md custom-instructions guide](https://developers.openai.com/codex/guides/agents-md), [Codex Best Practices](https://developers.openai.com/codex/learn/best-practices), [Codex cloud](https://developers.openai.com/codex/cloud).
- GitHub, [*How to write a great agents.md (lessons from 2,500+ repos)*](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/), the [AGENTS.md spec](https://agents.md/) (Agentic AI Foundation / Linux Foundation), [Copilot Workspace](https://githubnext.com/projects/copilot-workspace/) and the [coding agent / Spaces launches](https://github.blog/news-insights/product-news/github-copilot-workspace/), [GitHub Spec Kit](https://github.com/topics/spec-driven-development), [Octoverse 2025 AI section](https://github.blog/news-insights/octoverse/octoverse-a-new-developer-joins-github-every-second-as-ai-leads-typescript-to-1/).

**Coding-agent product engineering.**
- Cognition, [*How Cognition uses Devin to build Devin*](https://cognition.ai/blog/how-cognition-uses-devin-to-build-devin), [*Devin 2.0*](https://cognition.ai/blog/devin-2), [*Devin 2025 Performance Review*](https://cognition.ai/blog/devin-annual-performance-review-2025), [*DeepWiki*](https://cognition.ai/blog/deepwiki), [DeepWiki MCP server](https://cognition.ai/blog/deepwiki-mcp-server).
- Mitchell Hashimoto, [*Vibing a Non-Trivial Ghostty Feature*](https://mitchellh.com/writing/non-trivial-vibing), the [Zed agentic-engineering conversation](https://zed.dev/blog/agentic-engineering-with-mitchell-hashimoto), [*My AI Adoption Journey*](https://mitchellh.com/writing/my-ai-adoption-journey).
- Aider, [Repository map](https://aider.chat/docs/repomap.html) (PageRank-weighted tree-sitter map) and Paul Gauthier's [HISTORY notes](https://github.com/paul-gauthier/aider/blob/main/HISTORY.md).
- Sourcegraph, [*Lessons from building AI coding assistants*](https://sourcegraph.com/blog/lessons-from-building-ai-coding-assistants-context-retrieval-and-evaluation), [*How Cody understands your codebase*](https://sourcegraph.com/blog/how-cody-understands-your-codebase), Steve Yegge's [*Revenge of the junior developer*](https://sourcegraph.com/blog/revenge-of-the-junior-developer).
- Cursor, [Rules docs](https://cursor.com/docs/rules), [*Best practices for coding with agents*](https://cursor.com/blog/agent-best-practices) (plan mode, worktree-isolated parallel agents).
- Continue.dev, [*Codebase awareness*](https://docs.continue.dev/guides/codebase-documentation-awareness), [@Codebase indexing](https://docs.continue.dev/customize/context/codebase).
- Cline / Roo Code, [Custom Instructions](https://docs.roocode.com/features/custom-instructions), [AGENTS.md adoption discussion](https://github.com/RooCodeInc/Roo-Code/issues/5966).
- Augment, [*Harness Engineering for AI Coding Agents*](https://www.augmentcode.com/guides/harness-engineering-ai-coding-agents), [*Context is the new compiler*](https://workos.com/blog/augment-code-context-is-the-new-compiler), [*Real-time codebase index*](https://www.augmentcode.com/blog/a-real-time-index-for-your-codebase-secure-personal-scalable), [*100M-line quantized vector search*](https://www.augmentcode.com/blog/repo-scale-100M-line-codebase-quantized-vector-search), [*AI Agent Loop Token Costs*](https://www.augmentcode.com/guides/ai-agent-loop-token-cost-context-constraints).
- Factory.ai, [*Droid sets SOTA on Terminal-Bench*](https://factory.ai/news/terminal-bench), [Custom Droids docs](https://docs.factory.ai/cli/configuration/custom-droids).
- JetBrains, [*Junie now integrated into AI Chat*](https://blog.jetbrains.com/ai/2025/12/junie-now-integrated-into-the-ai-chat/), [*The Agentic AI Era at JetBrains*](https://blog.jetbrains.com/junie/2025/07/the-agentic-ai-era-at-jetbrains-is-here/).
- Replit, [Agent docs](https://docs.replit.com/replitai/agent) (ephemeral filesystem; agent works best on fresh projects).
- OpenHands, [ICLR 2025 paper](https://arxiv.org/pdf/2407.16741), [custom sandbox guide](https://docs.openhands.dev/openhands/usage/advanced/custom-sandbox-guide).
- David Crawshaw (sketch.dev), [*Programming with Agents*](https://crawshaw.io/blog/programming-with-agents), [*Eight more months of agents*](https://crawshaw.io/blog/eight-more-months-of-agents).
- Sentry, [*Seer Agent*](https://thenewstack.io/sentrys-seer-agent-debug/), [*Scaling observability for multi-agent AI*](https://blog.sentry.io/scaling-observability-for-multi-agent-ai-systems/).
- Conductor / parallel-agent worktrees: [Ry Walker research notes](https://rywalker.com/research/conductor); the harness's own `/worktree` skill.

**Academic — coding-agent evals and architecture.**
- [SWE-bench Verified leaderboard](https://www.swebench.com/verified.html) (best public models ~43% in 2026).
- [SWE-Bench Pro](https://arxiv.org/abs/2509.16941) — long-horizon trajectory analysis; "navigating large unfamiliar codebases" and "high-precision multi-file edits" identified as dominant failure modes; <20% on commercial enterprise set.
- [SWE-agent (NeurIPS 2024)](https://arxiv.org/abs/2405.15793) — Agent-Computer Interface design: tailored search/navigation and bounded file viewers raise SWE-bench score 5×+ over naive shell access.
- [AutoCodeRover](https://arxiv.org/pdf/2404.05427) — AST-aware code search outperforms string search; fault localisation using tests boosts repair rate (46% on SWE-bench Verified).
- [SWE-EVO](https://arxiv.org/pdf/2512.18470) — swallowed errors and generic exception handlers identified as top reasons agents fail to converge.
- [*Survey on Code Generation with LLM-based Agents*](https://arxiv.org/html/2508.00083v1) and [*Retrieval-Augmented Code Generation: a Survey*](https://arxiv.org/html/2510.04905v1).
- Microsoft, [*Magentic-One*](https://www.microsoft.com/en-us/research/articles/magentic-one-a-generalist-multi-agent-system-for-solving-complex-tasks/) — Task Ledger / Progress Ledger orchestrator pattern.
- Benchmarks: [LiveCodeBench](https://livecodebench.github.io/), [BigCodeBench (ICLR'25)](https://bigcode-bench.github.io/), [LiveCodeBench Pro](https://livecodebenchpro.com/).

**Practitioner / researcher writing.**
- Simon Willison, [*Setting up a codebase for working with coding agents*](https://simonwillison.net/2025/Oct/25/coding-agent-tips/), [*Agentic Engineering Patterns*](https://simonw.substack.com/p/agentic-engineering-patterns), [*Claude Skills are awesome*](https://simonwillison.net/2025/Oct/16/claude-skills/).
- Hamel Husain, [*Your AI Product Needs Evals*](https://hamel.dev/blog/posts/evals/), [*LLM-as-a-Judge complete guide*](https://hamel.dev/blog/posts/llm-judge/index.html), [*Field Guide to Rapidly Improving AI Products*](https://hamel.dev/blog/posts/field-guide/), [*Evals Skills for Coding Agents*](https://hamel.dev/blog/posts/evals-skills/).
- Martin Fowler / Birgitta Böckeler, [*Context Engineering for Coding Agents*](https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html) and Thoughtworks's [*Harness engineering and agent feedback*](https://www.thoughtworks.com/en-au/insights/blog/generative-ai/harness-engineering-agent-feedback-exploring-ai-coding-sensors).
- Andrej Karpathy, [CLAUDE.md / skills file](https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md) — "hypertrophy of code and abstractions" as a first-class agent failure mode.
- Kent Beck, [*Augmented Coding: Beyond the Vibes*](https://tidyfirst.substack.com/p/augmented-coding-beyond-the-vibes), [*Exploring AI*](https://tidyfirst.substack.com/p/exploring-ai) — "AI genies are astonishingly bad at safe sequencing."
- Charity Majors (Honeycomb), [Pragmatic Engineer observability conversation](https://newsletter.pragmaticengineer.com/p/observability-the-present-and-future); the Honeycomb 10-year [*Observability in a World of AI*](https://www.honeycomb.io/blog/honeycomb-10-year-manifesto-part-1) manifesto.
- Phoebe, [*Enforcing Architecture in an Agent-Driven Codebase*](https://www.phoebe.work/blog/enforcing-architecture-in-an-agent-driven-codebase) — "what can be inferred from the codebase should be handled by the Context Engine; rules files are for what cannot."
- Hillel Wayne, [*Using Formal Methods at Work*](https://www.hillelwayne.com/post/using-formal-methods/), [*Business Case for Formal Methods*](https://www.hillelwayne.com/post/business-case-formal-methods/).
- Steve Yegge, [*The Future of Coding Agents*](https://steve-yegge.medium.com/the-future-of-coding-agents-e9451a84207c) (waves: chat → agents → clusters → fleets); [Latent.space "Normsky" episode](https://www.latent.space/p/sourcegraph).
- Chip Huyen, [*AI Engineering*](https://www.oreilly.com/library/view/ai-engineering/9781098166298/) — Agent Failure Modes chapter.
- Geoffrey Litt, [*Malleable software in the age of LLMs*](https://www.geoffreylitt.com/2023/03/25/llm-end-user-programming.html).

**Adjacent disciplines.**
- [12-Factor App](https://12factor.net/) (Wiggins) and HumanLayer's [12-Factor Agents](https://github.com/humanlayer/12-factor-agents) — config-as-env, lockfiles, stateless processes.
- Neal Ford / Rebecca Parsons, [*Building Evolutionary Architectures*](https://nealford.com/books/buildingevolutionaryarchitectures.html) — fitness functions = mechanical gates.
- Bazel [Hermeticity](https://bazel.build/basics/hermeticity); the [reproducible-builds.org](https://reproducible-builds.org/) project.
- Trunk-based development: [trunkbaseddevelopment.com](https://trunkbaseddevelopment.com/), [Aviator's TBD guide](https://www.aviator.co/blog/trunk-based-development/).
- Spec-driven dev: [GitHub Spec Kit launch coverage](https://www.marktechpost.com/2026/05/08/meet-github-spec-kit-an-open-source-toolkit-for-spec-driven-development-with-ai-coding-agents/), [Specmatic article](https://specmatic.io/article/spec-driven-development-beyond-the-first-feature-with-api-design-first/), [OpenSpec](https://github.com/Fission-AI/OpenSpec).
- ADRs: [adr.github.io](https://adr.github.io/); [Cognitect's ADR post](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions); [joelparkerhenderson/architecture-decision-record](https://github.com/joelparkerhenderson/architecture-decision-record).
- Architecture-rule linters: [dependency-cruiser](https://github.com/sverweij/dependency-cruiser), [import-linter](https://github.com/seddonym/import-linter), [Nx module-boundary rules](https://www.stefanos-lignos.dev/posts/nx-module-boundaries).
- Observability: [OpenTelemetry Logs spec](https://opentelemetry.io/docs/specs/otel/logs/) — trace-correlated structured logs.
- Storybook visual regression: [visual tests docs](https://storybook.js.org/docs/writing-tests/visual-testing).
- Database safety under agents: [Prisma Migrate deploy guide](https://www.prisma.io/docs/orm/prisma-client/deployment/deploy-database-changes-with-prisma-migrate); [*Type-Safe Database Access for AI-Paired Codebases*](https://suparbase.com/blog/type-safe-database-for-ai-paired-code).
- Agent-security posture: NVIDIA's [*Practical Security Guidance for Sandboxing Agentic Workflows*](https://developer.nvidia.com/blog/practical-security-guidance-for-sandboxing-agentic-workflows-and-managing-execution-risk/); the [Google Antigravity sandbox-escape report](https://cyberscoop.com/google-antigravity-pillar-security-agent-sandbox-escape-remote-code-execution/); Microsoft Security's [*When prompts become shells*](https://www.microsoft.com/en-us/security/blog/2026/05/07/prompts-become-shells-rce-vulnerabilities-ai-agent-frameworks/); OpenAI's [*Designing AI agents to resist prompt injection*](https://openai.com/index/designing-agents-to-resist-prompt-injection/).

**Industry reports / capability evals.**
- [DORA 2024 *Accelerate State of DevOps*](https://dora.dev/research/2024/dora-report/) — AI adoption correlates with +productivity but −1.5% throughput and −7.2% delivery stability; small batch sizes and robust testing remain crucial.
- [METR *Early-2025 AI on Experienced OSS Developers*](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/) — 19% slowdown despite perceived 20% speedup, in large unfamiliar codebases.
- [GitHub Octoverse 2025](https://github.blog/news-insights/octoverse/octoverse-a-new-developer-joins-github-every-second-as-ai-leads-typescript-to-1/) — Copilot coding agent authored 1M+ PRs in 5 months; TypeScript overtook Python (typed-language premium under agents).

**Deliberately excluded.**

- *Test coverage percentage.* Coverage is a vanity metric; agents care that tests **run fast, fail loud, and are trivially invocable** — not that they touch 90% of lines. (Willison emphasizes runnability, not coverage; Anthropic's Claude Code best practices similarly stress TDD as a *workflow*, not a coverage ratio.)
- *Lines of code, file count, repo age, star count, commit cadence.* Vanity signals that don't predict agent productivity. A 5000-line file with clear sections is fine; a 200-line file that imports half the codebase is not.
- *Presence of a LICENSE, CODE_OF_CONDUCT, or pretty README.* Human-facing hygiene, not agent-facing.
- *Monorepo vs. polyrepo* as a global verdict. Each architecture has agent-friendly and agent-hostile variants; we grade the *symptoms* (cross-cutting changes, dependency clarity, boundary discipline) not the shape. Graphite's [polyglot-monorepo guide](https://graphite.com/guides/managing-multiple-languages-in-a-monorepo) makes the same case for language mixing.
- *Documentation volume.* Willison: "LLMs can read code faster than humans … comprehensive documentation is useful for humans, less helpful for coding agents." We grade *runnable* docs (commands that work) and *triggering* docs (CLAUDE.md / AGENTS.md), not narrative prose.

**Bias to mechanical signals.** Where a signal can be measured by a shell command, we write the command. Judgment signals are kept to a strict minority (§5) so the skill stays auditable. Fitness-function framing (Ford & Parsons) supports this: every dimension should ideally be enforceable by a passing/failing check.

## 3. Dimensions

Ten dimensions in v2 (was 8), weights sum to 100%. Each dimension has signals (with measurement), an anti-signal list, and a rationale tied to a specific agent failure mode. The two new dimensions (D9 Token-economy / context efficiency, D10 Agent-vantage security & runtime observability) absorbed signals that were previously scattered across D3, D5, and D7. Existing weights were re-balanced accordingly (see §9).

---

### D1. Onboarding context (13%)

**Definition.** Can the agent learn the project from a cold start using only files in the repo — no oral tradition, no Slack, no "ask the team."

**Why for agents specifically.** Agents have no continuity between sessions (HumanLayer 12-Factor §5, §12: stateless reducers; harness principle §39 on re-injection). A human absorbs tribal knowledge over weeks; the agent gets one shot per session. The CLAUDE.md / AGENTS.md pattern exists precisely because [GitHub's analysis of 2,500+ repos](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/) found this is the single highest-leverage file: "provide your agent a specific job or persona, exact commands to run, well-defined boundaries, and clear examples." OpenAI's [Codex AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md) and Roo Code's [adoption discussion](https://github.com/RooCodeInc/Roo-Code/issues/5966) corroborate from the other side: AGENTS.md is now the cross-tool standard, loaded by Codex, Cursor, Cline, Roo Code, Aider, and Continue.dev. Cognition's [DeepWiki](https://cognition.ai/blog/deepwiki) goes further — Devin auto-indexes repos into wikis with architecture diagrams; a `.devin/wiki.json` lets the user steer the generation, suggesting that even pre-built doc-generation tools want a small seed file in the repo.

**Plain-English case.** A new engineer joining your team gets a Slack channel, a coffee, and a few days of pairing before they ship. An agent gets one file. Without an AGENTS.md / CLAUDE.md, every session starts from zero — the agent guesses commands, guesses directory conventions, and writes code that an unaided human would have known not to write. The cost isn't theoretical; you pay it on every task.

**Common objections.**

| Objection | Honest response |
|---|---|
| "Our team isn't using agents yet." | Fair — and AGENTS.md is a 50-line file. Cline, Cursor, Codex, Aider, Continue, and Roo Code all read it; once you have one, every tool your team tries works better with zero per-tool config. Cost of writing it: a couple of hours, front-loaded. Cost of not: paid every session, by every tool, forever. |
| "Our README already covers this." | Most don't — READMEs are for humans landing on GitHub (narrative, why-we-exist). AGENTS.md is for the first 200 lines of an agent's session (copy-pasteable commands, "don't touch `legacy/`" rules). If your README is genuinely both, symlinking `AGENTS.md → README.md` is a perfectly valid pass on this dimension. |
| "We have an internal wiki." | The agent can't read it. If commands live in Notion or Confluence, the session starts with the agent guessing — or worse, running stale ones it cached from training data. |

**Cost of leaving this alone.** Conservatively, a cold agent session burns 10–30k tokens (~$0.03–$0.09 at Sonnet input rates ~$3/M) just orienting itself before the first real edit. That's small. The bigger cost is degraded output: the agent runs `npm test` when you use `pnpm test`, treats the resulting error as a code issue rather than a tooling issue, and you spend 20 minutes reviewing a wrong-shaped PR. At 50 agent-assisted PRs/month, even a 10% rate of these mismatches costs you ~10 review-hours.

**Presence is not the signal — *liveness* is.** A context doc that exists, is well-formatted, and is 18 months stale is *worse than nothing*: it misleads every session confidently. The signals below are split into **presence** (necessary, cheap to fake) and **liveness** (the part that actually predicts agent success). A dimension cannot score above C on presence alone — the liveness probes must pass. **Follow references:** if `CLAUDE.md`/`AGENTS.md` points at another file or folder (e.g. a `.ai/`, `docs/agent/`, or `.cursor/rules/` directory), the referenced content *is* the onboarding context and is graded here — including its freshness. Checking the pointer exists is not enough; read what it points to.

**Presence signals (necessary, not sufficient).**

| Signal | Measurement |
|---|---|
| `AGENTS.md` or `CLAUDE.md` at repo root | `test -f AGENTS.md \|\| test -f CLAUDE.md` |
| File covers Commands / Testing / Project structure / Code style / Git workflow / Boundaries | grep for section headers; GitHub recommends [these six core areas](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/) |
| Length 50–500 lines (not empty, not a novel) | `wc -l` — over ~2 screens the middle gets ignored (`claude-md-template.md`); Cursor's rules guide separately caps at 500 lines |
| Hierarchical agent docs in major subdirs (monorepo case) | `find . -name AGENTS.md -o -name CLAUDE.md` returns >1 in deep workspaces |
| Commands are copy-pasteable (real flags, no `<your-project>` placeholders) | run a sample; `grep -E '<[a-z-]+>'` |
| README "Quickstart" ends in a runnable command in <10 lines | judgment + grep |
| If the project ships an OpenAPI / GraphQL / protobuf contract, it is in the repo (not an external Confluence) | `find . -name 'openapi*.{yaml,yml,json}' -o -name '*.proto' -o -name 'schema.graphql'` |

**Liveness probes (required to score above C — these are *run*, not assumed).**

| Probe | Measurement |
|---|---|
| **Accuracy** — pull 3–5 concrete claims from the doc (a command, a directory path, a named helper/convention) and verify each against the repo | run the cited command (dry-run/`--help`); `test -e` the cited paths; grep the cited symbols. A doc where ≥1 of 3 sampled claims is false is *misleading*, not merely incomplete |
| **Freshness** — context doc not materially staler than the code it describes | compare `git log -1 --format=%cr` on the context doc(s) (and followed references) against median commit age of the top-churn source dirs (`git log --since='6 months ago' --name-only`). Doc untouched while its subject churned heavily = stale |
| **Feedback loop** — a mechanism exists to keep context current | look for a learnings dir (`docs/learnings/`, `.ai/learnings/`), dated entries in the context doc, a `/learn`-style capture skill, or "update this file when…" instructions. Absence means the doc will rot silently between grades |

**Weight justification (13%, was 15%).** Still the highest-leverage single artifact for cold-start sessions, but we shaved 2 points to fund D9 (token economy) — Augment's [token-cost analysis](https://www.augmentcode.com/guides/ai-agent-loop-token-cost-context-constraints) shows that even a perfect AGENTS.md is wasted if the rest of the repo bloats the context window. Cross-vendor support: AGENTS.md is recognised by Claude Code, Codex, Cursor, Cline, Roo Code, Aider, Continue.dev, JetBrains Junie (via MCP context), and GitHub Spec Kit's 29 integrations.

**Anti-signals.** A 100-page README. A wiki link with no content in the repo. Aspirational instructions ("we plan to add tests"). Generic AGENTS.md copy-pasted from a template with no project content (GitHub's analysis explicitly flags this as worse than nothing). Commands written as prose rather than code blocks. A `.cursorrules` / `CLAUDE.md` / `AGENTS.md` that contradicts one of its siblings. **A doc that references a folder of context (`.ai/`, `docs/agent/`) untouched for months while the code churned — present, plausible, and stale.** Cited commands that error or cite flags that no longer exist. No learnings/feedback mechanism, so nobody will notice when the doc drifts.

---

### D2. Build/test/lint loop (18%)

**Definition.** Can the agent run the project, exercise it, lint it, and get fast honest feedback — with **one command each**.

**Why for agents specifically.** This is the agent's verification loop. Without it the agent falls back to claiming success without evidence (harness principle §33). Willison: "Linters, type checkers, auto-formatters — give coding agents helpful tools to run and they'll use them." [Augment's harness engineering writeup](https://www.augmentcode.com/guides/harness-engineering-ai-coding-agents) and Böckeler's [*Harness engineering and agent feedback*](https://www.thoughtworks.com/en-au/insights/blog/generative-ai/harness-engineering-agent-feedback-exploring-ai-coding-sensors) both frame these tools as "sensors" — without sensors the agent guesses. [Cognition's Devin-on-Devin post](https://cognition.ai/blog/how-cognition-uses-devin-to-build-devin) credits tightening these gates as a top driver of throughput gains. The [SWE-agent ACI paper](https://arxiv.org/abs/2405.15793) makes the same point at the interface level: agents that get fast, bounded tool feedback solve 5× more SWE-bench tasks than agents using a raw shell. Crawshaw's [sketch.dev posts](https://crawshaw.io/blog/programming-with-agents) confirm: "compiler feedback reduces syntax errors and hallucinated interfaces" — an order-of-magnitude effect.

**Plain-English case.** Every iteration where the agent can't verify its work is an iteration where it guesses, claims success, and ships a regression. The test loop is the agent's only honest source of "did this work?" — if it takes 4 minutes or requires manual setup, the agent will skip it, narrate confidence, and you'll catch the bug in review (or production). One-command, fast, exit-coded feedback is the difference between agents that compound and agents that backslide.

**Common objections.**

| Objection | Honest response |
|---|---|
| "Our tests are slow because integration matters." | Real integration matters. The fix isn't "don't have integration tests" — it's: (a) separate a fast unit tier (<30s) the agent runs every iteration from the slow integration tier it runs once before PR, (b) parallelise the slow tier, (c) containerise infra so it boots from cold in <60s. DORA 2024's small-batch finding applies here: agents amplify the cost of slow loops; they don't change the underlying math. |
| "We don't have a single test command — different services have different runners." | That's the cost. Add a top-level `make test` / `pnpm test` that runs each service's command; budget two hours for the script. The alternative is that every agent session has to learn the matrix afresh and gets it wrong half the time. |
| "Strict lint config slows our team down." | Loose lint costs more than strict, with agents — every PR re-introduces five style variants and review burns on cosmetic comments. The fix is to bias strict + autofix on save, so humans pay the friction once at write-time and agents inherit consistency for free. |

**Cost of leaving this alone.** Token math: agents typically run 3–5 iterations per task. A 4-minute test suite × ~200k cumulative tokens/iteration × $3/M input ≈ $0.60–$1.00 per failed iteration in tokens alone, plus wall-clock. A 30s suite is ~10× cheaper and 8× faster. The bigger cost is silent: when the loop is slow, agents skip it and ship work they didn't verify. SWE-agent's 5× SWE-bench gain from improved interface feedback is the empirical anchor — fast honest feedback is the largest single intervention you can make in an agent's working environment.

**Signals.**

| Signal | Measurement |
|---|---|
| One-command install on clean checkout | run it; exit 0 in <5 min |
| One-command test exists and runs | `npm test` / `pytest` / `cargo test` / `make test` |
| Unit test suite finishes in <60s (target <30s) | `time` it; slow tests train the agent to skip them |
| Lint/format/typecheck single command, <30s | `npm run lint`, `ruff check`, `tsc --noEmit` |
| CI runs the same commands the agent runs locally | inspect the detected CI config (any of GitHub Actions, GitLab CI, CircleCI, Buildkite, Jenkins, Drone, Azure Pipelines — see grader discovery preamble); compare with AGENTS.md |
| Test failures include enough context to act on without re-running | sample; Willison: "stuffing extra data in the assertion is inexpensive" |
| Pre-commit hooks fail loud (don't silently auto-fix) | `.pre-commit-config.yaml` / `.husky` |
| Dev-server reload / incremental compile <5s for typical edit | judgment + sample |

**Weight justification (18%, unchanged).** Still the single biggest determinant. DORA 2024 explicitly notes that "small batch sizes and robust testing remain crucial" under AI adoption, and the −7.2% delivery-stability drop they observed is exactly what happens when the test loop is too slow or too vague for an agent to use as ground truth.

**Anti-signals.** Tests requiring manual setup (start a DB, set env vars, log into VPN) with no documented one-liner. Tests that pass when code is broken (no assertions). A 10-minute test suite. Lint config so strict the agent spends every iteration fighting style — or so absent it writes in five styles. A `--watch` mode that exists for humans but no one-shot command for agents (the agent needs an exit code, not a TUI).

---

### D3. Code navigability & locality (14%)

**Definition.** Can the agent locate symbols, follow types, and change one thing without secret coupling pulling in five others.

**Why for agents specifically.** [SWE-Bench Pro's trajectory analysis](https://arxiv.org/abs/2509.16941) found that even strong models fail predominantly on "navigating large, unfamiliar codebases" and "high-precision edits across multiple files" — and the gap between the public benchmark (~43%) and the commercial set (<20%) is largely a navigation gap. Aider's [repo-map design](https://aider.chat/docs/repomap.html) and AutoCodeRover's [AST-aware retrieval](https://arxiv.org/pdf/2404.05427) both treat code locality as a first-class retrieval problem — code connected by call edges gets included together. Augment's [Context Engine](https://workos.com/blog/augment-code-context-is-the-new-compiler) and Sourcegraph's [Cody indexing](https://sourcegraph.com/blog/how-cody-understands-your-codebase) make the same bet from the retrieval side; the codebase wants to be cleanly chunkable. GitHub's [Octoverse 2025](https://github.blog/news-insights/octoverse/octoverse-a-new-developer-joins-github-every-second-as-ai-leads-typescript-to-1/) finding — TypeScript overtaking Python on GitHub, attributed to "developers shifting toward typed languages that make agent-assisted coding more reliable" — is the field-scale signal for the typed-language signal below.

**Plain-English case.** Every change the agent makes loads context — files, types, callers. When that context is locally contained and types are honest, the agent edits one folder, runs the loop, ships. When it's spread across five directories with implicit cross-file globals and dynamic dispatch, the agent loads half the repo, runs out of useful context, and starts guessing at function signatures. Locality is what keeps the agent's window full of *relevant* code instead of speculative breadcrumbs.

**Common objections.**

| Objection | Honest response |
|---|---|
| "Indexing tools (Sourcegraph, Augment, Cody) solve this already." | They help — but the SWE-Bench Pro enterprise gap (43% public → <20% commercial) is largely a navigation gap on repos that *do* have indexing. Indexing surfaces candidates; locality determines whether editing one of them is a single-file change or a 12-file change. Augment's Context Engine and Aider's repo-map both work better on locality-disciplined repos; they don't replace the discipline. |
| "Strict types add prototype friction." | Yes — for genuine prototypes (`experiments/`, throwaway scripts), this dimension legitimately doesn't apply, and the rubric explicitly says scope-appropriate caveats are valid. For anything that lives past a quarter, the Octoverse field signal is direct: TypeScript adoption is rising specifically because typed languages give agents the schema they need to write correct code on the first try. |
| "We have 5000-line files but they're well-organised internally." | A 5000-line file with clean sections is fine — the rubric explicitly says so. The signal flags files >1000 lines because *most* of them aren't well-organised, not because length itself is the problem. If yours genuinely is, the judgment sample will catch it and you get the points back. |

**Cost of leaving this alone.** Hard to put a token cost on directly; it shows up as multi-file PRs that take 5 review-rounds instead of 1, and as agent attempts that abandon halfway because the context window fills with the wrong files. The empirical anchor is SWE-Bench Pro: even frontier models lose 20+ percentage points on enterprise codebases vs. the public benchmark, with "navigating large unfamiliar codebases" cited as the dominant failure mode. If your repo is in that category, the agent's success rate on non-trivial tasks halves, regardless of model quality.

**Signals.**

| Signal | Measurement |
|---|---|
| Statically-typed language, or strict type checker on (TypeScript strict, mypy strict, Sorbet, Pyright strict) | `tsconfig.json` `"strict": true`; mypy strict config |
| Symbol search returns one definition for ~unique names | sample 5 functions; `grep -rn "def foo\b"` ≤2 sites |
| Module/feature folders are colocated (one feature = one folder, not split by tech layer across 5 dirs) | tree inspection; judgment |
| Average file <600 lines | `find . -name '*.ts' \| xargs wc -l \| awk '$1>1000'` |
| Imports explicit (no wildcards, no auto-loaders) | `grep -rE 'from .* import \*'` ~0 |
| Public API boundaries surfaced (`__all__`, barrel `index.ts`, explicit re-exports) | inspection |
| Names are honest: `validate_email` validates email | judgment; sampled |
| Architectural rules encoded as a linter (folded from D4 — these are also a navigation aid) | `dependency-cruiser` / `import-linter` / Nx module-boundary rules |

**Weight justification (14%, was 15%).** Shaved 1 point because the architecture-rule signal moved into D3's measurable set rather than D4's gates. SWE-Bench Pro's enterprise-set gap is the single strongest piece of evidence we have for D3's importance; if anything 14% may be light.

**Anti-signals.** Dynamic dispatch / DI containers without compile-time guarantees. Generated code with no clear regeneration command (cf. D8). "God objects." Same name used for 4 different things. Heavy metaclass/decorator/AST manipulation that hides control flow. Implicit cross-file globals. Three different ORMs in one tree (Augment specifically calls this out for [polyglot monorepos](https://www.augmentcode.com/tools/monorepo-vs-multi-repo-ai-architecture-based-ai-tool-selection)).

---

### D4. Deterministic mechanical gates (11%)

**Definition.** Non-model gates that catch the agent's specific failure modes — drift, hallucination, style violations, half-done work.

**Why for agents specifically.** Forcing functions beat guidance (harness principle §2). The harness's `pre-deploy`, `tdd`, `verification-before-completion` skills exist because the model alone won't self-impose them. The codebase needs the same. [Phoebe](https://www.phoebe.work/blog/enforcing-architecture-in-an-agent-driven-codebase): "What can be inferred from the codebase should be handled by the Context Engine; rules files are reserved for what cannot be inferred." For everything else, ship enforcement. This is precisely Ford & Parsons's [fitness-function](https://nealford.com/books/buildingevolutionaryarchitectures.html) framing — an objective architectural integrity check, run in CI, that fails loudly when drift occurs. DORA 2024's finding (39% of respondents distrust AI-generated code) underwrites the urgency: gates are how trust is rebuilt mechanically.

**Plain-English case.** Code review doesn't scale to agent-generated PR volume. If a tireless agent can open 20 PRs/day, your reviewers can't be the only thing standing between drift and main. Anything mechanically enforceable — formatter, type-check, lint, architectural rules, secret scan — needs to be a CI gate that fails the build. That's not paranoia; it's the only way trust holds up under the new throughput.

**Common objections.**

| Objection | Honest response |
|---|---|
| "We trust our team to follow conventions." | Maybe — but agents aren't your team. They follow the conventions they can *see in code or CI*, and ignore conventions that exist only in tribal knowledge. The DORA 2024 stability drop (−7.2%) under AI adoption is the field signal: undocumented norms degrade fastest under high-velocity output. Gates encode the norms agents (and rushed humans) skip. |
| "Strict gates slow us down." | They slow you down at write-time and save you 5× at review-time. Agents amplify this asymmetry: a `--max-warnings 0` lint catches 100 trivial nits before review, which is exactly what you don't want a human spending review attention on. Reviewers should be reviewing logic, not whitespace. |
| "We have CI already." | Many "CI" setups are advisory — `continue-on-error: true`, warnings-as-suggestions, jobs marked `[skip ci]` routinely. The signal here is specifically *gates that fail the build*. If your existing CI is honest, you're already passing; if it has `continue-on-error` on the type check, the agent will exploit it (not maliciously — it just sees a green check and ships). |

**Cost of leaving this alone.** Cost shows up in review hours, not tokens. A repo without gates incurs ~5–20 minutes of nit review per PR (formatting, import order, type-narrowing, unused exports) that the gates would have caught in 2 seconds of CI. At 20 PRs/week × 10 minutes × 4 weeks = ~13 review-hours/month spent on cosmetic comments instead of architecture. With agent-generated PRs that ratio gets worse: the agent has no muscle memory for your conventions, so every nit reappears unless the gate enforces it.

**Signals.**

| Signal | Measurement |
|---|---|
| Formatter runs in CI in `--check` mode and fails the build | grep CI config |
| Type check is a hard gate in CI | grep CI for `tsc`, `mypy`, `cargo check` |
| Lint warnings cap (`--max-warnings 0` or equivalent) | grep |
| Schema/migration validation is a gate (Prisma diff, Alembic, sqlc) — Prisma now ships [explicit AI safety checks](https://www.prisma.io/docs/orm/prisma-client/deployment/deploy-database-changes-with-prisma-migrate) for agent workflows | inspection |
| Secrets scanner on (gitleaks, trufflehog, forge-native secret scanning) | `.gitleaks.toml`, `.trufflehog.yaml`, `.secrets.baseline`, or a secret-scan job in the detected CI config |
| `git status` clean after a successful build (no untracked generated leakage) | run build, diff |
| Pre-merge contract diff: spec/OpenAPI/protobuf is the source of truth, drift fails CI (cf. [GitHub Spec Kit](https://github.com/topics/spec-driven-development) / Specmatic) | grep CI |

**Weight justification (11%, was 12%).** Architecture-rule linters moved to D3 (where they more naturally measure navigability). 11% reflects that gates are necessary but not sufficient — the test loop (D2) catches most of what a missing gate would miss. For high-velocity agent work (many PRs/day) gates remain the difference between net-positive and net-negative productivity. DORA 2024's reported delivery-stability drop (−7.2%) under AI adoption is the empirical case for keeping this weight non-trivial.

**Anti-signals.** "Warnings as suggestions." Project-wide `eslint-disable`. CI checks with `continue-on-error: true`. A formatter installed but not enforced. Pre-commit hooks that auto-fix but never fail — agents silently bypass them. A migration tool installed but no CI step that validates schema drift (Prisma users specifically: not running `prisma migrate diff` in CI).

---

### D5. Failure honesty (9%)

**Definition.** When something breaks, the codebase says what broke, where, and why. Errors are loud, specific, and reproducible.

**Why for agents specifically.** Willison: "If a manual or automated test fails the more information you can return back to the model the better." Harness principle §6 (Fail Loud): silent failures are future incidents; for agents they're also debugging dead-ends — the agent re-runs, sees the same vague output, and either guesses or claims success. [SWE-EVO's failure analysis](https://arxiv.org/pdf/2512.18470) identifies "swallowed errors" and "generic exception handlers" as top reasons agents fail to converge on a fix. Kent Beck reinforces this from the other side: ["AI genies are astonishingly bad at safe sequencing"](https://tidyfirst.substack.com/p/exploring-ai) — they need every step to surface its own success/failure or they cascade. The "what to include" piece moved into D10 (the structured-logging signal there overlaps with D5; this dimension is now strictly about error-site honesty).

**Plain-English case.** Errors are the agent's debugging surface. When `catch (e) { return null }` swallows the actual failure, the agent re-runs, sees the same vague "returned null" result, and either guesses or claims success. Honest errors — specific identifiers (which user, which file), stack traces preserved across boundaries, structured details — are what turn a failed iteration into a useful one. Without them every bug looks like the same generic "didn't work."

**Common objections.**

| Objection | Honest response |
|---|---|
| "Generic catches are defensive — they prevent crashes." | They also prevent diagnosis. The defensive-programming case is real for *some* boundaries (top-level request handlers, queue consumers) where you genuinely want a fallback. The problem is when every internal function catches everything and returns `null` — the original error vanishes, and every downstream layer makes decisions on `null` instead of failing fast. SWE-EVO's failure analysis cites "swallowed errors and generic exception handlers" as a top reason agents fail to converge on a fix. |
| "We log errors to Sentry, that's enough." | Sentry catches what reaches it. A `catch { return null }` in your code path never reaches Sentry — it just silently degrades behaviour. The signal here is that errors at the *source* carry enough context to act on, not that telemetry exists at the edge. |
| "Adding identifiers to error messages is busywork." | One-time busywork. The payoff is multiplied across every future debug session — agent or human. The cheapest version: a project-wide error wrapper (`errors.Wrap(err, "loading user %d", id)`) added at boundaries; an afternoon of work for a permanent debugging speedup. |

**Cost of leaving this alone.** Cost is paid in time-to-diagnose, not tokens. When agents debug a vague failure, they typically run 2–3 extra iterations probing for context — 6–12k extra tokens each, plus the wall-clock cost of the longer loop. On a flaky-error-prone codebase, ~30–50% of agent iterations are spent on diagnosis rather than fix. The human version: a 20-minute Sentry-archaeology session for what should have been a 2-minute glance at a stack trace with the user_id attached.

**Signals.**

| Signal | Measurement |
|---|---|
| No bare `except:` / `catch (_)` / `catch (e) {}` blocks | `grep -rnE 'except:\|catch \(\)\|catch \(_\)'` ≈ 0 |
| Errors include identifiers (which user, which file, which row), not just types | sample; judgment |
| Test assertions include messages, expected/actual diffs, repro hints | sample 10 tests |
| Stack traces survive boundaries (`raise X from e`, `errors.Wrap`, error wrapping) | grep |
| Reproducible bug-report format (issue template, or `--debug` flag dumping env+versions) | inspection |

**Weight justification (9%, was 10%).** 1 point migrated to D10 where structured logging lives; failure-honesty here is now strictly about authored error sites, not runtime telemetry. Critical but not high-leverage at the rubric level — the failure-honesty payoff compounds inside D2 (the loop) and D3 (debugging). 9% is still enough to penalize codebases that swallow exceptions.

**Anti-signals.** Sentry tags as the only error context. `console.log("error")` with no detail. `try { … } catch { return null }`. Defaulting to empty string instead of throwing on missing config. Errors logged but not raised (loses stack trace).

---

### D6. Reproducibility & environment hermeticity (7%)

**Definition.** Can the agent get to a working environment from a clean machine, deterministically, and rerun a failure?

**Why for agents specifically.** Agents (Devin, OpenHands, sandboxed Claude Code, Codex cloud, Replit Agent) operate in fresh containers constantly. Hermeticity isn't a luxury — it's the precondition for autonomous operation. Replit's [Agent docs](https://docs.replit.com/replitai/agent) make this concrete: the filesystem is ephemeral and resets on every publish. [Cognition's Devin-on-Devin post](https://cognition.ai/blog/how-cognition-uses-devin-to-build-devin) cites environment-setup investment as one of the highest-leverage things they did to their own codebase. OpenHands's [ICLR 2025 paper](https://arxiv.org/pdf/2407.16741) builds the whole runtime on the "arbitrary Docker image + injected execution API" pattern — a codebase that can't be containerised cleanly can't be agented at all. The [12-Factor App](https://12factor.net/) (dependencies, config, dev/prod parity), [Bazel hermeticity](https://bazel.build/basics/hermeticity), and [reproducible-builds.org](https://reproducible-builds.org/) are the upstream theoretical sources.

**Plain-English case.** Cloud agents — Devin, Codex cloud, sandboxed Claude Code, Replit Agent — boot a fresh container every session. If your repo needs a 3-step manual setup (install Postgres locally, edit `.env`, run a seed script), the agent can't do it. The bar isn't "perfect Bazel hermeticity"; it's "fresh `git clone` → one command → working environment in under 5 minutes." Below that bar, autonomous agents can't run at all, and human onboarding stays slow.

**Common objections.**

| Objection | Honest response |
|---|---|
| "We're not Google, we don't need Bazel." | Agreed — Bazel is overkill for most repos. The signal here is a *lockfile + a runnable container* (`docker-compose up` or a `devcontainer.json`), not full hermetic build graphs. Most teams pass this dimension with `package-lock.json` + a Dockerfile + a `make dev` target. The bar is "fresh agent boots into working env" not "byte-reproducible builds." |
| "Our setup is documented in the README." | Documentation is necessary but not sufficient — the agent (and new humans) follow the doc, hit an error on step 4, and stall. The signal here is *executable* setup: a script the agent can run, error and all, instead of prose it has to interpret. If the README says "install Postgres 14," that's prose; if it says `./scripts/setup.sh`, that's a tool the agent can use and fail loudly with. |
| "We can't containerise our prod stack — it depends on AWS." | Local dev doesn't need prod parity — it needs *something* the agent can boot. LocalStack, MinIO, or a `testcontainers` recipe gives the agent a runnable sandbox. The signal isn't "reproduces prod"; it's "boots from cold without manual steps." |

**Cost of leaving this alone.** Hard cost: cloud agents (Devin, Codex cloud) simply can't operate on the repo at all — the engineering team is locked out of an entire class of tooling. Soft cost: every new hire loses 0.5–2 days to environment setup, which compounds as Postgres/Redis/Node versions drift on individual machines and "works on my laptop" bugs proliferate. The Cognition Devin-on-Devin post cites environment-setup investment as one of their highest-leverage internal projects; their team-of-engineers-using-agents pattern fundamentally requires this dimension.

**Signals.**

| Signal | Measurement |
|---|---|
| Pinned dependency versions (lockfile committed) | `test -f package-lock.json \|\| yarn.lock \|\| pnpm-lock.yaml \|\| poetry.lock \|\| uv.lock \|\| Cargo.lock \|\| go.sum` |
| Runtime version pinned | `.nvmrc`, `.python-version`, `rust-toolchain.toml`, `go.mod` go directive |
| Container or devcontainer config | `Dockerfile`, `.devcontainer/`, `flake.nix` |
| `.env.example` is the only env onboarding step | `test -f .env.example` |
| One command boots databases/queues/infra | `docker compose up`, `make dev-up` |
| Build is bit-reproducible OR hermeticity equivalent (Bazel/Nix), or repo has a stated reproducibility target | inspection |
| No "ask Bob for the API key" instructions | grep for personal names in setup docs |

**Weight justification (7%, was 8%).** Lockfile + container has become near-table-stakes — the marginal weight here is lower than it was a year ago because most production repos already pass. 1 point migrated to D9. A pinned lockfile is necessary but rarely sufficient; environment broken is a binary disqualifier for autonomous agents but rarely the *only* problem.

**Anti-signals.** "Works with Node 14 or 18 or 20." Unpinned `latest` Docker base images. Secret-manager dependencies that can't be stubbed for tests. Floating-point dependency on the developer's local Postgres. Setup scripts that assume macOS. Required services (Stripe, Auth0, S3) with no local sandbox/mock.

---

### D7. Change-safety affordances (11%)

**Definition.** Can the agent make a change, prove it didn't break anything, and recover when it does — with mechanisms the codebase provides rather than ones the agent invents?

**Why for agents specifically.** Hashimoto's Ghostty pattern: ["over-aggressively create commits"](https://zed.dev/blog/agentic-engineering-with-mitchell-hashimoto) so the agent has cheap rollback. Harness principle §30 (bite-sized tasks) + §32 (user review gates). Agents thrash without checkpoints; with them they self-bound. Karpathy's "Surgical Changes" principle in [CLAUDE.md](https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md) — the agent needs to know where the blast radius ends. Kent Beck's [augmented-coding posts](https://tidyfirst.substack.com/p/augmented-coding-beyond-the-vibes) frame the same observation as "small safe reversible changes" being the load-bearing discipline. The [trunk-based development](https://trunkbaseddevelopment.com/) literature provides the team-level analogue: small PRs, branch protection, merge queues — all of which become more important, not less, when an agent is generating PRs at scale (Octoverse 2025: 1M+ Copilot-agent PRs in 5 months). Spec-driven dev (GitHub Spec Kit, Specmatic, OpenSpec) is the proactive form: spec-first contracts give the agent a target before it writes code.

**Plain-English case.** Agents make mistakes — confidently, frequently, in volume. Whether the agent is net-positive depends on how cheap it is to *undo* each mistake. Frequent commits, small PRs, feature flags, branch protection, and migration safety all do the same job: bound the blast radius so that an agent's wrong turn costs minutes, not hours. Without these affordances every agent task is a high-stakes gamble; with them, agents compound.

**Common objections.**

| Objection | Honest response |
|---|---|
| "Smaller PRs slow throughput." | Empirically the opposite — the trunk-based-development literature has 15+ years of data showing small PRs ship faster because review cost drops super-linearly with diff size. With agents the asymmetry sharpens: a 400-line agent-generated PR is unreviewable in any honest sense, so it either gets rubber-stamped (drift) or sits forever (waste). 30–80 line PRs are reviewable in minutes. |
| "Feature flags add complexity." | Yes — and the alternative for agent-generated work is shipping unhedged. Pair flags with a removal SLA (e.g., delete after 14 days at 100% rollout) and the maintenance burden stays bounded. That's discipline mature teams already practice; agents don't change the rule. |
| "ADRs are overhead for our team size." | For a 3-person team in week 1, agreed — skip them. For a 10+ person team or a codebase older than a year, the agent (and new humans) regularly re-decide questions you already settled, badly, because the rationale isn't in the repo. A single `docs/adr/0001-why-postgres.md` is enough to start; the adr.github.io movement's central finding is that discoverability is the operational backbone of decisions. |

**Cost of leaving this alone.** The dominant cost is "wrong-turn cost" — wall-clock time from realising an agent change broke something to having it reverted. With small commits + branch protection + cheap rollback: ~5 minutes (revert a commit, agent retries). Without: 30–120 minutes manually unpicking a sprawling diff while production is degraded. Multiply by frequency of wrong turns (currently 5–20% of agent attempts depending on task complexity) and the math becomes obvious. Octoverse 2025's "1M+ Copilot-agent PRs in 5 months" makes this concrete: at that throughput, the cost of each wrong turn matters operationally, not just theoretically.

**Signals.**

| Signal | Measurement |
|---|---|
| Feature flags / gates for in-progress work | grep for a flag library (`unleash`, `launchdarkly`, `posthog`, `OpenFeature`) or convention |
| Migrations are atomic with rollback (or forward-only with documented backfill) | `find migrations -name '*down*'` or inspection |
| Branch protection on `main`/`master`/`trunk` (CI must pass, no force push) | forge-appropriate CLI — `gh api ...branches/<default>/protection`, `glab api projects/:id/protected_branches`, `tea repos branches protections list`; "not measured" if no CLI available |
| Snapshot / visual-regression tests for stable-output surfaces (Storybook + Chromatic, jest snapshots, image-diff) | `find . -name '*.snap' -o -name '__snapshots__' -o -name 'chromatic*'` |
| Contracts/types at I/O boundaries (OpenAPI, GraphQL, protobuf, zod, pydantic); the codebase has a "spec is source of truth" stance, not "code is" | file existence + grep for codegen step |
| Commits small and rebaseable (median <300 LOC over recent 50 commits) | `git log --shortstat -50` + awk |
| `git bisect` works (no flaky-by-time tests, no time-bombs) | judgment |
| ADRs / decision records colocated in the repo, not in Confluence | `find docs -name 'adr-*' -o -name '*.adr.md' -o -path '*/decisions/*'` |

**Weight justification (11%, was 12%).** 1 point migrated to D9. Still directly governs the cost of an agent's wrong turn. A codebase where each agent mistake costs an hour to undo is one where agents are a liability; where each costs 30 seconds, agents compound. The ADR signal is new (per the [adr.github.io](https://adr.github.io/) movement's "discoverability is the operational backbone" finding) — ADRs in the repo work as just-in-time context the agent can read at decision time. The spec-driven signal moved here from D4 because contracts are change-safety devices first, gates second.

**Anti-signals.** Long-lived feature branches drifting for weeks. Manual migration steps in production. PRs requiring 5 reviewers. No way to deploy a small thing without a release train. Tests that depend on time/network/random without seeding. ADRs in a Confluence space the agent can't read.

---

### D8. Conventions discoverable from code, not lore (8%)

**Definition.** When the agent needs to know "how do we do X here?" it can find the answer by reading the codebase, not by being told.

**Why for agents specifically.** Willison: "even having just one or two tests in the style you like means agents will write tests in the style you like. There's a lot to be said for keeping your codebase high quality because the agent will then add to it in a high quality way." [Cursor's rules docs](https://cursor.com/docs/rules) and [Phoebe's writeup](https://www.phoebe.work/blog/enforcing-architecture-in-an-agent-driven-codebase) converge on: "What can be inferred from the codebase should be handled by the Context Engine; rules files are reserved for what cannot be inferred." Agents pattern-match; if the codebase contains one canonical example of every pattern, the agent reproduces it. Sourcegraph's [Cody indexing](https://sourcegraph.com/blog/how-cody-understands-your-codebase) and Augment's [Context Engine](https://workos.com/blog/augment-code-context-is-the-new-compiler) confirm from the retrieval side: their retrieval systems reward repos with one good example over repos with five inconsistent ones. Karpathy's [hypertrophy](https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md) observation gives the drift case: agents accelerate convention erosion just as fast as they accelerate convention adoption — so conventions must be exemplified *and* enforced.

**Signals.**

| Signal | Measurement |
|---|---|
| Canonical example of each common operation (one feature endpoint, one CRUD slice, one job) the agent can clone | inspection |
| Consistent naming visible from `ls` (one casing for files, one for symbols) | sample; ratio of dominant casing |
| Tests live alongside code, or in a 1:1 mirror directory | `find` for `_test.{js,ts,py,go}` adjacent to source |
| Config centralized (one `config/`, one `settings.py`, not 30 scattered env reads) | grep env reads; should cluster |
| Common operations (logging, error wrapping, db access) go through one helper, not 5 | judgment + grep |
| Generated code clearly marked (`// CODE GENERATED — DO NOT EDIT`) and has a documented regenerate command | grep header strings; `find` for codegen scripts |
| A "where new code goes" answer is obvious from the tree | inspection |

**Weight justification (8%, was 10%).** Shaved 2 points to fund D9 and D10. Still the dimension that compounds: a well-conventioned codebase compounds *with* agent contributions; a poorly-conventioned one entropies *faster* with them. Effects show up over weeks, not minutes — which is why we don't weight it higher than D1/D2/D3. The generated-code signal is new — Karpathy and the Suparbase ["type-safety as load-bearing"](https://suparbase.com/blog/type-safe-database-for-ai-paired-code) post both stress that AI-paired codebases must keep generated artifacts in git (not `.gitignore`), with regeneration commands documented, or the agent will either invent the types or edit the generated files.

**Anti-signals.** Three different ORMs. Five HTTP-client patterns. Conventions documented but not exemplified. Conventions exemplified but contradicted by half the codebase. A `utils/` folder with 60 files. Generated code committed without provenance header. Inconsistent test-collocation across packages.

---

### D9. Token-economy / context efficiency (5%) — NEW

**Definition.** How much of an agent's context window does the codebase eat per typical task? Are files chunkable, retrievable, and free of irrelevant bloat?

**Why for agents specifically.** Augment's [*AI Agent Loop Token Costs*](https://www.augmentcode.com/guides/ai-agent-loop-token-cost-context-constraints) makes the quantitative case: agent loops accumulate context quadratically because the entire history is re-serialized at every step — a 20-step loop with 1k-token steps produces 210k cumulative input tokens, not 20k. Dead context is paid for on every subsequent call. HumanLayer's 12-Factor §3 frames the same problem qualitatively (the "dumb zone" past 40% context utilisation). Aider's [PageRank-weighted repo map](https://aider.chat/docs/repomap.html) and Augment's [100M-line quantised vector search](https://www.augmentcode.com/blog/repo-scale-100M-line-codebase-quantized-vector-search) are the retrieval-side responses; the codebase side is the focus of this dimension. Karpathy's [hypertrophy observation](https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md) is the slow-burn case: AI-generated dead code accumulates, and every future agent run pays for it. Hashimoto's [Zed conversation](https://zed.dev/blog/agentic-engineering-with-mitchell-hashimoto) corroborates: "Gemini produces a monumental amount of text… not efficient to me" — token economy is felt at the user level, not just the bill.

**Signals.**

| Signal | Measurement |
|---|---|
| No vendored dependency trees committed (`node_modules/`, `vendor/`, `.venv/` excluded via `.gitignore`) | inspect `.gitignore` and `find` for them |
| Repo source tree under ~500k LOC OR has clear sub-package boundaries an agent can scope into | `cloc` / `tokei` |
| No `cat`-able 5k-line autogenerated files in the agent's path (move them, mark `linguist-generated`, or exclude from search) | `find . -size +200k -name '*.{ts,py,go,rs}'` |
| `.gitattributes` marks generated files with `linguist-generated=true` (keeps them out of GitHub diffs and many index passes) | `grep linguist-generated .gitattributes` |
| Dead-code is pruned (no large quarantines of "kept for reference"); a deadcode scanner runs in CI | `grep` for deadcode tools (`knip`, `unimport`, `cargo udeps`, `vulture`) |
| Files exceed 1500 LOC only by deliberate exception | `find . -name '*.{ts,py,go,rs}' \| xargs wc -l \| awk '$1>1500'` |
| Hot-path config / fixtures are small enough to inline-read (<500 LOC) | inspection |

**Weight justification (5%, NEW).** A new dimension carved from previously-scattered signals in D3, D8, and D6. 5% reflects that the token bill matters even for unmetered users (the dumb-zone effect degrades quality, not just cost), but token economy is downstream of D3 (locality) and D8 (conventions) — bad locality and bad conventions are the upstream causes of token bloat. We weighted the upstream dimensions higher and gave the symptom dimension a modest 5%. The strongest empirical case is Augment's quadratic-cost demonstration; the strongest qualitative case is Karpathy's hypertrophy framing.

**Anti-signals.** Megabytes of fixtures committed to the repo with no `.gitattributes`. Mile-long type definitions inlined into source instead of imported from a typed contract package. 3MB single-file React components (the agent loads the whole thing). Vendored copies of upstream libraries with no clear "this is vendored" marker. Tests committed without sharding when the suite is 100k+ LOC. "Snapshot tests" that are actually 10MB blobs of serialised HTML.

---

### D10. Agent-vantage security & runtime observability (4%) — NEW

**Definition.** Two adjacent concerns that didn't fit cleanly elsewhere: (a) can the agent operate without ambient credentials it shouldn't have or being weaponised by prompt injection in repo files, and (b) can the agent see what its code did at runtime (structured logs, traces) to verify success and triage failure?

**Why for agents specifically.**

*Security side.* Agents now routinely execute arbitrary shell, write files, and call APIs. NVIDIA's [*Practical Security Guidance for Sandboxing Agentic Workflows*](https://developer.nvidia.com/blog/practical-security-guidance-for-sandboxing-agentic-workflows-and-managing-execution-risk/) lays out the mandatory controls (network egress allow-list, write-jail, no-config-write). The [Google Antigravity sandbox-escape report](https://cyberscoop.com/google-antigravity-pillar-security-agent-sandbox-escape-remote-code-execution/) and Microsoft Security's [*When prompts become shells*](https://www.microsoft.com/en-us/security/blog/2026/05/07/prompts-become-shells-rce-vulnerabilities-ai-agent-frameworks/) are the demonstrations that this is not hypothetical. A codebase contributes here mainly by *not* embedding credentials inline, not relying on developer-local secrets, and not loading untrusted markdown/YAML into prompts. Claude Code's [sandboxing release](https://www.infoq.com/news/2025/11/anthropic-claude-code-sandbox/) and OpenAI's [*Designing AI agents to resist prompt injection*](https://openai.com/index/designing-agents-to-resist-prompt-injection/) frame the runtime side; the codebase side is the focus of this dimension.

*Observability side.* Sentry's [Seer Agent](https://thenewstack.io/sentrys-seer-agent-debug/) and Charity Majors's [*Observability in a World of AI*](https://www.honeycomb.io/blog/honeycomb-10-year-manifesto-part-1) manifesto make the same point from opposite ends: agents that deploy code into a system without telemetry are flying blind. The [OpenTelemetry Logs spec](https://opentelemetry.io/docs/specs/otel/logs/) — trace-correlated structured logs — is the open-standard substrate. Without runtime visibility, the agent's "is it working?" check is whatever was true at PR time.

**Signals.**

| Signal | Measurement |
|---|---|
| No secrets in repo (`.env` git-ignored; `.env.example` only); secret scanner in CI | `git log --all --full-history -- '*.env'` empty; `.gitleaks.toml` present |
| Repo doesn't load untrusted external content into prompts/configs without sanitisation (e.g. markdown from third-party PRs is not in skill bodies) | judgment + inspection |
| Structured logging library in use (`pino`, `structlog`, `zap`, `slog`, OTel SDK) — not freeform `print` / `console.log` | grep |
| Runtime observability integration exists (Sentry, Honeycomb, Datadog, OTel exporter) and is wired at least for errors | `grep -r 'Sentry\|honeycomb\|opentelemetry'` |
| Trace IDs propagate request → log → error → response (so an agent can stitch a session together) | grep for `trace_id` / `request_id` in error sites |
| Agent-runtime jail: a documented allow-list of network egress / writable paths exists for sandboxed agent invocations | `find .claude -name '*.sh'` etc.; judgment |
| Generated code (Prisma client, sqlc output) is the only path to the DB; raw SQL strings are rare or behind a typed wrapper (limits prompt-injection blast radius via SQLi) | grep raw `execute(` calls |

**Weight justification (4%, NEW).** A new low-weight dimension intentionally — most of the agent-security and observability work happens *outside* the codebase (in the agent runtime, in CI, in the prod environment). The codebase contributes meaningfully but not dominantly. 4% is enough to flag repos that hardcode `OPENAI_API_KEY` in source or have no structured logging anywhere, without overstating the codebase's leverage on what is largely an operational problem.

**Anti-signals.** API keys committed (even rotated, even "for dev"). `.env` files in git history. Setup steps that expose long-lived credentials to the agent's shell environment. `console.log` as the only error surface. No structured logging anywhere. Prompts/skills load arbitrary contents of `~/Downloads` or third-party gists without provenance. Direct `psql` calls in production paths (means the agent can be tricked into writing raw SQL).

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
- **A**: ≥80% of presence signals **and all liveness probes pass** (where the dimension has them — §5). No anti-signals. Presence without verified liveness caps at C.
- **B**: ≥60% of presence signals, liveness probes substantially pass. ≤1 minor anti-signal.
- **C**: ≥40% of signals, *or* presence is strong but liveness is unverified/partially failing. Anti-signals visible but not dominant.
- **D**: <40% of signals or a critical-path signal fails (e.g., no test command at all for D2).
- **F**: Dimension materially absent (no AGENTS.md/CLAUDE.md *and* no README for D1; tests don't run for D2; no lockfile *and* no container for D6).

**Present-but-misleading scores *below* absent.** A confidently-wrong artifact (a stale doc whose commands error, a test suite that's all-green because it asserts nothing, a lint config disabled in CI) is worse for an agent than the artifact being missing — absence makes the agent cautious; false confidence makes it act on bad information. When a liveness probe shows an artifact actively misleads, score the dimension **D or F, not C**, even if every presence signal passed. "It exists" is not partial credit when what exists lies.

**Compounding-context cap.** D1 is not a normal 13% line item — misleading onboarding context poisons every downstream dimension (the agent runs the wrong commands, then "verifies" against them). Therefore **a D1 score of D or F caps the overall grade at C**, the same way a §6 anti-pattern does. A repo cannot be "A overall, F on context."

**Empirical calibration footnote.** Weights remain expert-judgment; the v2 deepening pass did not change that. DORA 2024, METR's 19%-slowdown study, the SWE-Bench Pro public/commercial gap, and Augment's quadratic-cost evidence all *constrain* the weights (we'd have to argue with one of them to move D2, D3, or D9 substantially), but they don't pin them to a number. §8 retains this as a known weakness; a real empirical tune would require running a fixed task suite against representative repos at each grade and measuring success rate.

## 5. Mechanical vs. judgment signals

The left column detects *configuration* (cheap, fakeable). The right column is the **liveness probe** — it tests whether the configuration is *enforced, current, and honest*. The right column is not a soft "model vibe"; each row is an action the skill **must run**, because the left column alone produces the false-A this rubric exists to prevent (a repo full of present-but-dead artifacts).

| Mechanical — *is it configured?* (run a command) | Liveness probe — *is it enforced / current / honest?* (must be actively tested) |
|---|---|
| File existence (`AGENTS.md`, lockfile, `.env.example`, CI config, ADR folder) | **D1:** verify 3+ doc claims against the code; check doc freshness vs. code churn; is `AGENTS.md` *useful* vs. a stub? |
| Test command exists; exit code + wall time | **D2:** does the suite *assert* anything? (grep for skipped/`todo`/empty tests; a fast green on a suite of `it.skip` is a fail, not an A) |
| Lint / typecheck / format config present | **D4:** is the gate *required*? (CI job not `continue-on-error`; status check is a *required* check in branch protection, not just a defined workflow) |
| Lockfile and runtime-version pinning present | **D6:** is the lockfile *in sync* with the manifest? does the container actually build? is `.env.example` complete vs. what the code reads? |
| ADR folder / feature-flag library present | **D7:** are flags *used*, not just installed? are ADRs *current*, not reversed-and-never-updated? |
| One "canonical example" file exists | **D8:** is it *actually* canonical, or contradicted by the real code the agent will pattern-match against? |
| Structured-logging library in dependencies | **D10:** is it *populated* at error sites with useful keys, or imported and unused? |

If a liveness probe cannot be run (no CLI, no network, no clean checkout), record **"not verified"** and cap that dimension at C — do **not** assume the configuration is live. "Unverified" is not "passing."

## 6. Anti-patterns / red flags (cap the grade at C or below)

Any one of these caps the *overall* grade at C, regardless of other dimensions. They break the agent's core loop.

1. **No test command, or test command doesn't work on a clean checkout.** The agent cannot self-verify.
2. **No lockfile or pinned runtime.** The agent's environment is non-deterministic between sessions.
3. **CI runtime >20 minutes for unit tests.** Feedback loop too slow; agent guesses. (DORA 2024's −1.5% throughput finding under AI is the macro signal here — slow loops + AI is strictly worse than slow loops alone.)
4. **Tests that mutate shared state and require manual cleanup.** Agent stuck after first run.
5. **Secrets required for tests with no documented stub.** Agent cannot run anything end-to-end.
6. **Generated code committed without a regeneration command** — *or*, conversely, **generated types in `.gitignore` so the agent reads stale/missing definitions** (per the Suparbase argument: generated types must live in git for the agent to read them as truth).
7. **`main` where `git log -p` shows >50% of recent commits broke the build.** Agent's "is it working" reference is unreliable.
8. **Bare `except:` / empty `catch` in hot paths.** Errors vanish; debugging impossible.
9. **`AGENTS.md`/`CLAUDE.md` contradicts the actual codebase** (says `npm test` when real is `yarn test`). Worse than no doc — actively misleads.
10. **A dependency on a developer's local machine state** (locally-installed CLI, `~/.config` file, login session) not part of setup.
11. **AI-generated dead-code drift visible in `git log`** — file count or LOC has grown >2× in 6 months with no commensurate feature increase (Karpathy's hypertrophy). Drift caps the grade until pruned.
12. **API keys committed to git history**, even if rotated. The repo is now a poisoned input for any agent that indexes history (DeepWiki and similar tools do).
13. **Unbounded retry loops without a documented kill switch.** An agent reading the codebase as the canonical pattern will reproduce them.
14. **Test fixtures pull live data from production** with no local stub. Agent can't reproduce failures offline.
15. **Context docs materially stale or misleading.** A `CLAUDE.md`/`AGENTS.md`/`.ai/` whose sampled claims fail verification (commands error, cited paths don't exist), or that is untouched for months while its subject code churned. *Worse than no doc* — caps the grade, and the dimension itself scores below C (§4 present-but-misleading rule). This is the false-A guard.
16. **Gate configured but not enforced.** A lint/typecheck/test job present in CI but `continue-on-error: true`, or behind a status check that branch protection doesn't *require*, or a formatter that's installed but never run in CI. The agent reads "we have gates" from the config and trusts a wall that isn't there.
17. **Test suite present but trivial.** Tests exist and run green, but a meaningful fraction are `skip`/`todo`/`xfail` or assert nothing (`expect(true).toBe(true)`, no assertions in the body). A green that means nothing is more dangerous than a red — the agent ships on it.
18. **Lockfile out of sync with the manifest.** `package.json`/`pyproject.toml`/`Cargo.toml` lists deps the lockfile doesn't pin (or vice versa). The "reproducible" environment isn't — the next clean install drifts.

## 7. Backlog generation hints

For each dimension, the kinds of tasks that move the grade up. The `/grade-codebase` skill's "full report" mode turns these into an agent-actionable backlog.

- **D1 Onboarding context.** Add `AGENTS.md` with the six core sections (Commands, Testing, Project structure, Code style, Git workflow, Boundaries). Trim README to <2 screens. Replace placeholders with real commands. For monorepos, add per-package `AGENTS.md`. If you use Devin, seed `.devin/wiki.json` to steer DeepWiki.
- **D2 Build/test/lint loop.** Add a `make help` / `pnpm run` index of canonical commands. Parallelize the test suite under 30s. Add in-memory or containerized fixtures for the database. Move slow integration tests behind a `--slow` flag. Make dev-server reload < 5s.
- **D3 Code navigability & locality.** Turn on strict mode in the type-checker. Split files >1000 LOC into named modules. Replace barrel re-exports with direct imports on hot paths. Add an `eslint-plugin-import` / `import-linter` / `dependency-cruiser` boundary check. For monorepos, add Nx module-boundary tags.
- **D4 Mechanical gates.** Enable formatter `--check` in CI. Add `--max-warnings 0`. Adopt a secret scanner. Add a schema-diff gate (Prisma / sqlc / Atlas). Wire spec/OpenAPI drift checks (Specmatic).
- **D5 Failure honesty.** Audit `except`/`catch` for swallowed errors. Add structured logging. Write a "what to include in a bug report" issue template. Add error-context wrapping at boundaries (`raise X from e` everywhere).
- **D6 Reproducibility & hermeticity.** Pin the runtime. Commit a lockfile. Add a `Dockerfile` + `docker compose` for infra. Replace personal API keys with stubs or local-only secrets. Consider Bazel/Nix if hermeticity is critical.
- **D7 Change-safety affordances.** Adopt feature flags for unfinished work. Enforce branch protection on `main`. Add snapshot / Storybook+Chromatic tests for stable-output surfaces. Document migration rollback. Encourage smaller commits. Start an ADR folder in `docs/decisions/`.
- **D8 Conventions discoverable from code.** Build one canonical example for each common operation (one CRUD endpoint, one job, one form). Consolidate to one helper for logging / errors / DB. Add a `docs/conventions.md` *only* with rules not enforceable by linter (per Phoebe's rule). Mark generated files with `linguist-generated`.
- **D9 Token-economy.** Run a deadcode scanner (`knip`, `cargo udeps`, `vulture`); delete what's unused. Move vendored dependencies out of source paths. Mark generated files `linguist-generated=true`. Split mega-files. Audit `.gitignore` for committed `node_modules`/`vendor` slip-ins.
- **D10 Agent-security / observability.** Scan history for committed secrets (`gitleaks`, `trufflehog`); rotate and rewrite if found. Wire Sentry/OTel at least for errors. Add `trace_id` to log lines. Document the agent runtime's network/write jail.

## 8. Open questions / known weaknesses

- **Eval gap (still open).** This rubric grades the *substrate* (the codebase), not the *outcome* (how well a given agent does in it). A rigorous validation would run a fixed set of well-scoped tasks against representative repos at each grade and measure success rate. Until then, the weights are informed but not empirically tuned. Hamel Husain's [coding-agent evals work](https://hamel.dev/blog/posts/evals-skills/) plus [SWE-Bench Pro](https://arxiv.org/abs/2509.16941) and METR's [productivity study](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/) are the closest analogs and the natural future input.
- **Calibration gap (presence-vs-liveness) — partially closed.** The rubric was caught awarding an A to a repo whose context lived in a stale `.ai/` folder that hadn't been touched in months — every D1 *presence* signal passed while the content was dead. The fix was the §5 liveness-probe layer and the §6 #15–18 "configured-but-dead" red flags, which force the skill to verify rather than detect. The deliberately-rigged fixtures now live at `.claude/skills/grade-codebase/fixtures/` (one stale-doc, one empty-test-suite, one disabled-gate), each with an `EXPECTED.md` stating the grade it must receive (D/F, overall capped at C). Two validation layers: `bin/test-grade-fixtures` mechanically guards that each fixture *remains a valid negative* (the regression guard for the calibration set itself), and a model-graded `/grade-codebase full` run against each fixture is the dogfood that confirms the skill actually marks it down. **Still open:** the model-graded layer is run by hand, not in CI — there's no automated assertion that a future rubric/skill edit didn't re-open the false-A. Wiring the fixtures into `bin/skill-eval` (so the model-graded expectation runs as a trajectory eval) is the remaining work; the freshness probe also isn't mechanically exercised by the fixtures (they're plain dirs, not git repos with backdated history).
- **Domain bias.** The rubric tilts toward web/services repos (TypeScript, Python, Go). Embedded, ML-training, infra-as-code, and game-engine codebases have different ergonomics (a CUDA codebase's "test" is a benchmark; a Terraform module's "verification" is a `plan` diff). The skill should branch on detected stack.
- **Conflict between agent and human ergonomics.** Mostly they align. Two exceptions we couldn't fully resolve: (a) **documentation volume** — humans want more, agents want less; (b) **abstraction depth** — humans tolerate dynamic dispatch and DI containers, agents lose track of them. We've sided with the agent in both cases. The deeper-pass research surfaced a third tension: (c) **vendored dependencies** — humans (and supply-chain security) sometimes want vendored copies; agents pay the token bill. We've sided with the agent (D9) but a security-conscious reviewer would push back.
- **Source disagreement: indexing vs. plain reading.** Augment's [Context Engine](https://workos.com/blog/augment-code-context-is-the-new-compiler) and Sourcegraph's [Cody indexing](https://sourcegraph.com/blog/how-cody-understands-your-codebase) argue that strong external indexing makes codebase locality matter less (you index your way out of bad colocation). Anthropic's Claude Code and the [SWE-agent paper](https://arxiv.org/abs/2405.15793) take the opposite stance — that bounded, simple tools beat fancier indexing, and the codebase still needs to be navigable by `grep`/`find`. We sided with the read-first camp (D3 weights stayed high) on the grounds that not every agent will be paired with a sophisticated index, and indexers can be wrong. If a future where every agent has Augment-grade retrieval comes to pass, D3 weight could fall.
- **Monorepo vs. polyrepo.** Still no global verdict. Nx's [monorepo-AI argument](https://nx.dev/blog/the-missing-multiplier-for-ai-agent-productivity) is real but downstream of D3 (locality) and D8 (conventions). A polyrepo with strong contracts at boundaries can score as well as a monorepo with tangled imports. We grade the symptoms, not the shape — meaning a polyrepo org running a fleet of related repos may score each one well individually while still suffering cross-repo friction the rubric doesn't see. The [Augment polyglot-vs-monorepo writeup](https://www.augmentcode.com/tools/monorepo-vs-multi-repo-ai-architecture-based-ai-tool-selection) is the most current take we found and reinforces this neutrality.
- **Tool-loop weight.** [The 12-Factor "small focused agents"](https://github.com/humanlayer/12-factor-agents) and the [SWE-Bench Pro long-horizon results](https://arxiv.org/abs/2509.16941) both argue that *task scoping* matters as much as codebase quality. We don't grade task scoping because it's not a property of the codebase — but a codebase that *invites* small tasks (well-modularized, good D3+D8+D9) will look better than one forcing every change to span 12 files. The current weights probably under-credit this compounding.
- **Drift over time.** Karpathy's observation that agents introduce ["hypertrophy of code and abstractions"](https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md) means an A-graded codebase under continuous agent contribution can drift to B or C without anyone noticing. Anti-pattern #11 catches the gross case (file-count or LOC 2× in 6 months) but a finer-grained drift detector (per-file growth rate) would be more honest. Open work.
- **Parallel-agent / multi-agent friendliness.** Conductor, Claude Code worktrees, OpenHands fleets, Factory.ai droid orchestration — the field is rapidly moving toward many agents on one repo at once. Worktree-compatibility (no global state that conflicts across branches; no `localhost:3000`-only assumptions; no `node_modules`-mutation in scripts) is becoming load-bearing. We've folded the signals into D6 and D7 rather than adding a fourth dimension because the underlying issues (hermeticity, change-safety) are not new — but if multi-agent becomes the default workload in the next year, this may need its own dimension.
- **AGENTS.md vs. CLAUDE.md vs. .cursorrules.** [AGENTS.md is now the cross-tool open standard](https://agents.md/) and recognised by Codex, Cursor, Cline, Roo Code, Aider, Continue.dev, and via Spec Kit; Claude Code still preferentially reads `CLAUDE.md`. We treat any of them as evidence for D1; the skill should detect the user's primary agent and not penalize redundancy.
- **DORA / METR contradiction.** DORA 2024 reports AI gives individual productivity but hurts throughput and stability. METR finds AI makes experienced devs 19% slower on their own repos. The Octoverse 2025 numbers (1M+ Copilot-agent PRs, 80% of new devs using Copilot week-1) appear to contradict both. We took the side that *codebase shape determines which outcome you get*: a codebase scoring A on this rubric trends toward the Octoverse case; one scoring D trends toward METR. This is the rubric's most defensible-but-untested claim and the eval-gap above is the way to test it.

## 9. Changelog — v2 deepening pass

### Sources added

The original ~17 anchored citations grew to ~60+. New source clusters:

- **Vendor / lab.** OpenAI Codex docs (4 URLs), Anthropic Building Effective Agents PDF, Agent Skills overview, worktrees docs, sandboxing release; GitHub Copilot Workspace / Spaces / Spec Kit / Octoverse 2025.
- **Coding-agent products.** Continue.dev codebase-awareness + indexing docs; Cline / Roo Code AGENTS.md adoption; Factory.ai Droid + custom-droids; JetBrains Junie; Replit Agent; OpenHands ICLR paper + sandbox guide; Cognition Devin 2.0, Annual Performance Review, DeepWiki, DeepWiki MCP; Crawshaw's sketch.dev posts; Sentry Seer + multi-agent observability; Conductor parallel-agent worktrees.
- **Academic.** SWE-bench Verified leaderboard, SWE-agent NeurIPS 2024 paper, AutoCodeRover paper, Microsoft Magentic-One, LiveCodeBench / BigCodeBench / LiveCodeBench Pro.
- **Practitioner.** Hamel Husain (3 additional posts), Simon Willison (2 additional), Kent Beck Augmented Coding posts, Charity Majors observability writing, Hillel Wayne formal-methods posts, Steve Yegge Future-of-Coding-Agents + Normsky, Chip Huyen AI Engineering, Geoffrey Litt malleable-software post.
- **Adjacent disciplines.** 12-Factor App original; Building Evolutionary Architectures (Ford / Parsons); Bazel Hermeticity + reproducible-builds.org; trunk-based development (trunkbaseddevelopment.com + Aviator); GitHub Spec Kit / Specmatic / OpenSpec; adr.github.io + Cognitect ADR post + joelparkerhenderson/architecture-decision-record; dependency-cruiser, import-linter, Nx boundary rules; OpenTelemetry Logs spec; Storybook visual testing; Prisma deploy guide + Suparbase type-safety-as-load-bearing; NVIDIA agentic-sandboxing guide; Google Antigravity sandbox-escape report; Microsoft "When prompts become shells"; OpenAI "Designing AI agents to resist prompt injection"; Augment AI Agent Loop Token Costs.
- **Industry reports.** DORA 2024 Accelerate State of DevOps; METR Early-2025 OSS-Dev Productivity study.

### Dimensions added, folded, kept, removed

- **Added (2).**
  - **D9 Token-economy / context efficiency (5%).** Strongest empirical case is Augment's quadratic-cost demonstration; Karpathy's hypertrophy is the qualitative complement.
  - **D10 Agent-vantage security & runtime observability (4%).** Sentry's Seer + Honeycomb's AI-observability writing on one side; NVIDIA / Microsoft / OpenAI prompt-injection literature on the other. Two themes were small enough to belong together at 4% rather than as separate 2-3% dimensions.
- **Kept and substantially deepened (6).** D1, D2, D3, D4, D7, D8 all gained new signals and rationale citations; their definitions are unchanged.
- **Kept with light deepening (2).** D5 and D6 had less marginal evidence to add — D6 in particular is a mature, well-understood dimension and the new sources mostly corroborated existing signals.
- **Rejected (5).**
  - *Front-end-specific ergonomics as its own dimension.* Folded into D7 (snapshot/Storybook signal). Storybook visual testing is real and useful but the underlying property (stable-output surfaces have automated baselines) is dimension-agnostic.
  - *Multi-agent / parallel-work friendliness as its own dimension.* Folded into D6 (hermeticity) and D7 (change-safety). Worktree compatibility is mostly downstream of those; if multi-agent becomes the default workload it may earn its own dimension later (§8).
  - *Database / data-layer ergonomics as its own dimension.* Folded into D4 (migration validation gate) and D8 (one canonical DB-access helper). The Prisma "AI safety checks" feature is best captured as a D4 signal, not a new dimension.
  - *Polyglot friction as its own dimension.* Folded into D3 anti-signals ("three different ORMs"). The Augment polyglot writeup and Graphite monorepo guide make the case but the underlying property is dimension D3 (navigability) and D8 (conventions).
  - *Performance during agent operation as its own dimension.* Folded into D2 (dev-server reload signal) and D9 (token economy). The literature treats this as a sub-property, not a free-standing concern.
  - *Cost economics as its own dimension.* Too soft to grade as a property of the codebase; the proxy (source-tree size) lives in D9.

### Weight changes

| Dimension | v1 | v2 | Δ | Rationale |
|---|---|---|---|---|
| D1 Onboarding | 15% | 13% | −2 | Cross-vendor AGENTS.md standardisation lowers the marginal cost of getting this right; weight migrates to D9 where the cost of *not* doing it accrues. |
| D2 Build/test/lint | 18% | 18% | 0 | DORA 2024's small-batch finding + SWE-agent ACI paper both reinforce; no reason to move. |
| D3 Navigability | 15% | 14% | −1 | Architecture-rule linters folded in (was a D4 signal); 1 point migrates to D9. SWE-Bench Pro's enterprise gap argues this could even rise; we left it conservatively at 14%. |
| D4 Gates | 12% | 11% | −1 | Architecture-rule linters moved to D3; spec-drift signal moved to D7. |
| D5 Failure honesty | 10% | 9% | −1 | 1 point migrates to D10 where structured-logging now lives. |
| D6 Reproducibility | 8% | 7% | −1 | Lockfile + container is now near-table-stakes; marginal weight lower than a year ago. |
| D7 Change-safety | 12% | 11% | −1 | ADR + spec-drift signals added; 1 point migrates to D9. |
| D8 Conventions | 10% | 8% | −2 | Generated-code-hygiene signal added; 2 points migrate to D9 (1) and D10 (1). |
| D9 Token-economy (NEW) | — | 5% | +5 | Carved from D3/D6/D7/D8. |
| D10 Security/observability (NEW) | — | 4% | +4 | Carved from D5/D8. |
| **Total** | **100%** | **100%** | **0** | |

### Signals added / refined per dimension

- **D1.** Added OpenAPI/GraphQL/protobuf in-repo signal.
- **D2.** Added dev-server reload-time signal.
- **D3.** Folded architecture-rule linters into the signal set; explicit reference to Octoverse TypeScript trend.
- **D4.** Added spec-drift gate signal (Spec Kit / Specmatic) and explicit Prisma AI-safety reference.
- **D5.** Reframed scope to "authored error sites only"; runtime telemetry moved to D10.
- **D6.** Added bit-reproducibility / hermeticity-equivalent signal.
- **D7.** Added ADRs-colocated signal and visual-regression (Storybook/Chromatic) signal.
- **D8.** Added generated-code-marker + regenerate-command signal.
- **D9.** All signals new.
- **D10.** All signals new.

### New anti-patterns

- #11 AI-generated dead-code drift (>2× growth in 6 months).
- #12 API keys committed to git history.
- #13 Unbounded retry loops without a kill switch.
- #14 Test fixtures pull live production data with no local stub.

### Things the deeper pass did *not* change (and why)

- **D2 weight stays at 18%.** Every new source we looked at reinforced this. DORA, METR, Anthropic, Cognition, SWE-agent, sketch.dev, Augment — all of them, independently, treat the build/test/lint loop as the single most important thing. The v1 weight was already right.
- **D1's six AGENTS.md sections.** GitHub's 2,500-repo analysis remains the strongest empirical basis we have; nothing in the new sources contradicted it. Codex, Cline, and Roo Code all converged on the same structure independently.
- **The "don't grade documentation volume" exclusion.** Willison's argument held up under every new source; not one of the new practitioner posts argued for more prose docs. If anything the deeper-pass evidence is more emphatic (Karpathy's "delete what isn't needed"; Crawshaw's "compiler feedback beats documentation").
- **The "don't grade monorepo vs. polyrepo" exclusion.** The Augment polyglot writeup actively reinforced this — they grade per-repo properties (boundary discipline, contract typing) regardless of shape.
- **The mechanical-bias rule (§5).** Ford & Parsons's fitness-function framing gave us a stronger theoretical foundation but didn't change the practice: anything that can be a passing/failing check should be.
- **The 50%-judgment cap.** Held up against every source.
