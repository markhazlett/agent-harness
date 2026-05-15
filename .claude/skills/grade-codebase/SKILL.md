---
name: grade-codebase
description: Use when the user says "/grade-codebase", "grade this codebase", "how agent-friendly is this repo", "score the codebase", or wants a longitudinal measure of how well an LLM coding agent can work in this codebase.
user-invocable: true
tier: flexible
kind: process
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Run `/harness-update` to pull it in." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Grade Codebase

Score this repository against the agent-friendliness rubric and produce a dated report. Designed to be re-run monthly so the user can see drift or improvement, and pointed at by other agents as a source of cleanup tasks.

<input_document> #$ARGUMENTS </input_document>

## What this skill produces

A markdown report at `docs/agent-grade/<YYYY-MM-DD>.md` plus a copy at `docs/agent-grade/latest.md` (so other skills / agents can find the most recent grade without globbing). Two modes:

- **quick** (default) — overall grade, per-dimension grades, top 3 issues, ~1 page. Use when re-running monthly to track drift.
- **full** — quick output **plus** prioritized backlog of fix-tasks and a diff against the previous report (if one exists). Use the first time, or when planning a cleanup sprint.

Mode comes from `$ARGUMENTS`: empty or `quick` → quick; `full` → full. Anything else → ask.

## Authoritative rubric

**Always read `.claude/docs/agent-friendliness-rubric.md` first.** It defines the eight dimensions, weights, signals (with concrete shell commands), grading scale, anti-patterns, and backlog hints. This skill does not duplicate the rubric — it executes it. If the rubric file is missing, stop and tell the user — do not grade without it.

## Workflow

### 1. Confirm mode and check for prior report

- Parse `$ARGUMENTS` for mode. Default to `quick`.
- `ls docs/agent-grade/` to find the most recent prior report (if any). Note its date for the diff.

### 2. Detect the stack

Before running signals, identify what kind of repo this is — the rubric has domain bias notes (§8). Look for: `package.json`, `pyproject.toml` / `requirements*.txt`, `go.mod`, `Cargo.toml`, `Gemfile`, `pom.xml` / `build.gradle*`, `*.csproj`, `flake.nix`, `Dockerfile`. Note the primary language and any monorepo signals (workspaces, lerna, nx, turbo, pnpm-workspace, cargo workspace).

If the stack is outside web/services (e.g., embedded, CUDA/ML training, Terraform-only, game engine), say so up front and flag which signals don't translate cleanly. Don't fake-grade them.

### 3. Run mechanical signals (parallel where possible)

For each dimension in the rubric, run the commands listed in its "Mechanical" column. Batch independent shell calls into a single tool message. Capture exit codes, command runtimes (for D2 — the rubric requires test/lint wall-time), and file existence checks. Don't run anything destructive; don't `npm install` unless the user authorized it.

Specifically:

- **D1 onboarding** — `test -f` for AGENTS.md / CLAUDE.md, `wc -l`, section-header grep, placeholder grep.
- **D2 build/test/lint** — read scripts from `package.json` / `Makefile` / `pyproject.toml`; **try** the canonical test command with a tight timeout (60–120s); record exit code + wall time. If running tests is risky or slow, ask before invoking.
- **D3 navigability** — strict-mode greps, file-size distribution, wildcard-import grep, sample 3–5 symbols and count definitions.
- **D4 gates** — read `.github/workflows/`, `.pre-commit-config.yaml`, lint configs.
- **D5 failure honesty** — grep for bare excepts / empty catches; sample a few error sites.
- **D6 reproducibility** — lockfile existence, runtime-pin files, Dockerfile, `.env.example`.
- **D7 change-safety** — `gh api` for branch protection (if available — skip silently if not), snapshot-test glob, recent-commit-size from `git log --shortstat -50`.
- **D8 conventions** — file-casing histogram, helper-consolidation grep, tests-alongside-code check.

### 4. Apply judgment signals

For the "Judgment" column (rubric §5), sample real files and make a call. Be specific: cite the file path you sampled. Judgment signals contribute at most 50% of a dimension's score (rubric §5).

### 5. Check anti-patterns / red flags (rubric §6)

If any of the ten anti-patterns fires, the overall grade caps at C. Surface which one and where.

### 6. Score and roll up

- Per-dimension letter using rubric §4 ("Per-dimension scoring rubric").
- Convert letters to midpoints (A=95, B=82, C=67, D=52, F=30), weighted-average, map back.
- Apply the C-cap if a red flag fired.

### 7. Write the report

Use the template in `report-template.md` (sibling file). Always include:

- Header (date, commit SHA from `git rev-parse --short HEAD`, branch, mode, stack notes).
- Overall grade + one-sentence verdict from the rubric's plain-English scale.
- Per-dimension table: dimension, weight, letter, the 2–3 signals that drove the letter.
- Anti-pattern flags (if any).

**Full mode adds:**

- **Backlog** — concrete fix-tasks, ordered by leverage (weight × gap-from-A). Each task: title, dimension, estimated effort (S/M/L), and a one-line "agent could do this" handoff line.
- **Diff vs previous** — per-dimension letter change, new red flags, resolved red flags. Skip silently if no prior report.

Write to `docs/agent-grade/<YYYY-MM-DD>.md`, then copy to `docs/agent-grade/latest.md`. Create the directory if missing.

### 8. Report back to the user

One paragraph: overall grade, the dimension that moved most (vs prior), and the single highest-leverage fix. Point at the report file. Don't commit — the user decides whether to.

## Honesty rules

- If a signal can't be measured (no `gh` CLI for branch protection, no test command at all), say "not measured" — do not score it as if it passed.
- If you ran a destructive-looking command, name it explicitly in the report.
- Judgment scores must cite the file you sampled. "Names are honest" without a path is not a score.
- If the rubric file looks stale or self-contradicts on a signal, flag it in the report's "methodology notes" footer rather than silently fudging.

## What this skill does NOT do

- Does not modify the codebase. No fixes, no PRs.
- Does not commit. The report is an artifact the user reviews and chooses to commit.
- Does not grade other repos via network. Operates on the current working directory only.
- Does not eval an *agent's* performance on this codebase — it grades the substrate. See rubric §8 "Eval gap" for the distinction.
