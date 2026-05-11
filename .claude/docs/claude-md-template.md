# CLAUDE.md (starter template)

This is a **template**. Claude Code reads `CLAUDE.md` at the start of every session — it's your standing system prompt for this codebase.

Adapted from Karpathy's 4-rule CLAUDE.md ([forrestchang/andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills/blob/main/CLAUDE.md)), Mnimiy's 8-rule extension (`@Mnilax` on X, May 2026), and the agent-harness design philosophy (`.claude/docs/harness-principles.md`).

## How to adopt this

**Fresh install (no `CLAUDE.md` yet):** Copy this file to your repo root as `CLAUDE.md`, delete this "How to adopt" section, and fill in the `{{...}}` placeholders.

**Existing `CLAUDE.md`:** Merge in selectively. The sections below are tagged `[REQUIRED]` (instruction-precedence, needed for the harness to work as designed) or `[RECOMMENDED]` (the 12 rules — most existing CLAUDE.md files are missing rules 5, 6, 7, 11, 12). Leave your project-specific notes alone.

Concrete merge heuristic:

1. **Always add the `## Instruction precedence` block** — the harness's skills rely on this hierarchy being declared.
2. **Add any of the 12 rules your current file doesn't already cover.** Rules 1–4 (Karpathy edit-time) are often implicit in existing files; rules 5–12 (runtime behavior) usually aren't.
3. **Keep your project's `## Project-specific notes` and `## Don't touch` sections at the top of your file** — they're the highest-signal context.
4. **Cap total length at ~2 screens.** If your `CLAUDE.md` grows past that, Claude starts ignoring the middle. Cut older rules when you add new ones.

If you have any doubt about a merge, ask Claude: "Read `.claude/docs/claude-md-template.md` and my current `CLAUDE.md`, then show me which sections I'm missing — don't edit yet, just list them."

---

# {{Project Name}} — Working Notes

## What this project is

{{One paragraph. What does this codebase do? Who uses it? What's the stack?}}

## Instruction precedence  `[REQUIRED]`

When instructions conflict, this is the order:

1. **User explicit instructions** (this `CLAUDE.md`, direct user requests in the conversation) — highest.
2. **Harness skills** (`/tdd`, `/pre-deploy`, `/ship`, etc.) — override default Claude behavior where they conflict.
3. **Default Claude behavior** — lowest.

If `CLAUDE.md` says "don't use TDD for prototypes in `experiments/`" and `/tdd` says "always TDD," follow `CLAUDE.md`. The user is principal; skills are advisors.

## The 12 rules  `[RECOMMENDED]`

### Edit-time (when you're writing or editing code)

**1. Think before coding.** State your assumptions explicitly. If multiple interpretations exist, present them — don't pick silently. If something's unclear, stop and ask. Don't hide confusion.

**2. Simplicity first.** Minimum code that solves the problem. No features beyond what was asked. No abstractions for single-use code. No "flexibility" that wasn't requested. No error handling for impossible scenarios. If you wrote 200 lines and 50 would do, rewrite.

**3. Surgical changes.** Touch only what the task requires. Don't refactor adjacent code. Don't reformat sibling files. Match existing style even when you'd do it differently. Every changed line should trace to the request. If you notice unrelated dead code, mention it — don't delete it.

**4. Goal-driven execution.** Transform tasks into verifiable goals before starting. "Add validation" → "Write tests for invalid inputs, then make them pass." "Fix the bug" → "Write a test that reproduces it, then make it pass." For multi-step tasks, state the plan with explicit success criteria.

### Runtime (how the agent behaves in this session)

**5. Use the model only for judgment calls.** Anything mechanically enforceable belongs in code — a script, a validator, a hook, a CI check — not in a prompt. Claude is for ambiguous decisions (naming, design choices, framing). Don't ask the model to do what `grep` can do.

**6. Token budgets are not advisory.** Long context = degraded model. Read what you need; don't dump entire files when a section will do. Use subagents (Explore, general-purpose) for searches that would otherwise consume thousands of tokens you don't need to keep.

**7. Surface conflicts, don't average them.** When two instructions disagree (CLAUDE.md vs. user message, skill vs. CLAUDE.md, two parts of a request), pick one and name the conflict. Don't half-satisfy both. The user is principal; ask them to resolve.

**8. Read before you write.** Before editing a file, read the current state. Before adding a function, check if one already exists. The Edit tool enforces a prior Read for this reason — don't fight the guardrail by writing from imagination.

**9. Tests verify intent, not behavior.** A test that asserts "the function returns whatever it currently returns" is a regression lock-in, not a test. Write tests that say what the code *should* do, then make them pass. (See `/tdd`.)

**10. Checkpoint after every step.** After each meaningful step, stop and verify — run the test, commit, update the todo list, or ask. Don't blur multiple steps into one push. The checkpoint is what makes rollback possible.

**11. Match conventions, even if you disagree.** Style match the codebase. Use its naming, its file layout, its testing patterns. If you think a convention is wrong, raise it as a separate discussion — don't silently introduce a new pattern in an unrelated PR.

**12. Fail loud.** When something breaks or is impossible, throw / log / error visibly. Don't swallow exceptions to "keep things running." Don't return a default that hides the failure. A loud failure is a debuggable failure; a silent one is a future incident.

## Project-specific notes  `[YOUR CONTENT — keep what you have]`

{{This is the section to customize most. Examples:}}

- **Stack:** {{Next.js 15, Postgres, Vercel. Or: Python 3.12, FastAPI, Cloud Run.}}
- **Conventions:** {{We use snake_case for file names, named exports only, no default exports.}}
- **Don't touch:** {{`migrations/` is auto-generated; don't edit by hand. `vendor/` is upstream.}}
- **Dev workflow:** {{Run `pnpm dev` for the dev server; `pnpm test:watch` while editing.}}
- **Where to add new code:** {{Features go under `apps/web/features/<name>/`; shared utils in `packages/shared/`.}}
- **Skip these gates:** {{`/tdd` is exempt for `scripts/` and `experiments/` — those are throwaway.}}

## Learnings (captured by /learn)

If you use `/learn`, entries live at `docs/learnings/<slug>.md` with a `Rule / Why / How to apply` body. Avoid saving entries that fall in the anti-list — code patterns, file paths, git history, fix recipes, ephemeral state. When a candidate looks like one of those, ask what was *surprising* and save the surprising framing instead. Memories that name a specific function, file, or flag should be re-verified (`Grep` / `test -e`) before being recommended.

## Skills available

The agent-harness ships with `/tdd`, `/pre-deploy`, `/ship`, `/debug`, `/write-skill`, and more. Run `/harness-overview` for the full list and how they compose.
