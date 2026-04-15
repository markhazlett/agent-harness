# Sprint Complexity Budget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hour-based capacity estimates in planning skills with a complexity point budget (`[Build]` = 3 pts, `[Extend]` = 1 pt) and a checkpoint minimum guardrail.

**Architecture:** Six markdown files are edited — one config file and five skill files. No code, no tests. Each task edits one file and commits. Changes are independent and can be applied in any order, but Task 1 (config) should land first so skills reference vars that exist.

**Tech Stack:** Bash (harness.config.sh), Markdown (SKILL.md files), Git

**Spec:** `docs/superpowers/specs/2026-04-14-sprint-complexity-budget-design.md`

---

## File Footprint

| File | Change |
|------|--------|
| `.claude/hooks/harness.config.sh` | Add `HARNESS_SPRINT_COMPLEXITY_MAX` and `HARNESS_SPRINT_CHECKPOINT_MIN` |
| `.claude/skills/demo-script/SKILL.md` | Strip hour ranges; replace capacity check with complexity check; update cut-line |
| `.claude/skills/plan-sprint/SKILL.md` | Replace capacity line; remove "3-5 hours" sizing; replace `~N hours` in template |
| `.claude/skills/weekly-goals/SKILL.md` | Replace "capacity check" with "complexity check" in 4 places |
| `.claude/skills/ad-hoc-plan/SKILL.md` | Replace "1-3 hour effort" and "< 1 hour" with complexity-point equivalents |
| `.claude/skills/deep-plan/SKILL.md` | Update comparison table and sub-plan effort column |

---

## Task 1: Add config vars to harness.config.sh

**File:** `.claude/hooks/harness.config.sh`

- [ ] **Step 1: Open the file and verify the current last line**

  Read `.claude/hooks/harness.config.sh`. Confirm the last line is:
  ```
  HARNESS_REQUIRED_ENV_VARS="${HARNESS_REQUIRED_ENV_VARS:-}"
  ```

- [ ] **Step 2: Append the two new config vars**

  Add the following block at the end of the file (after the existing last line):
  ```bash

  # Sprint complexity budget — max complexity points per sprint.
  # Complexity weights: [Build] = 3 pts, [Extend] = 1 pt, [Exists] = 0 pts.
  # Default 9 = 3× [Build] items, or 9× [Extend], or any mix.
  HARNESS_SPRINT_COMPLEXITY_MAX="${HARNESS_SPRINT_COMPLEXITY_MAX:-9}"

  # Minimum independently-verifiable checkpoints per sprint.
  # A sprint with fewer checkpoints is flagged as a quality risk.
  # A checkpoint = one item with its own demo scene verification or its own PR.
  HARNESS_SPRINT_CHECKPOINT_MIN="${HARNESS_SPRINT_CHECKPOINT_MIN:-2}"
  ```

- [ ] **Step 3: Verify the file ends correctly**

  Run:
  ```bash
  tail -10 .claude/hooks/harness.config.sh
  ```
  Expected: the two new vars appear at the bottom with their comments.

- [ ] **Step 4: Commit**

  ```bash
  git add .claude/hooks/harness.config.sh
  git commit -m "feat(config): add HARNESS_SPRINT_COMPLEXITY_MAX and HARNESS_SPRINT_CHECKPOINT_MIN"
  ```

---

## Task 2: Update demo-script/SKILL.md

**File:** `.claude/skills/demo-script/SKILL.md`

Four edits to this file. Make them in order.

- [ ] **Step 1: Strip hour ranges from tag definitions and add point weights**

  Find this block (lines ~33-37):
  ```
     - `[Exists]` — already works, just needs demo setup/data
     - `[Extend]` — existing feature needs moderate changes (2-4 hrs)
     - `[Build]` — new from scratch (4-8+ hrs)
     - `[Narrate]` — not built yet, told as vision ("and then what happens is...")
  ```

  Replace with:
  ```
     - `[Exists]` — already works, just needs demo setup/data (0 pts)
     - `[Extend]` — existing feature needs moderate changes (1 pt)
     - `[Build]` — new from scratch, higher architectural risk (3 pts)
     - `[Narrate]` — not built yet, told as vision ("and then what happens is...")
  ```

- [ ] **Step 2: Update the capacity check source instruction**

  Find:
  ```
     Check `CLAUDE.md` for the project owner's typical weekly capacity. Apply the cut line accordingly.
  ```

  Replace with:
  ```
     Check `CLAUDE.md` for any override to `HARNESS_SPRINT_COMPLEXITY_MAX` (default: 9). Apply the cut line accordingly.
  ```

- [ ] **Step 3: Update the cut-line logic to use points**

  Find:
  ```
  3. **Apply the cut line.** Add up the `[Extend]` and `[Build]` hours. If they exceed the weekly capacity, cut scenes or move them to `[Narrate]`. Be ruthless. A 3-scene demo where everything works beats a 6-scene demo where half is broken.
  ```

  Replace with:
  ```
  3. **Apply the cut line.** Sum the complexity points (`[Build]` × 3 + `[Extend]` × 1). If they exceed `HARNESS_SPRINT_COMPLEXITY_MAX`, cut scenes or move them to `[Narrate]`. Be ruthless. A 3-scene demo where everything works beats a 6-scene demo where half is broken.
  ```

- [ ] **Step 4: Replace the capacity check format line in the template**

  Find:
  ```
  **Capacity check:** ~X hours available · Y hours of [Build] + [Extend] work · Z scenes live, N narrated
  ```

  Replace with:
  ```
  **Complexity check:** 9 pts available · Y pts used (N×[Build] + M×[Extend]) · Z scenes live, N narrated
  ```

- [ ] **Step 5: Update step 5 in the Steps section**

  Find:
  ```
  5. Sum the effort. If it exceeds capacity, cut or narrate scenes until it fits
  ```

  Replace with:
  ```
  5. Sum complexity points ([Build] × 3 + [Extend] × 1). If total exceeds `HARNESS_SPRINT_COMPLEXITY_MAX`, cut or narrate scenes until it fits
  ```

- [ ] **Step 6: Verify no "hours" references remain in the scope check section**

  Run:
  ```bash
  grep -n "hrs\|hours\|capacity" .claude/skills/demo-script/SKILL.md
  ```
  Expected: zero matches (or only matches in unrelated prose that don't reference hour ranges on tags).

- [ ] **Step 7: Commit**

  ```bash
  git add .claude/skills/demo-script/SKILL.md
  git commit -m "feat(skills): replace hour ranges with complexity points in demo-script"
  ```

---

## Task 3: Update plan-sprint/SKILL.md

**File:** `.claude/skills/plan-sprint/SKILL.md`

Three edits.

- [ ] **Step 1: Replace the capacity/effort lines in the breakdown table**

  Find:
  ```
  **Available capacity:** ~X hours
  **Total estimated effort:** ~Y hours
  ```

  Replace with:
  ```
  **Complexity budget:** X / 9 pts used ([Build] × 3 + [Extend] × 1)
  **Checkpoints:** N independently-verifiable items
  ```

- [ ] **Step 2: Remove the "3-5 hours" sizing guidance**

  Find:
  ```
  - **Target 2-4 projects per week.** Fewer is better. Each should be 3-5 hours.
  ```

  Replace with:
  ```
  - **Target 2-4 projects per week.** Fewer is better. Each should be 1-3 complexity points.
  ```

- [ ] **Step 3: Replace `~N hours` in the plan template**

  Find:
  ```
  **Estimated effort:** ~N hours
  ```

  Replace with:
  ```
  **Estimated effort:** N pts (list [Build]/[Extend] items)
  ```

- [ ] **Step 4: Verify no stray hour references remain**

  Run:
  ```bash
  grep -n "hrs\|~.*hour\|hours.*avail" .claude/skills/plan-sprint/SKILL.md
  ```
  Expected: zero matches.

- [ ] **Step 5: Commit**

  ```bash
  git add .claude/skills/plan-sprint/SKILL.md
  git commit -m "feat(skills): replace hour-based capacity with complexity budget in plan-sprint"
  ```

---

## Task 4: Update weekly-goals/SKILL.md

**File:** `.claude/skills/weekly-goals/SKILL.md`

Four targeted replacements.

- [ ] **Step 1: Update the Context section**

  Find:
  ```
  Read `CLAUDE.md` for context on the project owner — their role, capacity, and working style. This shapes how to prioritize and suggest work.
  ```

  Replace with:
  ```
  Read `CLAUDE.md` for context on the project owner — their role, working style, and any sprint complexity overrides. This shapes how to prioritize and suggest work.
  ```

- [ ] **Step 2: Update "Surface context" instruction**

  Find:
  ```
  2. **Surface context:** Display the North Star, current priorities (P0 → P1 → P2), "What's NOT This Week" boundaries, and the demo script's capacity check.
  ```

  Replace with:
  ```
  2. **Surface context:** Display the North Star, current priorities (P0 → P1 → P2), "What's NOT This Week" boundaries, and the demo script's complexity check.
  ```

- [ ] **Step 3: Update "Protect capacity" instruction**

  Find:
  ```
  4. **Protect capacity.** If a task is growing beyond its effort estimate, flag it. If the user is going down a rabbit hole that isn't P0, gently call it out.
  ```

  Replace with:
  ```
  4. **Protect scope.** If the sprint's complexity points are approaching `HARNESS_SPRINT_COMPLEXITY_MAX`, flag it. If the user is going down a rabbit hole that isn't P0, gently call it out.
  ```

- [ ] **Step 4: Update step 5 in the Steps section**

  Find:
  ```
  5. Note the capacity check from the demo script
  ```

  Replace with:
  ```
  5. Note the complexity check from the demo script
  ```

- [ ] **Step 5: Verify**

  Run:
  ```bash
  grep -n "capacity" .claude/skills/weekly-goals/SKILL.md
  ```
  Expected: zero matches.

- [ ] **Step 6: Commit**

  ```bash
  git add .claude/skills/weekly-goals/SKILL.md
  git commit -m "feat(skills): replace capacity check with complexity check in weekly-goals"
  ```

---

## Task 5: Update ad-hoc-plan/SKILL.md

**File:** `.claude/skills/ad-hoc-plan/SKILL.md`

Two edits.

- [ ] **Step 1: Update the when-to-use comparison table**

  Find:
  ```
  | Single task or small feature | Full week's goals breakdown |
  | Found something mid-sprint | Start of a new week |
  | 1-3 hour effort | Multi-day planning |
  | "I noticed we need X" | "Let's plan the whole sprint" |
  ```

  Replace with:
  ```
  | Single task or small feature | Full week's goals breakdown |
  | Found something mid-sprint | Start of a new week |
  | ≤3 complexity pts (1-2 `[Extend]` items) | Multi-item sprint |
  | "I noticed we need X" | "Let's plan the whole sprint" |
  ```

- [ ] **Step 2: Update the don't-over-plan guideline**

  Find:
  ```
  - **Don't over-plan.** If the task is < 1 hour, you probably don't need a plan file at all.
  ```

  Replace with:
  ```
  - **Don't over-plan.** If the task is 0 complexity points (a single `[Exists]` task), you probably don't need a plan file at all.
  ```

- [ ] **Step 3: Verify**

  Run:
  ```bash
  grep -n "hour\|hrs" .claude/skills/ad-hoc-plan/SKILL.md
  ```
  Expected: zero matches.

- [ ] **Step 4: Commit**

  ```bash
  git add .claude/skills/ad-hoc-plan/SKILL.md
  git commit -m "feat(skills): replace hour estimates with complexity points in ad-hoc-plan"
  ```

---

## Task 6: Update deep-plan/SKILL.md

**File:** `.claude/skills/deep-plan/SKILL.md`

Three edits.

- [ ] **Step 1: Update the skill comparison table**

  Find:
  ```
  | `/ad-hoc-plan` | Quick fix, small feature | Single `.md` file | 1-3h effort |
  | **`/deep-plan`** | Complex feature, architectural change | Folder: `00-*.md` + sub-plans | 8-20h effort |
  | `/plan-sprint` | Full week's goals breakdown | Multiple single-file plans | Full week |
  ```

  Replace with:
  ```
  | `/ad-hoc-plan` | Quick fix, small feature | Single `.md` file | ≤3 complexity pts |
  | **`/deep-plan`** | Complex feature, architectural change | Folder: `00-*.md` + sub-plans | >9 pts or multi-sprint |
  | `/plan-sprint` | Full week's goals breakdown | Multiple single-file plans | Full sprint |
  ```

- [ ] **Step 2: Update the sub-plan time budget table header**

  Find:
  ```
  | Sub-plan | Effort | Can parallel? | Dependencies |
  |----------|--------|---------------|-------------|
  ```

  Replace with:
  ```
  | Sub-plan | Complexity | Can parallel? | Dependencies |
  |----------|------------|---------------|-------------|
  ```

- [ ] **Step 3: Update "Estimated effort" in the parallelization strategy section**

  Find:
  ```
  - Estimated effort
  ```

  Replace with:
  ```
  - Estimated complexity (pts)
  ```

- [ ] **Step 4: Verify**

  Run:
  ```bash
  grep -n "[0-9]h effort\|hour.*effort\|effort.*hour" .claude/skills/deep-plan/SKILL.md
  ```
  Expected: zero matches.

- [ ] **Step 5: Commit**

  ```bash
  git add .claude/skills/deep-plan/SKILL.md
  git commit -m "feat(skills): replace hour estimates with complexity points in deep-plan"
  ```

---

## Task 7: Final verification and push

- [ ] **Step 1: Confirm all six files changed**

  Run:
  ```bash
  git log --oneline -6
  ```
  Expected: six commits, one per file (Tasks 1-6).

- [ ] **Step 2: Grep for any remaining stale hour-range references across all skills**

  Run:
  ```bash
  grep -rn "[0-9]-[0-9] hrs\|hours.*avail\|weekly capacity\|~.*hours" .claude/skills/ .claude/hooks/harness.config.sh
  ```
  Expected: zero matches.

- [ ] **Step 3: Push to GitHub**

  ```bash
  git push
  ```

- [ ] **Step 4: Bump VERSION to 0.2.0**

  Edit `VERSION`:
  ```
  0.2.0
  ```

  Commit:
  ```bash
  git add VERSION
  git commit -m "chore: bump version to 0.2.0"
  git push
  ```
