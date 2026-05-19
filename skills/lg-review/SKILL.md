---
name: lg-review
description: Use when the user says "review my agent", "is this LangGraph code current", "audit this for footguns", "help me migrate from v0", or "find the bug in my graph". Reviews LangChain/LangGraph code for v1 best practices, deprecated patterns, and known footguns; doubles as the migration scout for v0→v1 upgrades.
user-invocable: true
tier: rigid
kind: verification
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Run `/harness-update` to pull it in." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

<langgraph-gate>
Run: `bash -c 'source "$(git rev-parse --show-toplevel)/.claude/hooks/config.sh"; [ "$HARNESS_LANGGRAPH" = "true" ] && echo OK || echo OPT_IN_REQUIRED'`
- `OPT_IN_REQUIRED` → tell the user: "lg-* skills are opt-in. Run `./setup.sh` and answer 'yes' to LangGraph mode to enable." Then stop without doing the rest of the skill.
- `OK` → continue silently.
</langgraph-gate>

# /lg-review

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

Read-only static audit of LangChain/LangGraph code against v1 best practices and the current deprecation list. Analysis comes first; fixes are offered only after the full punch list is presented and the user explicitly approves. Results saved to `docs/lg-reviews/`.

## The Iron Law

```
NO LG-REVIEW APPROVAL WITHOUT EVERY DEPRECATION CHECK AND EVERY FOOTGUN CHECK
```

Every deprecated pattern from `/lg-cheatsheet` §15 is checked, every footgun from §14 is checked, and each produces a verdict: BLOCK, WARN, or PASS. "It works in tests" is not a verdict. "v1 migration is on the roadmap" is not a verdict. Spot-checking is not a review.

## Gate Sequence

**REQUIRED SUB-FILES:** `static-checks.md` (pattern tables, grep strategies, fix patterns, punch-list format) and `/lg-cheatsheet` §14 (footguns) + §15 (deprecation).

1. **Phase 0 — Load context.** Invoke `/lg-cheatsheet`. Don't proceed without it.
2. **Phase 1 — Scope.** Accept `/lg-review <path>`; default `src/agents/**`. Read-only.
3. **Phase 2 — Static checks.** Run all four passes (deprecation, correctness, production, style). Grep each pattern in `static-checks.md`; cite `file:line` per finding; "none found" is a verdict.
4. **Phase 3 — Synthesize.** Build punch list grouped by severity (BLOCKING → WARNING → NIT), ordered by file:line. Save to `docs/lg-reviews/<date>-<slug>.md`. Print it.
5. **Phase 4 — Migration mode.** If BLOCKING deprecation count ≥ 3, offer `[Y]es / [S]tep-by-step / [P]rint plan only`. Otherwise skip.
6. **Phase 5 — Offer fixes.** AskUserQuestion: `"Apply BLOCKING fixes? (y/n/select)"`. Apply only what's authorized; run `$HARNESS_TEST_CMD` after.
7. **Phase 6 — Final report.** Punch list with `✓`/`•` markers, summary line per severity, saved-path citation.

## Red Flags — STOP

- "It works in tests."
- "v1 migration is on the roadmap."
- "createReactAgent is fine for now."
- "MemorySaver is acceptable in dev."
- "Missing reducer is theoretical."
- "Sign off with TODOs noted."
- "Spot-check the obvious, the rest is theoretical."
- Skipping a Grep pattern because the result "would be" empty.
- Approving without producing the punch list.

**All of these mean: stop. Run the missing pattern; produce a verdict per item.**

## Common Rationalizations

**REQUIRED SUB-FILE:** Read `rationalizations.md` if you find yourself making excuses. The verbatim-excuse-to-reality table is harvested from a real `time-pressure-quick-fix` baseline plus domain-specific deprecation framings.

## Self-Review Checklist

- [ ] `/lg-cheatsheet` was loaded before Phase 2.
- [ ] Every pattern in §2.1, §2.2, §2.3, §2.4 has a verdict (finding or "none found").
- [ ] Punch list is grouped by severity, ordered by file:line.
- [ ] Punch list is saved to `docs/lg-reviews/<date>-<slug>.md`.

Cannot check all boxes? The audit is not complete. Do not approve.

## What this skill does NOT cover

- Runtime behavior (use `/lg-eval` for that).
- Architecture decisions (use `/lg-design`).
- Adding capabilities (use `/lg-add`).

## Tone

Senior engineer. Evidence-based. Every finding cites file:line. Read-only by default. Grep first, conclude from evidence — don't flag patterns not actually found. A clean category is a positive signal.
