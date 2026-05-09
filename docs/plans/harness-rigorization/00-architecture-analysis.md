# Harness Rigorization — Architecture Analysis

**Created:** 2026-05-09
**Source:** Gap analysis against `Harness Principles.md` (Parts I–IX, XI)
**Status:** Ready to execute. Sub-plans G1–G9 below.

## Context

`Harness Principles.md` extracts 63 principles from a Claude Code + superpowers-style harness. This repo's harness — a general-purpose dev harness shipped to other users — aligns on the structural pillars (layered context, hooks-as-forcing-functions, multi-stage workflow, typed memory via `/learn`) but has gaps in the *behavioral discipline* layer: the patterns that make rigid skills feel prescient under pressure (Iron Laws, Rationalization Tables, Red Flags, Self-Review checklists, terminal-state declarations) plus a missing `/debug` skill and an inconsistent frontmatter contract.

This workstream lands those gaps as one cohesive PR. Goal is "harness 0.7 — behavioral rigor."

## Current state summary

**What works**
- Hooks fight known failure modes (`bash-guard.sh`, `protected-files.sh`, `stop.sh`, `init.sh`, `pre-compact.sh`).
- Multi-stage workflow exists end-to-end (`/weekly-goals → /demo-script → /plan-sprint → /build → /ship`).
- Typed memory via `/learn` with project + user buckets, Rule/Why/How-to-apply body shape, index/body split.
- Skills are loadable files with on-demand body injection.
- Subagent isolation via `validator` (read-only Opus), `e2e-tester` (browser Sonnet), `migration-validator` (read-only Haiku).

**What's missing**
- 11 of 26 skills lack YAML frontmatter entirely (`tdd`, `ship`, `pre-deploy`, `self-verify`, `e2e-verify`, `security-review`, `incident`, `db-review`, `worktree`, `dev-server`, `harness-overview`). One has a name mismatch: `build-plan/SKILL.md` declares `name: build`.
- Zero skills have a real two-column Rationalization Table. Some have implicit Iron Laws as numbered rules.
- No skills are TDD'd against subagent baselines — no infrastructure exists to harvest rationalizations under pressure.
- `/learn` has no anti-list of what NOT to save, no verify-before-recommend rule.
- `/plan-sprint` and `/deep-plan` have no mechanical Self-Review pass.
- No `/debug` skill — debugging is unstructured.
- 4 missing terminal-state declarations (`lg-scaffold`, `lg-design`, `build-plan`, `tdd`); 2 underspecified handoffs (`tdd → e2e-verify`, `incident → fix`).
- No stated user-supremacy invariant in `CLAUDE.md` or `README.md`.

**Reference templates available locally**
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/test-driven-development/SKILL.md` — Iron Law, Rationalization Table, Red Flags, Self-Review checklist.
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/verification-before-completion/SKILL.md` — Gate Function pattern.
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/writing-skills/SKILL.md` — RED/GREEN/REFACTOR cycle for skills + `testing-skills-with-subagents.md` reference.

These will be copied verbatim as templates and adapted for this harness.

## Final classification (decided)

Rigid skills (gate-worthy; require Iron Law + Rationalization Table + Red Flags + Self-Review):
- `tdd`, `pre-deploy`, `ship`, `e2e-verify`, `security-review`, `incident`, `db-review`, `lg-review`, plus new `/debug` (9 total).

Flexible skills (procedural, judgment-driven; keep current shape, just standardize frontmatter):
- `weekly-goals`, `demo-script`, `plan-sprint`, `deep-plan`, `ad-hoc-plan`, `build-plan`, `learn`, `self-verify`, `office-hours`, `lg-design`, `lg-scaffold`, `lg-add`, `lg-eval`, `lg-cheatsheet`.

Util skills (operational, no rigor needed):
- `sync`, `worktree`, `dev-server`, `harness-overview`.

Note: `self-verify` is FLEXIBLE (quick browser spot-check, not gate-worthy). `e2e-verify` is the rigid version. `plan-sprint` is FLEXIBLE despite parallelization-wave detection — planning is judgment work; rigid feels wrong.

## One-way door analysis

### 1. Frontmatter shape (decided: include `tier` and `kind`)

**Decision:** Every skill's frontmatter must declare:

```yaml
---
name: <skill-name>                   # required, must match folder
description: Use when <trigger>      # required, trigger-only (no workflow summary)
user-invocable: true|false           # required
tier: rigid | flexible | util        # required
kind: process | implementation | verification   # optional (omitted for tier: util)
---
```

**Why this is one-way:** Adding a new required field later forces a retroactive edit on all skills. Locking the shape now matters.

**Risk if wrong:** If `tier`/`kind` proves too coarse, future skills get squeezed into the wrong bucket and the typing stops being honest. Mitigation: the `kind` field is optional; we can add a fourth tier or a fifth kind without breaking existing entries.

### 2. Skill-baseline storage location (decided: committed under `docs/skill-baselines/`)

**Decision:** Baselines live at `docs/skill-baselines/<skill>-<date>.md`, git-tracked.

**Why this is one-way:** Once future contributors expect baselines there, moving them is annoying. Committing rather than gitignoring gives forensic value when a skill regresses — we can re-run the same scenario against the new skill body.

### 3. Rationalization Table location (decided: sibling files)

**Decision:** Each rigid skill's heavy reference (Rationalization Table, Red Flags expanded notes) lives in a sibling file under the skill folder, loaded on demand:

```
.claude/skills/tdd/
  SKILL.md                  # ~250 words: Iron Law, body, link to references
  rationalizations.md       # full Rationalization Table
  red-flags.md              # full Red Flags list (if extensive)
```

`SKILL.md` cross-references with `**REQUIRED SUB-FILE:** Read rationalizations.md if you find yourself making excuses` — matches superpowers convention.

**Why this matters:** `/tdd`, `/ship`, `/pre-deploy` load on every dev-flow conversation. Inline tables would 3x their token weight. Sibling files keep the body scannable and only load reference when triggered.

### 4. `/ship` does NOT auto-fire `/pre-deploy` (decided: no)

**Decision:** `/ship` continues to run lint + test + commit + push + PR. It does NOT auto-invoke `/pre-deploy`. Instead, `/ship` adds a check: if the diff touches auth, schema, deploy config, or other risk surfaces, it asks "Did you run `/pre-deploy`?" once.

**Why this is NOT one-way:** Behavior change is reversible. But auto-firing would surprise existing users, so we don't do it.

## NOT one-way doors

These are safe to revise after landing:

- Specific Iron Law wording (one-line declarations are easy to refine).
- Rationalization Table rows (extend as new excuses surface).
- Red Flag list items (extend or prune).
- `/debug` phase definitions (the stage shape can evolve).
- Terminal-state phrasings (small text tweaks).
- Whether `/incident` chains to a fix-skill (deferred — current behavior is fine).

## Risks

| # | Risk | Mitigation |
|---|---|---|
| 1 | Token bloat in frequently-loaded skills | Sibling-file pattern (decision #3). Body stays <500 words; reference loads on demand. |
| 2 | Subagent baselines × 8 skills × pressure scenarios = real cost | One-time cost, ~50k tokens total. Run once during G6/G7; commit baselines for future regressions. |
| 3 | Rigid skills frustrate user when bypass is legitimate | G5 user-supremacy invariant + each rigid skill's frontmatter notes the override path ("if `CLAUDE.md` says skip, follow it"). |
| 4 | Coupled handoff changes | G9 lands all terminal-state and handoff edits in one pass after the rigid skills are written. |
| 5 | `bin/skill-baseline` could rot | Document its inputs/outputs; require G6 to use it before merging. |

## Security review

This workstream changes documentation and skill content. No new endpoints, no auth changes, no DB writes, no external integrations. Skipped — N/A.

## Execution strategy & parallelization

**Wave 1** (independent, can run in parallel):
- G1 — Frontmatter + classification pass
- G2 — Skill-baseline infra (`bin/skill-baseline` + `/skill-baseline` skill)
- G3 — `/learn` hardening (anti-list + verify-before-recommend)
- G4 — Mechanical Self-Review for `/plan-sprint` and `/deep-plan`
- G5 — User-supremacy invariant (CLAUDE.md + README)

**Wave 2** (depends on G1 + G2):
- G6 — Rigid template + first 3 rigid skills (`tdd`, `pre-deploy`, `ship`)

**Wave 3** (depends on G6):
- G7 — Remaining 5 rigid skills (`security-review`, `incident`, `db-review`, `e2e-verify`, `lg-review`)
- G8 — New `/debug` skill (depends on G2 + G6)

**Wave 4** (depends on G7):
- G9 — Terminal states + missing handoffs

### Time budget

| Sub-plan | Pts | Wave | File footprint overlap with |
|----------|-----|------|------------------------------|
| G1 | 2 | 1 | G6, G7, G8 (frontmatter only — sequence after G1) |
| G2 | 3 | 1 | None |
| G3 | 1 | 1 | None |
| G4 | 1 | 1 | None |
| G5 | 1 | 1 | None |
| G6 | 4 | 2 | G7 (template), G8 (template) |
| G7 | 3 | 3 | G9 (terminal states) |
| G8 | 2 | 3 | G9 (terminal states) |
| G9 | 2 | 4 | None |

**Total: 19 pts.** Conductor users can run wave 1 in 5 parallel workspaces. Otherwise the sequence is G1+G2+G3+G4+G5 → G6 → G7+G8 → G9.

## Sub-plan index

| File | Title | Pts |
|------|-------|-----|
| [G1-frontmatter-classification.md](./G1-frontmatter-classification.md) | Frontmatter audit + `tier`/`kind` fields + CONVENTIONS.md | 2 |
| [G2-skill-baseline-infra.md](./G2-skill-baseline-infra.md) | `bin/skill-baseline` helper + `/skill-baseline` skill | 3 |
| [G3-learn-hardening.md](./G3-learn-hardening.md) | `/learn` anti-list + verify-before-recommend | 1 |
| [G4-self-review-for-planning.md](./G4-self-review-for-planning.md) | Mechanical Self-Review for `/plan-sprint` + `/deep-plan` | 1 |
| [G5-user-supremacy-invariant.md](./G5-user-supremacy-invariant.md) | User-supremacy statement in CLAUDE.md + README | 1 |
| [G6-rigid-template-first-three.md](./G6-rigid-template-first-three.md) | Rigid template + `tdd`/`pre-deploy`/`ship` rigorization | 4 |
| [G7-remaining-rigid-skills.md](./G7-remaining-rigid-skills.md) | `security-review`/`incident`/`db-review`/`e2e-verify`/`lg-review` | 3 |
| [G8-debug-skill.md](./G8-debug-skill.md) | New `/debug` rigid skill (staged debugging) | 2 |
| [G9-terminal-states-handoffs.md](./G9-terminal-states-handoffs.md) | Terminal-state declarations + `/ship` risk-check + `tdd→e2e-verify` linkage | 2 |

## Done criteria for the workstream

- [ ] All 26 existing skills have valid frontmatter with `name`, `description` (trigger-only), `user-invocable`, `tier`, `kind` (where applicable).
- [ ] `.claude/skills/CONVENTIONS.md` documents the frontmatter contract and the rigidity tiers.
- [ ] `bin/skill-baseline` exists and dispatches a subagent baseline run end-to-end.
- [ ] `/skill-baseline` skill exists and walks a contributor through RED/GREEN/REFACTOR for skills.
- [ ] `docs/skill-baselines/` contains at least 8 baseline files (one per rigid skill in G6+G7).
- [ ] 9 rigid skills have Iron Law + Rationalization Table (sibling file) + Red Flags + Self-Review.
- [ ] `/learn` has anti-list + verify-before-recommend rule.
- [ ] `/plan-sprint` and `/deep-plan` have a mechanical Self-Review phase.
- [ ] `CLAUDE.md` and `README.md` declare user-supremacy invariant.
- [ ] `/debug` skill exists, is rigid, hands off to `/tdd`.
- [ ] Terminal states declared on `lg-scaffold`, `lg-design`, `build-plan`, `tdd`.
- [ ] `/ship` includes risk-check question for auth/schema/deploy diffs.
- [ ] `VERSION` bumped to `0.7.0`.
- [ ] `/harness-health` passes.
