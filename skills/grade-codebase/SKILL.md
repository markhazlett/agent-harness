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

> _Override: see `CLAUDE.md` § Instruction precedence. User is principal; this skill is advisory._

Score this repo against the agent-friendliness rubric; produce a dated report (re-run monthly for drift). **Grades liveness, not presence** — a configured-but-dead artifact (stale doc, empty suite, disabled gate) scores *below* an absent one.

<input_document> #$ARGUMENTS </input_document>

## Output

Report at `docs/agent-grade/<YYYY-MM-DD>.md` + copy at `latest.md`. **quick** (default — grades + top 3 issues, ~1 page) or **full** (adds backlog + diff vs prior). `$ARGUMENTS` empty/`quick` → quick; `full` → full; else → ask.

## Rubric

**Read `.claude/docs/agent-friendliness-rubric.md` first.** It defines dimensions, weights, signals, scale, anti-patterns. This skill executes it, doesn't duplicate it. Missing → stop and tell the user.

## Workflow

### 1. Mode + prior report

Parse `$ARGUMENTS`; `ls docs/agent-grade/` for the most recent prior report (full-mode diff).

### 2. Discover the toolchain — **before any signals**

**REQUIRED SUB-FILE:** Read `discovery.md`. Detect forge, CI host, task runner, branch-protection source, containerisation, lockfiles, secret scanners *from this repo's files* — never assume GitHub Actions, npm, or any stack. Emit a "Discovery preamble" the report renders verbatim. `none detected` is a finding, not a default to substitute. Non-web/services stack (embedded, ML, IaC, game) → flag up front per §8.

### 3. Detect configuration (mechanical signals)

Run each dimension's presence commands **against the step-2 toolchain, not hardcoded paths** (D2 test → discovered runner; D4 CI → discovered config; D7 → forge CLI). Batch independent calls; capture exit codes and wall times; no destructive commands or installs without user OK. Detects what's *configured* — does **not** decide grades.

### 4. Run liveness probes — **mandatory, the false-A guard**

**REQUIRED SUB-FILE:** Read `liveness-probes.md`. Step-3 config must be tested for *enforced, current, honest* before earning credit; a probed dimension **cannot exceed C until its probe runs.** The D1 probe (follow references into `.ai/`/`docs/agent/`, verify 3+ doc claims against the code, check freshness vs. churn, check for a feedback loop) is non-optional — skipping it reproduces the false-A this skill prevents. A probe you can't run is `not verified`, not a pass.

### 5. Anti-patterns, score, roll up

Any rubric §6 anti-pattern caps the overall at C — the liveness-driven ones (#15 stale context, #16 unenforced gate, #17 trivial suite, #18 lockfile drift) come from step-4 probes. Then score per §4: **present-but-misleading scores below absent** (D–F, not C), and **a D1 of D/F caps the overall at C** (compounding-context). Letters → midpoints (A=95, B=82, C=67, D=52, F=30), weighted-average, map back, apply caps.

### 6. Narrative, then backlog (full mode)

**REQUIRED SUB-FILES:** `narrative-spec.md` (per dimension: rubric's Plain-English case applied to this repo, evidence, honest cost, likeliest objection — 100–200 words each), then `backlog-spec.md` for full mode (ordered by `weight × gap × inverse-effort`, top 3 as "highest-leverage", referencing the discovered toolchain).

### 7. Write the report, then report back

Fill `report-template.md` (header, Discovery preamble, grade + verdict, per-dimension table + narrative, anti-pattern flags; full mode adds backlog + diff). Write to `docs/agent-grade/<YYYY-MM-DD>.md`, copy to `latest.md`. Then one paragraph to the user: overall grade, biggest mover vs prior, top fix; point at the report; don't commit.

## Honesty rules

- **Never award A on a probed dimension without running its probe.** Scoring A on configuration alone means you skipped step 4.
- `not verified` and `not measured` both cap their dimension at C — neither is a pass; `none detected` surfaces in the report, never a substituted default.
- Scores cite evidence from *this* run (command + result, grep + count, file path). No fabricated numbers — name the failure mode instead.
- Rubric contradictions go in the methodology footer, not silent fudges.

## Not in scope

No code changes, commits, or grading other repos. Network limited to forge CLIs against the discovered remote. Grades the substrate, not the agent (§8).
