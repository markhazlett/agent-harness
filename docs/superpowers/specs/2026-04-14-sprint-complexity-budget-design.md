# Sprint Complexity Budget — Design Spec

**Date:** 2026-04-14
**Status:** Approved
**Scope:** `agent-harness` — planning skills and config

## Problem

The sprint planning system used hour-range estimates (`[Extend]` = 2-4 hrs, `[Build]` = 4-8+ hrs) calibrated for a single developer working sequentially. With conductor and parallel agents, those ranges are inaccurate by an order of magnitude — work estimated at ~10 hours ships in under 1 hour. The estimates were undermining trust in the planning system without providing useful signal.

The real constraints are:

1. **Architectural risk** — how many moving parts are changing at once, regardless of agent speed
2. **Checkpoint density** — enough natural pause points to verify quality before continuing

Neither is measured in hours.

## Decision

Replace hour-based capacity with a **complexity point budget**. Keep the existing `[Exists]` / `[Extend]` / `[Build]` / `[Narrate]` tags — they accurately signal complexity and risk — but strip the hour ranges. Add a checkpoint requirement so sprints can't be over-scoped without independent verification points.

## Tag System

| Tag | Points | Meaning |
|-----|--------|---------|
| `[Exists]` | 0 | Already works, just needs demo setup/data |
| `[Extend]` | 1 | Existing feature needs moderate changes |
| `[Build]` | 3 | New from scratch — higher architectural risk |
| `[Narrate]` | 0 | Not built yet, told as vision |

The 3:1 ratio between `[Build]` and `[Extend]` reflects risk and moving parts, not time. Three simultaneous `[Build]` items is architecturally riskier than nine `[Extend]` items regardless of how fast agents work.

## Complexity Budget

**Default:** 9 points per sprint (`HARNESS_SPRINT_COMPLEXITY_MAX`)

This allows:
- 3× `[Build]` items (3+3+3 = 9), or
- 9× `[Extend]` items (1×9 = 9), or
- Any mix (e.g., 1× `[Build]` + 6× `[Extend]` = 9)

If total points exceed the budget, the planning skill cuts scenes or moves them to `[Narrate]` until the sprint fits. The default of 9 is intentionally ambitious without being reckless — users can raise it via config for teams or setups with higher parallelism.

## Checkpoint Requirement

**Default minimum:** 2 checkpoints per sprint (`HARNESS_SPRINT_CHECKPOINT_MIN`)

A checkpoint = one independently-verifiable item. An item is independently verifiable if:
- It has its own demo scene verification step, or
- It can be reviewed/merged as its own PR without requiring other in-progress work

If two `[Build]` items are so entangled they can't be verified separately, they count as one item and the plan must flag the coupling. A sprint with fewer than `HARNESS_SPRINT_CHECKPOINT_MIN` checkpoints is flagged as a quality risk.

## Capacity Check Format

The old format:
```
**Capacity check:** ~X hours available · Y hours of [Build] + [Extend] work · Z scenes live, N narrated
```

Replaced with:
```
**Complexity check:** 9 pts available · 7 pts used (2×[Build] + 1×[Extend]) · 3 scenes live, 1 narrated
```

## Config Vars (harness.config.sh)

```bash
HARNESS_SPRINT_COMPLEXITY_MAX="${HARNESS_SPRINT_COMPLEXITY_MAX:-9}"
HARNESS_SPRINT_CHECKPOINT_MIN="${HARNESS_SPRINT_CHECKPOINT_MIN:-2}"
```

## Files Changed

| File | Change |
|------|--------|
| `.claude/hooks/harness.config.sh` | Add `HARNESS_SPRINT_COMPLEXITY_MAX` and `HARNESS_SPRINT_CHECKPOINT_MIN` |
| `.claude/skills/demo-script/SKILL.md` | Strip hour ranges from tags; replace capacity check with complexity check; update cut-line logic |
| `.claude/skills/plan-sprint/SKILL.md` | Replace "~X hours" capacity line with complexity budget; remove "3-5 hours" sizing guidance; replace `~N hours` in plan template |
| `.claude/skills/weekly-goals/SKILL.md` | Replace capacity check reference with complexity check |
| `.claude/skills/ad-hoc-plan/SKILL.md` | Replace "1-3 hour effort" in when-to-use table with "≤3 complexity pts (1-2 [Extend] items)"; replace "< 1 hour" don't-over-plan guidance with "0-pt complexity (single [Exists] task)" |
| `.claude/skills/deep-plan/SKILL.md` | Update comparison table and time budget table to complexity budget |

## What Stays the Same

- The four tags themselves (`[Exists]`, `[Extend]`, `[Build]`, `[Narrate]`) — they accurately signal complexity
- The cut-line concept — over-budget sprints still get trimmed
- The `[Narrate]` escape valve — future vision scenes still get marked clearly
- The demo scene structure — scenes still have verification steps
