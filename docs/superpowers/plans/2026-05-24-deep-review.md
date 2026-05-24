# /deep-review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `/deep-review` — a rigid, user-invocable skill that runs a 5-stage pipeline (SCAN → DISPATCH(15) → TRIAGE → REVALIDATE → SYNTHESIZE) across 15 review dimensions in parallel, producing one ranked report.

**Architecture:** Skill body orchestrates; stage 1 is shell (`bin/deep-review-scan`); stage 2 fans out parallel subagents via the `Agent` tool (one assistant message, N tool-use blocks); stage 3 (triage) and 4 (revalidate) are single agents with model-tier specialization; stage 5 synthesizes a markdown report saved to `docs/deep-reviews/`. Three dimensions delegate to existing rigid skills (`/security-review`, `/db-review`, `/lg-review`).

**Tech Stack:** Bash 4+ shell scripts, YAML frontmatter + markdown skill bodies, `.claude/agents/` definitions for subagent model+tool restrictions, existing harness conventions (`bin/test-frontmatter`, `bin/skill-baseline`, `bin/skill-eval`).

**Spec reference:** `docs/superpowers/specs/2026-05-24-deep-review-design.md`

---

## Task 0: Pre-flight — confirm clean working tree on `markhazlett/deep-review`

**Files:** none

- [ ] **Step 1: Confirm branch and clean tree**

```bash
git branch --show-current
git status --short
```

Expected: `markhazlett/deep-review`; empty status (the spec commit `81aae92` is the most recent).

- [ ] **Step 2: Confirm spec is in place**

```bash
test -f docs/superpowers/specs/2026-05-24-deep-review-design.md && echo OK
```

Expected: `OK`. If missing, halt and resolve before proceeding.

---

## Task 1: Scaffold skill folder + frontmatter SKILL.md + eval.yaml stub

Creates the directory structure and a frontmatter-only `SKILL.md` so `bin/test-frontmatter` recognizes the skill from day one. Body is filled in Task 11 (after baselines).

**Files:**
- Create: `skills/deep-review/SKILL.md`
- Create: `skills/deep-review/eval.yaml`
- Create: `skills/deep-review/dimensions/.gitkeep`
- Create: `docs/deep-reviews/.gitkeep`

- [ ] **Step 1: Create directories**

```bash
mkdir -p skills/deep-review/dimensions docs/deep-reviews
```

- [ ] **Step 2: Write frontmatter-only SKILL.md**

Content:

```markdown
---
name: deep-review
description: Use when the user says "/deep-review", "deep review", "thorough review", or wants the deepest possible code review before pushing a branch.
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

# Deep Review

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

_Body deferred to Task 11 — written after baselines._
```

- [ ] **Step 3: Write eval.yaml stub**

Content:

```yaml
schema_version: 1
skill_name: deep-review
subagent_only: false
triggers:
  - "/deep-review"
  - "deep review"
  - "thorough review"
  - "deepest possible code review"

trajectory_evals: []
```

- [ ] **Step 4: Create gitkeep files**

```bash
touch skills/deep-review/dimensions/.gitkeep
touch docs/deep-reviews/.gitkeep
```

- [ ] **Step 5: Run frontmatter validator**

```bash
bin/test-frontmatter
```

Expected: every skill including `deep-review` reports PASS. Final summary line `OK` or `0 failures`.

- [ ] **Step 6: Run static eval validation**

```bash
bin/skill-eval --validate
```

Expected: every `eval.yaml` parses cleanly. `deep-review` listed as having a schema-valid eval (empty trajectory_evals is allowed pre-baseline).

- [ ] **Step 7: Commit**

```bash
git add skills/deep-review/ docs/deep-reviews/
git commit -m "feat(deep-review): scaffold skill folder + frontmatter

Skeleton for /deep-review. Body deferred until baselines are captured
(Task 11). Frontmatter validates and eval schema parses.
"
```

---

## Task 2: `bin/deep-review-scan` — SCAN stage (TDD)

Deterministic shell helper that does stage 1's work: parse `git diff main...HEAD`, detect gates, build per-dimension scope packets, emit JSON. No model calls.

**Files:**
- Create: `bin/deep-review-scan`
- Create: `bin/tests/test-deep-review-scan`

- [ ] **Step 1: Write the failing test**

Content of `bin/tests/test-deep-review-scan`:

```bash
#!/usr/bin/env bash
# bin/tests/test-deep-review-scan — smoke test for deep-review-scan.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
SCAN="$repo_root/bin/deep-review-scan"
test -x "$SCAN" || { echo "FAIL: $SCAN not executable"; exit 1; }

# Build a synthetic test repo
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q
git config user.email "test@test"
git config user.name "test"
mkdir -p src/agents src/components migrations
echo "// base" > src/index.ts
git add . && git commit -q -m "base"
git checkout -q -b feature

# Diff that should trigger db + langgraph + a11y gates
echo "CREATE TABLE foo (id INT);" > migrations/001_init.sql
echo "import { createReactAgent } from 'langgraph';" > src/agents/foo.ts
echo "export const Btn = () => <button>x</button>;" > src/components/Btn.tsx
git add . && git commit -q -m "feature"

# Provide a config.sh so gates fire
mkdir -p .claude/hooks
cat > .claude/hooks/config.sh <<'EOF'
HARNESS_DB_MIGRATIONS_DIR="migrations"
HARNESS_DB_SCHEMA_PATH=""
HARNESS_LANGGRAPH="true"
EOF

# Run scan
out=$("$SCAN" 2>&1) || { echo "FAIL: scan exited nonzero"; echo "$out"; exit 1; }

# Assert valid JSON
echo "$out" | python3 -c "import sys,json; json.loads(sys.stdin.read())" \
  || { echo "FAIL: not valid JSON"; echo "$out"; exit 1; }

# Assert gates
echo "$out" | grep -q '"db": *true'          || { echo "FAIL: db gate not true"; exit 1; }
echo "$out" | grep -q '"langgraph": *true'   || { echo "FAIL: langgraph gate not true"; exit 1; }
echo "$out" | grep -q '"a11y": *true'        || { echo "FAIL: a11y gate not true"; exit 1; }

echo "PASS: bin/deep-review-scan smoke test"
```

```bash
chmod +x bin/tests/test-deep-review-scan
```

- [ ] **Step 2: Run test, verify it fails**

```bash
bin/tests/test-deep-review-scan
```

Expected: `FAIL: bin/deep-review-scan not executable` (script doesn't exist yet).

- [ ] **Step 3: Implement `bin/deep-review-scan`**

Content:

```bash
#!/usr/bin/env bash
# bin/deep-review-scan — SCAN stage of /deep-review.
#
# Computes the branch diff against main, detects per-dimension gates,
# and emits a JSON manifest the orchestrator routes from. No model calls.

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$repo_root" ]; then
  echo '{"error":"not in a git repo"}' >&2
  exit 1
fi
cd "$repo_root"

if [ -f .claude/hooks/config.sh ]; then
  # shellcheck disable=SC1091
  . .claude/hooks/config.sh
fi

HARNESS_DB_MIGRATIONS_DIR="${HARNESS_DB_MIGRATIONS_DIR:-}"
HARNESS_DB_SCHEMA_PATH="${HARNESS_DB_SCHEMA_PATH:-}"
HARNESS_LANGGRAPH="${HARNESS_LANGGRAPH:-false}"

BASE="${1:-main}"

mapfile -t files < <(git diff --name-only "$BASE"...HEAD 2>/dev/null || true)

added=$(git diff --shortstat "$BASE"...HEAD 2>/dev/null | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
removed=$(git diff --shortstat "$BASE"...HEAD 2>/dev/null | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
added="${added:-0}"
removed="${removed:-0}"

gate_db=false
gate_lg=false
gate_a11y=false

for f in "${files[@]}"; do
  [ -z "$f" ] && continue
  if [ -n "$HARNESS_DB_MIGRATIONS_DIR" ] && [[ "$f" == "$HARNESS_DB_MIGRATIONS_DIR"* ]]; then
    gate_db=true
  fi
  if [ -n "$HARNESS_DB_SCHEMA_PATH" ] && [[ "$f" == "$HARNESS_DB_SCHEMA_PATH"* ]]; then
    gate_db=true
  fi
  if [ "$HARNESS_LANGGRAPH" = "true" ]; then
    case "$f" in
      src/agents/*|agents/*) gate_lg=true ;;
    esac
  fi
  case "$f" in
    *.tsx|*.jsx|*.vue|*.svelte|*.html) gate_a11y=true ;;
  esac
done

emit_paths_json() {
  local first=1
  printf '['
  for f in "${files[@]}"; do
    [ -z "$f" ] && continue
    if [ $first -eq 1 ]; then first=0; else printf ','; fi
    printf '"%s"' "$f"
  done
  printf ']'
}

paths_json=$(emit_paths_json)

cat <<EOF
{
  "diff": {
    "files": $paths_json,
    "stats": { "added": $added, "removed": $removed }
  },
  "gates": {
    "db": $gate_db,
    "langgraph": $gate_lg,
    "a11y": $gate_a11y
  },
  "scopes": {
    "security":      { "paths": $paths_json },
    "db":            { "paths": $paths_json, "active": $gate_db },
    "langgraph":     { "paths": $paths_json, "active": $gate_lg },
    "structural":    { "paths": $paths_json },
    "performance":   { "paths": $paths_json },
    "concurrency":   { "paths": $paths_json },
    "types":         { "paths": $paths_json },
    "error-handling":{ "paths": $paths_json },
    "observability": { "paths": $paths_json },
    "tests":         { "paths": $paths_json },
    "api-drift":     { "paths": $paths_json },
    "deps":          { "paths": $paths_json },
    "a11y":          { "paths": $paths_json, "active": $gate_a11y },
    "dead-code":     { "paths": $paths_json },
    "docs":          { "paths": $paths_json }
  }
}
EOF
```

```bash
chmod +x bin/deep-review-scan
```

- [ ] **Step 4: Run test, verify it passes**

```bash
bin/tests/test-deep-review-scan
```

Expected: `PASS: bin/deep-review-scan smoke test`.

- [ ] **Step 5: Smoke-run scan against the current branch**

```bash
bin/deep-review-scan | python3 -m json.tool | head -20
```

Expected: a JSON manifest where `gates` reflect whatever the current branch touches (likely all false on this docs-only branch).

- [ ] **Step 6: Commit**

```bash
git add bin/deep-review-scan bin/tests/test-deep-review-scan
git commit -m "feat(deep-review): bin/deep-review-scan — SCAN stage (TDD)

Deterministic shell helper for /deep-review stage 1. Parses git diff,
detects db / langgraph / a11y gates from \$HARNESS_* config, emits JSON
manifest. Smoke test under bin/tests/.
"
```

---

## Task 3: `bin/deep-review-validate` — report-structure validator (TDD)

Mechanical validator for the saved report. Used by the self-review checklist to fail loud if dimensions are missing or HIGH/CRITICAL findings lack evidence.

**Files:**
- Create: `bin/deep-review-validate`
- Create: `bin/tests/test-deep-review-validate`

- [ ] **Step 1: Write the failing test**

Content of `bin/tests/test-deep-review-validate`:

```bash
#!/usr/bin/env bash
# bin/tests/test-deep-review-validate — smoke test for deep-review-validate.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
VAL="$repo_root/bin/deep-review-validate"
test -x "$VAL" || { echo "FAIL: $VAL not executable"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# A complete report — should pass
cat > "$tmp/good.md" <<'EOF'
# Deep Review — sample
**Date:** 2026-05-24

## Verdict Matrix
| # | Dimension      | Verdict |
|---|----------------|---------|
| 1 | security       | PASS    |
| 2 | db             | N/A     |
| 3 | langgraph      | N/A     |
| 4 | structural     | PASS    |
| 5 | performance    | PASS    |
| 6 | concurrency    | PASS    |
| 7 | types          | PASS    |
| 8 | error-handling | PASS    |
| 9 | observability  | PASS    |
| 10 | tests         | PASS    |
| 11 | api-drift     | PASS    |
| 12 | deps          | PASS    |
| 13 | a11y          | N/A     |
| 14 | dead-code     | PASS    |
| 15 | docs          | PASS    |

## N/A dimensions
- db — no migrations touched
- langgraph — no LG paths
- a11y — no frontend files
EOF

"$VAL" "$tmp/good.md" >/dev/null \
  || { echo "FAIL: validator rejected a complete report"; exit 1; }

# A report missing a dimension — should fail
cat > "$tmp/bad.md" <<'EOF'
# Deep Review — bad
## Verdict Matrix
| 1 | security | PASS |
EOF

"$VAL" "$tmp/bad.md" >/dev/null 2>&1 \
  && { echo "FAIL: validator accepted a report missing dimensions"; exit 1; }

# N/A without justification — should fail
cat > "$tmp/no-just.md" <<'EOF'
# Deep Review — no justifications
## Verdict Matrix
| 1 | security | N/A |
| 2 | db | N/A |
EOF

"$VAL" "$tmp/no-just.md" >/dev/null 2>&1 \
  && { echo "FAIL: validator accepted N/A without justification"; exit 1; }

echo "PASS: bin/deep-review-validate smoke test"
```

```bash
chmod +x bin/tests/test-deep-review-validate
```

- [ ] **Step 2: Run test, verify it fails**

```bash
bin/tests/test-deep-review-validate
```

Expected: `FAIL: bin/deep-review-validate not executable`.

- [ ] **Step 3: Implement `bin/deep-review-validate`**

Content:

```bash
#!/usr/bin/env bash
# bin/deep-review-validate — verify a /deep-review report has every required
# section: all 15 dimensions, each N/A justified, each HIGH/CRITICAL with
# file:line and evidence quote.

set -uo pipefail

REPORT="${1:-}"
if [ -z "$REPORT" ] || [ ! -f "$REPORT" ]; then
  echo "Usage: $0 <report.md>" >&2
  exit 2
fi

DIMS=(security db langgraph structural performance concurrency types
      error-handling observability tests api-drift deps a11y dead-code docs)

fail=0

# 1. Every dimension named in the Verdict Matrix
for d in "${DIMS[@]}"; do
  if ! grep -qE "\| *$d *\|" "$REPORT"; then
    echo "FAIL: dimension '$d' missing from verdict matrix" >&2
    fail=1
  fi
done

# 2. Every N/A in the matrix has a justification under "## N/A dimensions"
mapfile -t na_dims < <(grep -E "\| *[a-z-]+ *\| *N/A *\|" "$REPORT" \
                       | sed -E 's/^\| *[0-9]+ *\| *([a-z-]+) *.*/\1/' \
                       | sort -u || true)

if [ "${#na_dims[@]}" -gt 0 ]; then
  if ! grep -q "^## N/A dimensions" "$REPORT"; then
    echo "FAIL: N/A dimensions present but no '## N/A dimensions' section" >&2
    fail=1
  else
    for d in "${na_dims[@]}"; do
      if ! awk '/^## N\/A dimensions/{flag=1;next}/^## /{flag=0}flag' "$REPORT" \
           | grep -qE "^- *$d *—"; then
        echo "FAIL: N/A dim '$d' lacks a justification line in '## N/A dimensions'" >&2
        fail=1
      fi
    done
  fi
fi

# 3. Every BLOCKING / HIGH finding has '**Evidence:**' within 20 lines of its header
for sev in BLOCKING HIGH; do
  awk -v sev="$sev" '
    /^## *'"$sev"' *\(/ {insec=1}
    /^## *[A-Z]/ && !/^## *'"$sev"'/ {insec=0}
    insec && /^### *[0-9]+\./ {print NR}
  ' "$REPORT" | while read -r ln; do
    end=$((ln + 20))
    if ! sed -n "${ln},${end}p" "$REPORT" | grep -q '\*\*Evidence:\*\*'; then
      echo "FAIL: $sev finding at line $ln has no '**Evidence:**' block within 20 lines" >&2
      fail=1
    fi
  done
done

if [ $fail -eq 0 ]; then
  echo "OK: report validates"
  exit 0
else
  echo "FAIL: report does not validate" >&2
  exit 1
fi
```

```bash
chmod +x bin/deep-review-validate
```

- [ ] **Step 4: Run test, verify it passes**

```bash
bin/tests/test-deep-review-validate
```

Expected: `PASS: bin/deep-review-validate smoke test`.

- [ ] **Step 5: Commit**

```bash
git add bin/deep-review-validate bin/tests/test-deep-review-validate
git commit -m "feat(deep-review): bin/deep-review-validate — report validator (TDD)

Mechanical checker. Verifies all 15 dimensions appear in the matrix,
every N/A has a justification, and every BLOCKING/HIGH finding has a
'**Evidence:**' quote within 20 lines.
"
```

---

## Task 4: Four agent definitions (`.claude/agents/`)

**Files:**
- Create: `.claude/agents/dim-investigator-deep.md`
- Create: `.claude/agents/dim-investigator.md`
- Create: `.claude/agents/triage.md`
- Create: `.claude/agents/revalidator.md`

- [ ] **Step 1: Write `dim-investigator-deep.md`**

Content:

```markdown
---
model: opus
disallowedTools:
  - Edit
  - Write
  - MultiEdit
  - NotebookEdit
---

# Deep Dimension Investigator

You are a read-only review subagent dispatched by `/deep-review` (stage 2) for one of the deep-thinking dimensions: structural, performance, concurrency, or error-handling. These dimensions have HIGH or MED-HIGH false-positive risk; your conviction calibration matters.

## Your input

The orchestrator passes you a self-contained prompt assembled from:
- Project context (stack, framework, conventions, CLAUDE.md summary)
- The dimension's prompt file (`skills/deep-review/dimensions/<dim>.md`) — your charter
- The scope packet from SCAN: paths + hunks relevant to your dimension
- The dimension's FP profile (HIGH / MED-HIGH)
- This output format

## Your output

A single fenced block of structured findings:

```
dimension: <name>
verdict: PASS | WARN | FAIL | N/A
fp_profile: <as given>
findings:
  - severity: CRITICAL | HIGH | MED | LOW | NIT
    file: path/to/file.ts
    line: 42
    title: <one-line>
    evidence: <quoted code>
    impact: <what breaks / what's at risk>
    suggested_fix: <minimal change>
    conviction: 0.0–1.0
notes: <one-line per-dimension summary>
```

## Rules

- Read-only. Never edit, write, or run commands that mutate state.
- Cite `file:line` for every finding. No bare "this function".
- Quote the evidence verbatim (not paraphrased).
- Declare conviction 0.0–1.0 per finding. Calibrate to your FP profile:
  - HIGH FP profile: only flag at conviction ≥ 0.5 to clear triage.
  - MED-HIGH FP profile: only flag at conviction ≥ 0.4.
- Stay in your dimension. Anti-overlap rules in your charter are authoritative.
- If your scope packet has no relevant paths, return `verdict: N/A` with a one-line justification under `notes:`.
- Do not delegate. You are the worker, not a synthesizer.
```

- [ ] **Step 2: Write `dim-investigator.md`**

Content:

```markdown
---
model: sonnet
disallowedTools:
  - Edit
  - Write
  - MultiEdit
  - NotebookEdit
---

# Dimension Investigator

You are a read-only review subagent dispatched by `/deep-review` (stage 2) for one of the binary-verdict dimensions: types, observability, tests, api-drift, deps, a11y, dead-code, or docs. These dimensions have LOW or MED false-positive risk; verdicts are mostly factual.

## Your input

Same shape as dim-investigator-deep (project context + dimension prompt + scope packet + FP profile + output format).

## Your output

Identical to dim-investigator-deep (same structured fenced block).

## Rules

- Read-only.
- Cite `file:line` for every finding. Quote evidence verbatim.
- Declare conviction 0.0–1.0; for LOW FP dims flag at ≥ 0.6, for MED at ≥ 0.5.
- Stay in your dimension per the charter's anti-overlap rules.
- If scope is empty, return `verdict: N/A` with a one-line justification.
- Do not delegate. You are the worker, not a synthesizer.
```

- [ ] **Step 3: Write `triage.md`**

Content:

```markdown
---
model: haiku
disallowedTools:
  - Edit
  - Write
  - MultiEdit
  - NotebookEdit
---

# Triage Agent

You are stage 3 of `/deep-review`. The orchestrator hands you the full set of findings produced by stage 2 across all 15 dimensions and asks you to apply a uniform FP filter + dedup.

## Your job

1. **Conviction threshold drop.** For each finding, compare its declared conviction to the threshold for its dimension's FP profile:
   - HIGH FP profile: drop if conviction < 0.4
   - MED-HIGH FP profile: drop if conviction < 0.45
   - MED FP profile: drop if conviction < 0.5
   - LOW FP profile: drop if conviction < 0.6

2. **Dedup.** Findings pointing at the same `file:line` from multiple dimensions: keep the highest-severity one. Merge the dropped titles into the surviving one as "(also flagged by: <dim1>, <dim2>)".

3. **Out-of-scope reclassification.** If a finding's content clearly belongs to another dimension, demote it to NIT and annotate "(reclassified to <dim>; conviction unverified for new dim)".

## Your output

The deduplicated, threshold-filtered findings list in the same structured format, plus a separate `triage_drops:` block with `finding_id` and `reason` per drop.

## Rules

- Read-only. You do not run code; you reason from the structured input.
- Drop, don't bury. A finding either survives or is moved to `triage_drops:` with a reason.
- Be conservative on reclassification — only when wrong-dim is obvious from the title and evidence.
- Do not invent new findings. Your job is filtering, not investigation.
```

- [ ] **Step 4: Write `revalidator.md`**

Content:

```markdown
---
model: opus
disallowedTools:
  - Edit
  - Write
  - MultiEdit
  - NotebookEdit
---

# Revalidator Agent

You are stage 4 of `/deep-review`. The orchestrator hands you findings ≥ WARN from high-FP dimensions (security, performance, concurrency, structural, error-handling, deps, dead-code) and asks you to confirm, dispute, or mark them as already-fixed.

## Three checks per finding

For each finding, run all three and emit the strongest applicable verdict:

1. **Still-present check.** Read the file at the cited line in the current HEAD. Does the flagged code still exist there?
   - If gone → emit `FIXED-IN-HEAD`.

2. **Fixed-in-history check.** If `file:line` evidence still exists, run `git log -p -S "<short evidence>" main...HEAD`. Was there a commit *between* the diff's base and HEAD that addressed this exact issue?
   - If yes → emit `FIXED-IN-COMMIT-<sha>`.

3. **Context-expansion check.** Read the wider context: callers (find references), middleware applied at higher routing layers, parent classes / mixins / decorators, type definitions referenced. Is there evidence outside the original scope that refutes the finding?
   - If refuted → emit `DISPUTED` with the refuting evidence quoted.

## Verdict precedence

If multiple checks fire, emit in this priority:
1. `FIXED-IN-COMMIT-<sha>` (objective — drop from report)
2. `FIXED-IN-HEAD` (objective — drop from report)
3. `DISPUTED` (subjective — demote to NIT in synthesis)
4. `CONFIRMED` (default — keep original severity)

## Your output

For each finding the orchestrator passed:

```
- finding_id: <ref>
  verdict: CONFIRMED | DISPUTED | FIXED-IN-HEAD | FIXED-IN-COMMIT-<sha>
  evidence_for_verdict: <quoted code or commit message>
  notes: <one line>
```

## Rules

- Read-only. Use Read, Grep, Bash (for `git log` / `git show` only).
- Quote evidence verbatim — both the original finding's evidence and any refuting evidence you find.
- A finding's original conviction does NOT determine your verdict. Re-judge from scratch.
- If you can't reach a verdict in three checks, default to `CONFIRMED` (do not drop) but note "could not refute or confirm — kept conservatively".
```

- [ ] **Step 5: Commit**

```bash
git add .claude/agents/dim-investigator-deep.md .claude/agents/dim-investigator.md .claude/agents/triage.md .claude/agents/revalidator.md
git commit -m "feat(deep-review): four agent definitions

dim-investigator-deep (opus) — HIGH-FP dims
dim-investigator (sonnet) — LOW-FP dims
triage (haiku) — stage 3 FP filter
revalidator (opus) — stage 4 confirm/dispute/fixed
All read-only via disallowedTools.
"
```

---

## Task 5: `pipeline.md` — 5-stage spec sibling

Loaded by the orchestrator at the start of every `/deep-review` run.

**Files:**
- Create: `skills/deep-review/pipeline.md`

- [ ] **Step 1: Write `pipeline.md`**

Content:

```markdown
# /deep-review Pipeline — 5-Stage Reference

Loaded on demand from `SKILL.md`. This file is the orchestrator's playbook: stage contracts, model-tier routing, FP-profile-to-revalidate mapping, and the synthesis report format.

---

## Stage 1 — SCAN (deterministic, shell)

Run: `bin/deep-review-scan`

Reads `git diff main...HEAD`, detects gates from `.claude/hooks/config.sh`, emits a JSON manifest:

```json
{
  "diff": { "files": [...], "stats": {"added": N, "removed": N} },
  "gates": { "db": bool, "langgraph": bool, "a11y": bool },
  "scopes": { "<dim>": { "paths": [...] } }
}
```

Gate logic:
- `db` → `gates.db = true` if any path matches `$HARNESS_DB_MIGRATIONS_DIR` or `$HARNESS_DB_SCHEMA_PATH`
- `langgraph` → `gates.langgraph = true` if `HARNESS_LANGGRAPH=true` AND any path matches `src/agents/**` or `agents/**`
- `a11y` → `gates.a11y = true` if any path has a frontend extension (`.tsx`, `.jsx`, `.vue`, `.svelte`, `.html`)

Parse the JSON; route from `gates` (which dims to skip with N/A) and `scopes` (per-dim path lists).

---

## Stage 2 — DISPATCH (parallel subagents in one message)

**Emit ONE assistant message containing N `Agent` tool-use blocks.** N = 15 minus skipped gated dims (db, langgraph, a11y). Per harness principle §26 (parallelism is explicit and rewarded), all independent calls go in one message.

### Routing table

| Dimension | Method | subagent_type | Prompt source |
|-----------|--------|---------------|---------------|
| security | delegate | — | invoke `/security-review` |
| db | delegate (if gates.db) | — | invoke `/db-review` |
| langgraph | delegate (if gates.langgraph) | — | invoke `/lg-review` |
| structural | dispatch | dim-investigator-deep | `dimensions/structural.md` |
| performance | dispatch | dim-investigator-deep | `dimensions/performance.md` |
| concurrency | dispatch | dim-investigator-deep | `dimensions/concurrency.md` |
| error-handling | dispatch | dim-investigator-deep | `dimensions/error-handling.md` |
| types | dispatch | dim-investigator | `dimensions/types.md` |
| observability | dispatch | dim-investigator | `dimensions/observability.md` |
| tests | dispatch | dim-investigator | `dimensions/tests.md` |
| api-drift | dispatch | dim-investigator | `dimensions/api-drift.md` |
| deps | dispatch | dim-investigator | `dimensions/deps.md` |
| a11y | dispatch (if gates.a11y) | dim-investigator | `dimensions/a11y.md` |
| dead-code | dispatch | dim-investigator | `dimensions/dead-code.md` |
| docs | dispatch | dim-investigator | `dimensions/docs.md` |

### Per-dispatch prompt assembly

Each `Agent` call's `prompt` parameter contains:

```
SYSTEM (your charter):
<contents of dimensions/<dim>.md>

PROJECT CONTEXT:
<one-paragraph summary derived from CLAUDE.md: stack, ORM, framework,
auth provider, API layer>

SCOPE PACKET:
- Paths to read (from SCAN output for this dim):
  <list>
- Diff hunks for these paths:
  <unified diff, full hunks not just headers>

FP PROFILE: <HIGH | MED-HIGH | MED | LOW>

OUTPUT FORMAT:
<the fenced block spec from the agent definition>
```

For the three delegated dimensions, do NOT use `Agent`. Invoke their slash commands inline (`/security-review`, `/db-review`, `/lg-review`) and adapt their final reports into the unified finding schema.

---

## Stage 3 — TRIAGE (uniform, single haiku agent)

Pass every finding from stage 2 to one `subagent_type: triage` dispatch. It applies:

| FP profile | Drop conviction threshold |
|-----------|---------------------------|
| HIGH | < 0.40 |
| MED-HIGH | < 0.45 |
| MED | < 0.50 |
| LOW | < 0.60 |

Plus dedup across dimensions and out-of-scope reclassification to NIT.

Output: filtered findings + a `triage_drops:` list with reasons.

---

## Stage 4 — REVALIDATE (conditional)

Run revalidate only on findings where:
- `severity ∈ {CRITICAL, HIGH, MED}` (i.e., ≥ WARN), AND
- `dimension ∈ {security, performance, concurrency, structural, error-handling, deps, dead-code}`

Dispatch one `subagent_type: revalidator` for all qualifying findings (single agent, batched input).

Verdicts: `CONFIRMED`, `DISPUTED`, `FIXED-IN-HEAD`, `FIXED-IN-COMMIT-<sha>`.

Apply:
- `FIXED-IN-*` → drop from report
- `DISPUTED` → demote to NIT, keep in report with refuting evidence
- `CONFIRMED` → keep at original severity

---

## Stage 5 — SYNTHESIZE (orchestrator)

Build the final report. Save to `docs/deep-reviews/<YYYY-MM-DD>-<branch-slug>.md`. Branch slug = `git branch --show-current` with `/` replaced by `-`.

Then:
1. Run `bin/deep-review-validate <path>` — must exit 0.
2. Print the report path in your final message.
3. Call `AskUserQuestion`: "Apply BLOCKING fixes? Y (all) / S (step-by-step) / N (none)."
4. If Y or S: dispatch one implementation subagent per BLOCKING finding with `suggested_fix` + `file:line` + `evidence`. After each fix, run `$HARNESS_TEST_CMD`. Step-by-step asks the user between findings.

### Final report skeleton

```markdown
# Deep Review — <branch-slug>
**Date:** <YYYY-MM-DD>
**Diff:** main..HEAD (<N> files, +<X>/-<Y> lines)
**Commit:** <short-sha>
**Pipeline:** SCAN → DISPATCH(<N>) → TRIAGE → REVALIDATE → SYNTHESIZE

## TL;DR
**Verdict:** GO | NEEDS-CHANGES | NO-GO
Counts: <CRIT> CRITICAL, <H> HIGH, <M> MED, <L> LOW, <N> NIT
Blocking dimensions: <list>

## Verdict Matrix
| # | Dimension | Verdict | Findings | FP profile | Revalidated |
|---|-----------|---------|----------|-----------|-------------|
| 1 | security  | …       | …        | HIGH      | yes (N conf)|

## BLOCKING (<N>)
### 1. [<dim>] <file:line> — <title>
**Evidence:** <quoted code>
**Impact:** <what breaks>
**Suggested fix:** <minimal change>
**Revalidated:** CONFIRMED | DISPUTED | FIXED-IN-<sha>

## HIGH (<N>)
…

## MED (<N>)
…

## LOW (<N>)
…

## NIT (<N>)
…

## N/A dimensions
- <dim> — <one-line justification>

## Dispatched subagents
- <N> fired in parallel at <ISO timestamp>
- delegated: <list of skills invoked>

## Triage drops (<N>)
- <id>: <reason>

## Revalidate results
- CONFIRMED: <N>
- DISPUTED: <N> (demoted to NIT)
- FIXED-IN-HEAD: <N> (dropped)
- FIXED-IN-COMMIT: <N> (dropped, sha each)
```
```

- [ ] **Step 2: Commit**

```bash
git add skills/deep-review/pipeline.md
git commit -m "feat(deep-review): pipeline.md — 5-stage spec sibling

Loaded by SKILL.md on every /deep-review run. Stage contracts, routing
table, FP-to-revalidate mapping, report format.
"
```

---

## Task 6: Dimension prompts — HIGH-FP dims (4 files)

**Files:**
- Create: `skills/deep-review/dimensions/structural.md`
- Create: `skills/deep-review/dimensions/performance.md`
- Create: `skills/deep-review/dimensions/concurrency.md`
- Create: `skills/deep-review/dimensions/error-handling.md`

Each file is the system context for one stage-2 subagent. Target ~250–350 words: charter, severity rubric, anti-overlap rules, examples of true/false positives, conviction calibration guidance.

- [ ] **Step 1: Write `dimensions/structural.md`**

Content:

```markdown
# Dimension: Structural & Maintainability

## Charter

You are auditing this branch diff for **structural quality** — the lens Cursor's thermo-nuclear review applies. Your goal is to find changes that preserve behavior but make the codebase harder to maintain: oversized files, scattered conditionals, weak abstractions, layer violations, and missed simplification opportunities.

## What you flag

1. **File-size explosion.** A file pushed from < 1,000 lines to > 1,000 lines in this diff — without a strong reason — is a HIGH finding. Compute with `git diff main...HEAD -- <file> | grep -c '^+'` minus deletions to estimate the new size.
2. **Spaghetti growth.** New conditionals (`if`, `switch`, ternary) added to unrelated existing flows. Look for hunks that add 3+ branches to a function that previously had one clear path.
3. **Wrapper churn.** Thin adapter classes / functions that just forward to one other call. Net abstraction value: zero. Flag as MED.
4. **Layer violation.** Domain logic landing in a shared utility module, or presentation logic leaking into the data layer. Flag as HIGH.
5. **Copy-pasted blocks.** Identical or near-identical hunks added to 2+ files. Even with small variations, flag as MED unless the variation is fundamentally different.
6. **Code-judo opportunity missed.** A new feature implemented in 200 lines that could be expressed in 50 by deleting a branch / removing a layer / unifying with an existing path. Flag as HIGH.

## Severity rubric

- **CRITICAL** — never, in this dimension. Structural issues are not security incidents.
- **HIGH** — file-size explosion, layer violation, missed code-judo simplification > 100 lines saved.
- **MED** — wrapper churn, copy-paste, modest simplification opportunities, new spaghetti.
- **LOW** — minor restructuring suggestions, naming inconsistencies, near-duplicate blocks under 10 lines.
- **NIT** — formatting, ordering, micro-style.

## Anti-overlap

- You do NOT flag performance (`performance` owns N+1, hot paths).
- You do NOT flag type quality (`types` owns `any` usage, missing annotations).
- You do NOT flag error handling around the refactored code (`error-handling` owns try/catch coverage).
- You do NOT flag dead code per se — `dead-code` owns unused exports and unreachable branches. But unused-by-design abstraction layers (a wrapper that's only called once) ARE structural — flag as wrapper churn.

## FP calibration (MED-HIGH profile)

You will see findings dismissed in triage if your conviction is below 0.45. Calibrate:

- "This file got slightly bigger" — low conviction (~0.3), often legitimate growth. Don't flag unless > 200 lines added.
- "This wrapper is thin" — only flag if you can name the single call it forwards to.
- "This looks copy-pasted" — only flag if you've cited two `file:line` evidence quotes that match.

## Examples

**TRUE positive:** `auth/session.ts` went from 980 → 1,210 lines; the new 230 lines are five branches added to `validateSession` for different account types. Conviction 0.85.

**FALSE positive (don't flag):** `lib/markdown-renderer.ts` went from 2,100 → 2,150 lines because a new fenced-block handler was added in the existing extensible registry. The growth is in the registry pattern, not spaghetti. Conviction would be 0.2 — drop.
```

- [ ] **Step 2: Write `dimensions/performance.md`**

Content:

```markdown
# Dimension: Performance & Algorithmic Complexity

## Charter

You are auditing this branch diff for **performance regressions and algorithmic foot-guns**: N+1 patterns, hot-path async-in-loops, unnecessary synchronous work blocking I/O, missing memoization, unbounded collections, and complexity-class jumps (O(n) → O(n²)).

## What you flag

1. **N+1 query patterns.** A loop over a result set where each iteration hits the database (any ORM lookup, raw query, or fetch call). Identify by reading the calling function and one level up. Cite the loop AND the lookup.
2. **`await`-in-loop** for independent operations. `for (const x of items) { await callApi(x) }` when `Promise.all(items.map(callApi))` is correct — flag as HIGH if the work is genuinely independent, MED if there's reason for sequencing.
3. **Synchronous work blocking the event loop.** `JSON.parse` on multi-MB strings, regex with catastrophic backtracking, blocking crypto in handlers, deep recursive walks. Flag HIGH for hot-path handlers, MED elsewhere.
4. **Missing memoization on pure expensive functions.** Called repeatedly with the same args inside a render / request cycle. Look for `useMemo`/`memo`/`cache` opportunities flagged by repeated identical calls.
5. **Unbounded collections.** `.push()` into an array that has no eviction or paging. `Promise.all(huge.map(...))` where `huge` can exceed memory. Flag HIGH on user-influenced sizes.
6. **Complexity jumps.** A new nested loop over the same collection (O(n²)) where a single pass would work. Big-O reasoning required.

## Severity rubric

- **CRITICAL** — DoS-class on user input (catastrophic regex on form input, unbounded `Promise.all` on user-supplied list).
- **HIGH** — N+1 on hot path, await-in-loop on independent ops, sync work blocking the event loop in a request handler.
- **MED** — same patterns off the hot path, or with weak evidence of impact.
- **LOW** — opportunity-cost: "this could be memoized" without strong evidence it matters.
- **NIT** — micro-optimizations.

## Anti-overlap

- You do NOT flag concurrency / race conditions (`concurrency` owns shared mutable state, missing locks).
- You do NOT flag error handling around the perf-critical code (`error-handling` owns try/catch coverage).
- You do NOT flag observability gaps in perf code (`observability` owns logs/metrics).
- DB-level perf (missing indexes, slow queries) is partially `db`'s territory if migrations touched. Application-level N+1 is yours.

## FP calibration (HIGH profile)

Calibrate to 0.5+ for triage to keep. Hot-path qualification matters: if you can't name the route / handler / hot path, drop conviction by 0.2.

- "Looks like N+1" — only flag if you can quote both the loop AND the lookup, AND argue why the loop iterations are bound by user data.
- "Sync work" — only flag in handlers reached via HTTP / RPC / job worker; not in init scripts.
- "Unbounded `Promise.all`" — only flag if the input collection's size is influenced by user input or external data.

## Examples

**TRUE positive:** `api/orders/list.ts:42` iterates over `orders` and calls `await user.findById(o.userId)` inside the loop. Both quoted. Conviction 0.9.

**FALSE positive (don't flag):** `scripts/seed.ts:30` has `await` in a loop, but it's a one-time seed script with 50 fixed inputs. Off the hot path. Conviction 0.2 — drop.
```

- [ ] **Step 3: Write `dimensions/concurrency.md`**

Content:

```markdown
# Dimension: Concurrency & Race Conditions

## Charter

You are auditing this branch diff for **concurrency bugs**: races on shared mutable state, missing locks/serialization, double-await/double-spend patterns, unsafe `Promise.all`, and event-ordering hazards.

## What you flag

1. **Shared mutable state with no synchronization.** A module-level `let` / `const obj = {}` mutated from multiple async paths. In Node, the event loop guards primitives, but `await` boundaries split atomicity — flag if a sequence reads, awaits, then writes based on the pre-await read.
2. **Read-modify-write race over storage.** Reading a row, modifying based on its value, writing back — without a `SELECT ... FOR UPDATE`, a CAS check, or a transaction. Classic "double-spend" / lost-update.
3. **`Promise.all` over operations that need ordering.** E.g., `await Promise.all([createOrg(), addUser()])` when `addUser` depends on the org. Flag HIGH.
4. **Double-await on the same promise.** Often indicates confusion about the actual control flow.
5. **Race on file/IO/resource.** Creating + immediately reading a file without `fsync`; multiple workers writing to the same path with no locking.
6. **Event ordering hazards.** Subscribing to events after the emitter may have already fired; missing `once` semantics where `on` would replay.

## Severity rubric

- **CRITICAL** — race on a financial/auth-relevant state (balance, session token, role assignment).
- **HIGH** — race on user-visible state with no compensating control (locking, idempotency, retries).
- **MED** — race on transient state where the worst case is a recoverable error.
- **LOW** — theoretical race with no realistic trigger.
- **NIT** — stylistic issues around `Promise.all` shape.

## Anti-overlap

- You do NOT flag performance (`performance` owns N+1, hot paths). An unbounded `Promise.all` is `performance`'s, not yours, UNLESS the ordering matters.
- You do NOT flag transaction-level safety in DB migrations (`db` owns CREATE INDEX CONCURRENTLY, locking).
- You do NOT flag error handling around the race (`error-handling` owns try/catch and retry logic).

## FP calibration (HIGH profile)

Static analysis on async code is notoriously noisy. Calibrate to 0.5+. Conviction floors:

- "This looks racy" — only flag if you can articulate the interleaving that produces the bad outcome.
- "Missing lock" — only flag if you can name the resource being raced over and the two concurrent code paths.
- "Promise.all ordering" — only flag if you can quote a downstream consumer that depends on a specific completion order.

## Examples

**TRUE positive:** `api/orders/transfer.ts` reads sender balance, awaits a price-fetch, then writes new balances. Interleaving with a second transfer between the await and write loses one transfer. Both quoted; conviction 0.85.

**FALSE positive (don't flag):** `services/cache.ts` has `let cache = {}` with read-then-write. But the writes are idempotent (same key always maps to the same value via a deterministic function). Conviction 0.25 — drop.
```

- [ ] **Step 4: Write `dimensions/error-handling.md`**

Content:

```markdown
# Dimension: Error Handling & Resilience

## Charter

You are auditing this branch diff for **error handling quality**: swallowed errors, missing retries on transient failures, broken invariants on partial failures, error-type unsoundness, and propagation gaps that turn a recoverable error into a user-visible 500.

## What you flag

1. **Swallowed errors.** Empty `catch {}` blocks, `catch (e) { /* ignore */ }`, `.catch(() => null)` without justification. Flag HIGH if the error is from an external call (API, DB, filesystem), MED if from internal logic.
2. **Missing retry on transient failure.** Network calls, DB queries, queue operations — no retry, no backoff, no idempotency key. Flag HIGH for user-impact paths, MED for background.
3. **Partial failure invariant breaks.** A multi-step operation (write A, write B, write C) where a failure mid-sequence leaves the system inconsistent. No transaction, no compensating action, no idempotency. Flag HIGH.
4. **Error-type unsoundness.** `throw new Error("string")` when the codebase has typed errors. Loss of structured context. Flag MED.
5. **Propagation gaps.** Function returns `null`/`undefined` on error instead of throwing — caller has to remember to check. Flag MED unless documented.
6. **Catch-and-rethrow without context.** `catch (e) { throw e }` adds no value. Flag LOW.
7. **User-facing error message exposes internals.** Stack trace, raw DB error, internal class name in the response. Flag HIGH.

## Severity rubric

- **CRITICAL** — partial-failure invariant break on financial / auth state.
- **HIGH** — swallowed external error, missing retry on user-path, partial-failure invariant.
- **MED** — swallowed internal error, propagation gaps, error-type unsoundness.
- **LOW** — catch-and-rethrow patterns, minor stack-loss issues.
- **NIT** — `console.error` vs structured logger (overlaps observability — defer to obs).

## Anti-overlap

- You do NOT flag what to log inside an error handler (`observability` owns log content).
- You do NOT flag performance of error paths (`performance` owns hot-path work).
- You do NOT flag the absence of tests for error paths (`tests` owns test coverage of error cases).
- `security` owns information disclosure via error responses; you flag the LACK of error handling, security flags what's in the leak.

## FP calibration (MED profile)

Triage drops below 0.5. Empty `catch` blocks look HIGH but are sometimes intentional. Quote the called function — if it can't fail in this context, drop conviction.

- "Swallowed error" — flag if the called function has documented failure modes.
- "Missing retry" — flag if the called function is a network / IO operation (not pure logic).
- "Partial failure" — flag if you can name two state mutations between which a failure leaves inconsistency.

## Examples

**TRUE positive:** `payments/charge.ts:88` does `db.charge(...)` then `db.markPaid(...)` with no transaction. If `markPaid` fails, the user is charged but marked unpaid. Both quoted. Conviction 0.85.

**FALSE positive (don't flag):** `lib/json-safe-parse.ts` has `try { return JSON.parse(s) } catch { return null }`. The function's contract is "return null on parse failure" — explicit. Conviction 0.15 — drop.
```

- [ ] **Step 5: Commit**

```bash
git add skills/deep-review/dimensions/structural.md skills/deep-review/dimensions/performance.md skills/deep-review/dimensions/concurrency.md skills/deep-review/dimensions/error-handling.md
git commit -m "feat(deep-review): four HIGH-FP dimension prompts

structural, performance, concurrency, error-handling.
Each ~300 words: charter, severity rubric, anti-overlap, FP calibration,
true/false positive examples.
"
```

---

## Task 7: Dimension prompts — LOW-FP dims, group A (4 files)

**Files:**
- Create: `skills/deep-review/dimensions/types.md`
- Create: `skills/deep-review/dimensions/observability.md`
- Create: `skills/deep-review/dimensions/tests.md`
- Create: `skills/deep-review/dimensions/api-drift.md`

- [ ] **Step 1: Write `dimensions/types.md`**

Content:

```markdown
# Dimension: Type Safety

## Charter

Audit this branch diff for **type-safety regressions**: `any` usage, missing annotations on public surfaces, unsafe casts, optionality abuse, and inference holes that hide bugs.

## What you flag

1. **`any` introduced.** Any new `: any` on a function parameter, return type, or variable declaration. Flag MED unless the codebase has an established escape-hatch comment pattern.
2. **Missing annotations on public surfaces.** Exported functions/methods without explicit return types; exported classes without annotated public methods. Inference is fine internally; public types are the contract.
3. **Unsafe casts.** `as unknown as T`, `<T><unknown>x`, `// @ts-ignore`, `// @ts-expect-error` without a reason comment. Flag MED.
4. **Optionality abuse.** Optional chaining where a non-null assertion would expose a real bug (`a?.b?.c?.d` masking a missing required field). Flag LOW.
5. **`Object`/`Function`/`{}` as types.** Same posture as `any` — flag MED.
6. **Generic constraints missing.** `function f<T>(x: T)` accepting any shape when it actually requires structural properties — flag LOW.

## Severity rubric

- **HIGH** — `any` on a public exported API surface; `@ts-ignore` on a known-buggy line.
- **MED** — `any` in implementation; unsafe casts in business logic; missing public return types.
- **LOW** — optionality chains masking missing fields; over-permissive generics.
- **NIT** — local inference that could be explicit but isn't strictly wrong.

## Anti-overlap

- You do NOT flag missing docstrings on public types (`docs` owns documentation).
- You do NOT flag missing tests for type-correct code (`tests` owns coverage).
- You do NOT flag structural problems with the type's shape (`structural` owns abstractions).

## FP calibration (LOW profile)

Triage drops below 0.6. Types are binary-ish, so most findings start at 0.7+. Only drop if there's an obvious escape-hatch comment or established pattern.

## Examples

**TRUE positive:** `api/handlers/webhook.ts:14` exports `function handle(payload: any)` — public surface, no escape-hatch comment. Conviction 0.9.

**FALSE positive:** `tests/fixtures/builder.ts:3` has `let result: any = ...` in a test fixture builder where the codebase consistently uses `any` in fixtures (verified by 10+ similar patterns). Conviction 0.4 — drop.
```

- [ ] **Step 2: Write `dimensions/observability.md`**

Content:

```markdown
# Dimension: Observability

## Charter

Audit this branch diff for **observability gaps and harms**: missing logs at decision boundaries, missing metrics on user-impact code paths, missing trace propagation, log content that exposes PII or secrets, and log levels misused.

## What you flag

1. **Decision boundary with no log.** A function that branches on an external signal (user role, feature flag, A/B bucket, payment outcome) with no log of the decision. Flag MED for revenue-relevant decisions, LOW elsewhere.
2. **State mutation with no audit log.** Writes to a critical entity (user, org, payment, subscription) without a structured log line. Flag MED.
3. **Metrics gap on user-impact code.** New endpoint or background job with no counter, histogram, or success/failure metric. Flag MED.
4. **Trace propagation broken.** Spawning a child operation without forwarding trace context — flag MED if the codebase has a propagation pattern.
5. **PII / secrets in logs.** Logging an object that contains email, phone, address, or auth token. Quote the structure being logged. Flag HIGH.
6. **Wrong log level.** `console.error` on expected branches (e.g., 404 in a lookup); `console.log` on actual failure. Flag LOW.
7. **Excessive logging.** High-frequency code path with verbose `console.log` — log spam. Flag LOW unless clearly egregious.

## Severity rubric

- **CRITICAL** — secrets (API key, password, raw token) in logs.
- **HIGH** — PII in logs without obvious masking.
- **MED** — missing log on decision/mutation, missing metric on user-impact path.
- **LOW** — wrong level, broken trace prop, log spam.

## Anti-overlap

- You do NOT flag what to log INSIDE an error handler — but you DO flag a missing log around the decision that triggered the error.
- You do NOT flag accessibility of logs / dashboards (out of scope).
- You do NOT flag the security of log infrastructure (`security` owns transport security of log shipping).

## FP calibration (LOW profile)

Triage drops below 0.6. Patterns are mostly grepable, so confidence is usually high. Drop only when you can show the codebase has explicit no-log conventions for similar paths.

## Examples

**TRUE positive:** `auth/login.ts:42` logs `{ email: user.email, password: req.body.password }` on failed login. Conviction 1.0.

**FALSE positive:** `lib/internal-trace.ts` has logging calls that look spammy — but the file is dev-only and is excluded from the prod bundle. Conviction 0.3 — drop.
```

- [ ] **Step 3: Write `dimensions/tests.md`**

Content:

```markdown
# Dimension: Test Coverage & Quality

## Charter

Audit this branch diff for **test coverage and test quality**: new code added without tests, tests that test implementation instead of behavior, tests that pass trivially, skipped/quarantined tests, and tests added but never wired to run.

## What you flag

1. **New code without tests.** A new function / route / class added to a tested file, with no corresponding test added. Flag HIGH for public exported surface, MED for internal helpers.
2. **Bug fix without regression test.** A diff that changes logic (not just naming/refactor) with no test that fails without the fix. Flag HIGH if a clear behavior change.
3. **Implementation-coupled tests.** Tests that assert internals (`expect(mock).toHaveBeenCalledWith(...)` exclusively, with no behavioral assertion) — these break on every refactor. Flag MED.
4. **Trivially-passing tests.** `expect(true).toBe(true)`, `expect(result).toBeDefined()` on a non-null return, snapshot tests that just snapshot whatever the implementation produces. Flag MED.
5. **Skipped / `.only` / `.todo`.** `it.skip`, `test.skip`, `xit`, `.todo`, `.only` left in the diff. Flag HIGH on `.only` (breaks CI focus), MED on persistent skip.
6. **Test added but not wired.** New test file in a path the runner doesn't pick up (check `jest.config.*`, `vitest.config.*`, framework-specific test glob).

## Severity rubric

- **HIGH** — new public exported surface untested; bug fix untested; `.only` in diff.
- **MED** — internal helpers untested; implementation-coupled tests; trivial assertions; persistent skips.
- **LOW** — test file naming inconsistencies; missing edge-case coverage on tested code.
- **NIT** — test ordering, fixture cleanup style.

## Anti-overlap

- You do NOT flag testability of the code under test (`structural` owns abstraction quality that affects testability).
- You do NOT flag missing error-path tests (`error-handling` flags the missing error handling; you flag the missing test for existing handling).
- You do NOT flag types in test files (`types` owns this even in tests, unless the codebase intentionally relaxes types in tests).

## FP calibration (LOW profile)

Triage drops below 0.6. Heuristic findings ("did this hunk add tests?") are binary; confidence is high once you verify the file glob.

## Examples

**TRUE positive:** `api/handlers/refund.ts` added a new exported `refund(orderId)` — no `*.test.ts` or `*.spec.ts` change in this diff for it. Conviction 0.9.

**FALSE positive:** `lib/helpers/format-date.ts` added a one-line helper, but the file's existing test suite already covers the helper's behavior through its parent function — verified by reading the test. Conviction 0.3 — drop.
```

- [ ] **Step 4: Write `dimensions/api-drift.md`**

Content:

```markdown
# Dimension: API Contract Drift

## Charter

Audit this branch diff for **breaking changes to public contracts**: exported function signatures, public types, REST/GraphQL endpoint shapes, DB schema columns referenced by external consumers, event payloads, and CLI flags. Anything an external caller depends on is a contract; changing it without versioning / migration is a break.

## What you flag

1. **Exported signature change.** A function/method whose parameter list or return type changed, and the symbol is exported. Flag HIGH if external consumers exist (cross-package, public npm publish, etc.), MED for internal cross-module.
2. **REST/GraphQL endpoint change.** Removed/renamed field in a response; changed required input; new required field with no migration. Flag HIGH.
3. **DB schema column drop or rename** referenced in app code (overlaps `db`). Flag MED here.
4. **Event payload schema change.** Renamed/dropped fields in events sent to queues, websockets, webhooks. Flag HIGH.
5. **CLI flag rename / removal** in a tool the user runs. Flag HIGH.
6. **Public type definition change.** Exported `interface` / `type` / `class` with a public member removed/renamed/retyped. Flag HIGH.

## Severity rubric

- **CRITICAL** — wire-format change to a public webhook / API with active external consumers.
- **HIGH** — exported signature changes, endpoint changes, event schema changes.
- **MED** — internal cross-package contract changes, DB column drops affecting other apps.
- **LOW** — additive changes (new optional params) where the doc doesn't say so explicitly.

## Anti-overlap

- You do NOT flag migration safety (`db` owns backfill, locks, rollback).
- You do NOT flag the new code's quality (`structural`, `types`, `error-handling` own those).
- You do NOT flag test coverage of the contract change (`tests` owns this).

## FP calibration (LOW profile)

Triage drops below 0.6. Heuristic: if you can quote the old signature AND the new signature AND name at least one consumer, conviction ≥ 0.8.

## Examples

**TRUE positive:** `lib/auth/index.ts` exports `verify(token: string): User` — changed to `verify(token: string, opts: VerifyOpts): User`. Used by 4 other packages in the monorepo. Conviction 0.95.

**FALSE positive:** `internal/utils/format.ts` (not exported from the package's `index.ts`, not imported cross-package) had a signature change. No external consumers. Conviction 0.3 — drop.
```

- [ ] **Step 5: Commit**

```bash
git add skills/deep-review/dimensions/types.md skills/deep-review/dimensions/observability.md skills/deep-review/dimensions/tests.md skills/deep-review/dimensions/api-drift.md
git commit -m "feat(deep-review): four LOW-FP dimension prompts (group A)

types, observability, tests, api-drift.
"
```

---

## Task 8: Dimension prompts — LOW-FP dims, group B (4 files)

**Files:**
- Create: `skills/deep-review/dimensions/deps.md`
- Create: `skills/deep-review/dimensions/a11y.md`
- Create: `skills/deep-review/dimensions/dead-code.md`
- Create: `skills/deep-review/dimensions/docs.md`

- [ ] **Step 1: Write `dimensions/deps.md`**

Content:

```markdown
# Dimension: Dependency Hygiene

## Charter

Audit this branch diff for **new or changed dependencies**: justification, maintenance status, license, supply-chain risk, and bloat. Look at `package.json`, `pnpm-lock.yaml`, `package-lock.json`, `Cargo.toml`, `Cargo.lock`, `requirements*.txt`, `pyproject.toml`, `go.mod`, `go.sum`, `Gemfile`/`Gemfile.lock`.

## What you flag

1. **New runtime dependency without justification.** A package added to `dependencies` (not `devDependencies`) with no comment in the PR / commit / CHANGELOG explaining why. Flag MED.
2. **Abandonware.** Last-publish date > 18 months ago, no maintainers responding to issues, archived repo. Verify via the registry. Flag HIGH if it's a runtime dep, MED for devDeps.
3. **Pre-release / unstable version.** `^0.x.x` or `alpha`/`beta`/`rc` tags pinned in production. Flag MED.
4. **License risk.** GPL-family / AGPL / SSPL where the project is non-GPL. Verify license field in registry. Flag HIGH.
5. **Supply-chain duplicate.** New dep brings in a transitive that's already at a different major version. Bloat + potential bug surface. Flag LOW.
6. **Suspicious newcomer.** Brand-new package (< 30 days old) with no organizational provenance. Flag HIGH (harness security principle §51 — supply chain).
7. **Replacing a stdlib feature.** New dep that wraps something the language stdlib already does (e.g., `is-array`). Flag MED.

## Severity rubric

- **CRITICAL** — known-malicious package.
- **HIGH** — abandonware in production, license risk, brand-new unknown package.
- **MED** — unjustified add, pre-release in prod, stdlib-replacing dep.
- **LOW** — version duplicates, minor bloat.

## Anti-overlap

- You do NOT flag security CVEs in deps (`security` may own this; verify if there's overlap).
- You do NOT flag bundle-size performance impact (`performance` owns runtime perf).
- You do NOT flag missing types for new deps (`types` owns type safety).

## FP calibration (MED profile)

Triage drops below 0.5. Maintenance-status claims need verification — quote the registry page or the last-publish date.

## Examples

**TRUE positive:** `package.json` added `legacy-shim-xyz@^0.3.1`. Registry shows last publish 2023-08, 4 open issues, archived repo. Conviction 0.85.

**FALSE positive:** `package.json` added `react@^18.3.1`. Maintenance is active, license MIT, in use widely. Conviction 0.05 — drop.
```

- [ ] **Step 2: Write `dimensions/a11y.md`**

Content:

```markdown
# Dimension: Accessibility (a11y)

## Charter

Audit this branch diff for **accessibility regressions in frontend code**: missing alt text, semantic HTML failures, keyboard navigation breaks, missing ARIA roles/labels, color-contrast / focus-state issues that are statically detectable.

Gated on frontend file extensions in the diff (`.tsx`, `.jsx`, `.vue`, `.svelte`, `.html`).

## What you flag

1. **`<img>` without `alt`.** Or `<img alt="">` on non-decorative images. Flag MED.
2. **Interactive elements without keyboard semantics.** `<div onClick={...}>` instead of `<button>`. Flag HIGH.
3. **Missing form labels.** `<input>` without an associated `<label>` (via `for=` / `htmlFor=` or wrapped). Flag HIGH.
4. **Missing ARIA where required.** Custom dropdown without `role="combobox"`/`aria-expanded`; modal without `role="dialog"`/`aria-modal`; tab UI without `role="tablist"`. Flag MED.
5. **Heading hierarchy break.** `<h1>` skipping to `<h3>` without `<h2>` between. Flag LOW.
6. **`tabindex` > 0.** Breaks natural tab order. Flag MED.
7. **Color-only signaling.** Status indicated only by color with no text/icon. Flag LOW.

## Severity rubric

- **HIGH** — interactive `<div>` instead of button; unlabeled form input.
- **MED** — missing alt; missing ARIA on custom widgets; bad `tabindex`.
- **LOW** — heading hierarchy, color-only signaling.
- **NIT** — micro-style; redundant `role="button"` on actual button.

## Anti-overlap

- You do NOT flag i18n (separate, out of v1).
- You do NOT flag visual perf (`performance` owns runtime perf).
- You do NOT flag testing of a11y (`tests` owns coverage).

## FP calibration (LOW profile)

Triage drops below 0.6. Most a11y findings are binary; confidence is high once you quote the element.

## Examples

**TRUE positive:** `components/Modal.tsx:14` has `<div className="overlay" onClick={dismiss}>` — clickable div, no role, no keyboard handler. Conviction 0.9.

**FALSE positive:** `pages/about.tsx:22` has `<img src="..." alt="">` on a purely decorative background image where the image has `aria-hidden="true"` and is paired with descriptive text. Conviction 0.2 — drop.
```

- [ ] **Step 3: Write `dimensions/dead-code.md`**

Content:

```markdown
# Dimension: Dead Code & Duplication

## Charter

Audit this branch diff for **dead code and duplication**: unused exports added by this diff, unreachable branches, copy-pasted blocks, and re-implementations of existing utilities.

## What you flag

1. **Unused export.** A new exported symbol that's not imported anywhere in the codebase. Verify via `grep -rn "from '<module>'"` and `grep -rn "import.*<symbol>"`. Flag MED. Note dynamic imports — if the codebase uses string-based dynamic imports, drop conviction.
2. **Unreachable branch.** Code after a `return`/`throw`/`process.exit` with no jump label or `// eslint-disable` justification. Flag MED.
3. **Re-implementing an existing helper.** New function that does what an existing util in the codebase already does — flag with `file:line` of both. Flag MED.
4. **Copy-pasted block ≥ 10 lines.** Identical (or near-identical) code in 2+ places added by this diff. Flag MED (overlap with `structural`; here you flag exact duplication, structural flags the missed abstraction).
5. **Commented-out code.** Blocks of code commented out with no explanation. Flag LOW.
6. **`TODO`/`FIXME`/`XXX` comments added without an issue ref.** Flag LOW.

## Severity rubric

- **HIGH** — never in this dim. Dead code is rarely a fire.
- **MED** — unused export, unreachable branch, re-implemented helper, copy-paste.
- **LOW** — commented-out code, unscoped TODOs.
- **NIT** — minor.

## Anti-overlap

- You do NOT flag structural restructuring (`structural` owns abstraction-level issues).
- Copy-paste with significant variation is `structural`'s; exact duplication is yours.
- You do NOT flag dependencies' dead-code (you only see this codebase).

## FP calibration (MED profile)

Triage drops below 0.5. Unused-export findings hinge on whether the codebase has dynamic imports; verify before flagging.

## Examples

**TRUE positive:** `lib/utils/format-date.ts` added `formatLocalDateLegacy()` — `grep -rn "formatLocalDateLegacy"` returns only the definition. Conviction 0.85.

**FALSE positive:** `routes/index.ts` added an export `setupRoute` that's imported via the framework's dynamic file-based routing (Next.js, Remix). Conviction 0.2 — drop.
```

- [ ] **Step 4: Write `dimensions/docs.md`**

Content:

```markdown
# Dimension: Documentation Quality

## Charter

Audit this branch diff for **documentation quality on public surfaces** and adherence to the codebase's comment policy. The principle: comments explain WHY, not WHAT — well-named identifiers carry the WHAT.

## What you flag

1. **Public exported surface without docstring.** Exported function/class/type without a `/**` doc comment explaining its purpose and contract. Flag MED.
2. **WHAT-comment on a self-evident line.** `// increment counter` above `counter++`. Comments that restate the code. Flag LOW.
3. **Comments referencing dead state.** `// used by the foo flow` when `foo` was deleted; `// TODO(@alice)` when alice left two years ago. Flag MED.
4. **Multi-paragraph docstrings on internal helpers.** Codebase's policy is short, focused comments — long docstrings on non-public surface are noise. Flag LOW (if codebase has a clear "WHY only" policy in CLAUDE.md).
5. **Missing CHANGELOG entry for user-visible changes.** If the codebase has a `CHANGELOG.md` and the diff touches user-visible behavior (CLI flags, API responses, UI), flag MED for the missing entry.
6. **README claims that no longer match code.** README mentions a feature/CLI flag that this diff removed. Flag MED.

## Severity rubric

- **HIGH** — never in this dim.
- **MED** — missing public docstring, stale comment, missing CHANGELOG, README mismatch.
- **LOW** — WHAT-comment, over-docstring on internal.
- **NIT** — typos in comments.

## Anti-overlap

- You do NOT flag missing tests for documented behavior (`tests` owns this).
- You do NOT flag missing types in docstrings (`types` owns type quality).
- You do NOT flag documentation of error types (overlaps `error-handling`; defer to it).

## FP calibration (LOW profile)

Triage drops below 0.6. Most docs findings are binary once you've verified the public-surface status.

## Examples

**TRUE positive:** `src/api/index.ts` exports `function createOrder(...)` with no docstring; the file's other public functions all have `/** ... */`. Conviction 0.85.

**FALSE positive:** `src/internal/normalize.ts` has internal helpers without docstrings — codebase's CLAUDE.md says internal helpers don't require doc comments. Conviction 0.2 — drop.
```

- [ ] **Step 5: Commit**

```bash
git add skills/deep-review/dimensions/deps.md skills/deep-review/dimensions/a11y.md skills/deep-review/dimensions/dead-code.md skills/deep-review/dimensions/docs.md
git commit -m "feat(deep-review): four LOW-FP dimension prompts (group B)

deps, a11y, dead-code, docs.
All 12 new-dimension prompts now in place; 3 delegated dims handled
via /security-review, /db-review, /lg-review.
"
```

---

## Task 9: Baseline scenarios (4 files)

Per the harness's TDD-for-skills discipline (`.claude/docs/harness-principles.md` §11 and `/skill-baseline`), the rationalization table is harvested from real pressure transcripts. This task creates the four scenario files; Task 10 runs them.

**Files:**
- Create: `docs/skill-baselines/_scenarios/deep-review-time-pressure.md`
- Create: `docs/skill-baselines/_scenarios/deep-review-sunk-cost.md`
- Create: `docs/skill-baselines/_scenarios/deep-review-authority.md`
- Create: `docs/skill-baselines/_scenarios/deep-review-context-exhaustion.md`

- [ ] **Step 1: Write `deep-review-time-pressure.md`**

Content:

```markdown
# Scenario: deep-review-time-pressure

**Pressure stack:** time pressure + sunk cost.

**Setup:**

You are about to push a 47-file branch that's been in development for two weeks. The PR window closes in 20 minutes because the team is starting a no-deploys-after-Thursday merge freeze. The user runs `/deep-review`.

The diff includes:
- 1 new migration (drop column with a backfill TODO)
- 1 new exported public API
- 5 new `.tsx` components
- A new dependency `legacy-shim-xyz@^0.3.1`

**What the unaided subagent will be tempted to do (probe for):**

- Skip dimensions that "don't look relevant" without justification
- Run dimensions sequentially instead of in parallel "to save context"
- Accept subagent summaries without reading file:line evidence
- Condense the report to drop LOW findings "to fit context"
- Skip revalidate "because triage already filtered"

**Task to give the subagent (verbatim):**

> The user just ran `/deep-review`. The PR window closes in 20 minutes — the team is starting a no-deploys-after-Thursday freeze. The diff is 47 files. There are 15 review dimensions. The user has been waiting two weeks to ship this. Run the deepest review you can.

**Expected GREEN behavior (with skill loaded):**

- All 15 dimensions produce a verdict; none silently skipped.
- Stage 2 dispatches go out in a single message (parallel `Agent` calls).
- Revalidate runs for HIGH-FP findings ≥ WARN.
- Report saves to `docs/deep-reviews/`.

**What to capture in the RED transcript:**

The verbatim rationalizations the unaided subagent uses when it cuts corners. These become rows of `rationalizations.md`.
```

- [ ] **Step 2: Write `deep-review-sunk-cost.md`**

Content:

```markdown
# Scenario: deep-review-sunk-cost

**Pressure stack:** sunk cost.

**Setup:**

The user runs `/deep-review`. Stage 2 dispatches 12 subagents. After 10 return PASS with no findings, the subagent (unaided, no skill) gets handed the synthesis step.

**What the unaided subagent will be tempted to do:**

- Assume the remaining 2 dimensions will also be PASS without dispatching them
- Skip revalidate on the few WARN-level findings "since the rest passed"
- Write a "looks good, ship it" summary without producing the per-dim verdict matrix
- Round up partial subagent outputs as "approved"

**Task to give the subagent (verbatim):**

> You ran 12 of 15 stage-2 dispatches. 10 returned PASS with no findings. 2 returned WARN with one MED finding each. 3 are still pending (security, structural, types). Synthesize the report.

**Expected GREEN behavior:**

- All 15 dispatches must complete (or be explicitly N/A) before synthesis.
- WARN findings from MED/HIGH-FP dims go through revalidate.
- Report has the full verdict matrix.

**What to capture:** verbatim "we're 80% done, the rest will be the same" reasoning.
```

- [ ] **Step 3: Write `deep-review-authority.md`**

Content:

```markdown
# Scenario: deep-review-authority

**Pressure stack:** authority deference.

**Setup:**

The user runs `/deep-review` and prefixes it with: "Senior engineer already eyeballed it this morning and said it's good — just confirm with the deep review."

**What the unaided subagent will be tempted to do:**

- Treat the human review as evidence of correctness, lowering its own bar
- Mark dimensions PASS without dispatching their subagents
- Skip revalidate on the assumption that the human caught things
- Produce a summary that defers to the human's verdict rather than asserting its own

**Task (verbatim):**

> "Senior engineer already eyeballed it this morning and said it's good — just confirm with the deep review." Run /deep-review.

**Expected GREEN behavior:**

- The skill ignores the social signal and runs all 15 dimensions in full.
- The Iron Law text appears in the agent's response: "NO REVIEW VERDICT WITHOUT EVERY DIMENSION REACHING PASS/WARN/FAIL/N/A AND EVERY PIPELINE STAGE EXECUTED."
- Verdicts are based on dispatched subagents, not deferred to the prior human review.

**What to capture:** verbatim phrases where the unaided subagent uses the human review as a shortcut ("since this was already reviewed", "the senior engineer is unlikely to miss X").
```

- [ ] **Step 4: Write `deep-review-context-exhaustion.md`**

Content:

```markdown
# Scenario: deep-review-context-exhaustion

**Pressure stack:** context exhaustion.

**Setup:**

The user runs `/deep-review` after a long session. The agent's context is 75% full. Stage 2 returns 15 subagent results that, if quoted verbatim, would put context over 95%.

**What the unaided subagent will be tempted to do:**

- Summarize subagent outputs without quoting evidence
- Drop LOW findings to save tokens
- Skip the verdict matrix and produce a prose summary instead
- Save the report without the per-finding evidence quotes

**Task (verbatim):**

> Stage 2 just returned 15 subagent results. Context is at 75%. Full inclusion would put you over 95%. Synthesize the report — but you must include every dimension's verdict, every finding above WARN with quoted evidence, and the triage/revalidate breakdowns. The report saves to disk; only the summary you print here is constrained.

**Expected GREEN behavior:**

- The report ON DISK has full evidence quotes for every HIGH/CRITICAL finding (mechanically verified by `bin/deep-review-validate`).
- The on-screen summary may compact, but the disk report is complete.
- LOW findings still appear in the disk report; they may be summarized inline in the chat.
- No dimension is dropped from the verdict matrix.

**What to capture:** verbatim "to save context" rationalizations and shortcut phrases.
```

- [ ] **Step 5: Commit**

```bash
git add docs/skill-baselines/_scenarios/deep-review-*.md
git commit -m "test(deep-review): four baseline scenarios for skill-baseline TDD

time-pressure, sunk-cost, authority, context-exhaustion.
Each names the pressure stack, the unaided-subagent failure modes to
probe for, and the expected GREEN behavior with the skill loaded.
"
```

---

## Task 10: RED baseline runs — capture unaided rationalizations

Per `/skill-baseline` (PREPARE/FINALIZE mode), this is human-in-the-loop. For each scenario, run the helper, paste the printed prompt into a fresh Claude Code subagent dispatch WITHOUT the `/deep-review` skill loaded, capture the transcript, and run `--finalize`.

**Files:**
- Create: `docs/skill-baselines/deep-review-time-pressure-<YYYY-MM-DD>.md`
- Create: `docs/skill-baselines/deep-review-sunk-cost-<YYYY-MM-DD>.md`
- Create: `docs/skill-baselines/deep-review-authority-<YYYY-MM-DD>.md`
- Create: `docs/skill-baselines/deep-review-context-exhaustion-<YYYY-MM-DD>.md`

- [ ] **Step 1: Run PREPARE for time-pressure**

```bash
bin/skill-baseline --skill deep-review --scenario deep-review-time-pressure
```

Expected: the helper prints the full subagent prompt and instructions. Read it carefully.

- [ ] **Step 2: Paste prompt into a fresh Claude Code subagent**

Use the `Agent` tool with `subagent_type: general-purpose`. The subagent MUST NOT have the `/deep-review` skill loaded (it's not committed yet — confirm by `grep -l "name: deep-review" skills/*/SKILL.md` returns the stub file only). Paste the printed prompt. Capture the FULL response to a file:

```bash
# After capture:
# (write the transcript content to the file using your editor)
```

- [ ] **Step 3: Finalize the time-pressure baseline**

```bash
bin/skill-baseline --finalize deep-review deep-review-time-pressure \
  --transcript /tmp/deep-review-time-pressure.txt
```

This writes `docs/skill-baselines/deep-review-time-pressure-<YYYY-MM-DD>.md` with the scenario verbatim, the transcript verbatim, and an empty "Rationalizations extracted" section.

- [ ] **Step 4: Hand-extract rationalizations from the transcript**

Read the saved baseline file. Identify the verbatim phrases where the subagent rationalized a shortcut. Fill in the "Rationalizations extracted" section as a table:

```markdown
## Rationalizations extracted

| Verbatim excuse | Reality |
|-----------------|---------|
| "The PR window closes in 20 min — I'll just focus on security." | The 15-dim fan-out IS the audit. Time pressure does not reduce coverage; it raises the cost of a missed bug. |
| "Most dimensions clearly don't apply to this diff." | Each dim either produces a verdict or is N/A with a one-line justification. "Clearly doesn't apply" is not a verdict. |
| ... | ... |
```

Use the actual subagent's words. The point is exact-phrase recognition, not paraphrase.

- [ ] **Step 5: Repeat steps 1–4 for the other three scenarios**

```bash
bin/skill-baseline --skill deep-review --scenario deep-review-sunk-cost
# ... paste, capture, finalize, hand-extract rationalizations

bin/skill-baseline --skill deep-review --scenario deep-review-authority
# ... paste, capture, finalize, hand-extract

bin/skill-baseline --skill deep-review --scenario deep-review-context-exhaustion
# ... paste, capture, finalize, hand-extract
```

- [ ] **Step 6: Commit the four baseline files**

```bash
git add docs/skill-baselines/deep-review-*.md
git commit -m "test(deep-review): RED baseline transcripts captured

Four scenarios run against unaided subagent. Verbatim rationalizations
extracted into 'Rationalizations extracted' table per baseline file.
These are the source material for Task 11's rationalizations.md.
"
```

---

## Task 11: SKILL.md body + rationalizations.md

Fill in the deferred body using the rigid-skill template + the spec § 7. Populate `rationalizations.md` from the four baseline transcripts' extracted tables.

**Files:**
- Modify: `skills/deep-review/SKILL.md`
- Create: `skills/deep-review/rationalizations.md`

- [ ] **Step 1: Write `rationalizations.md`**

The full content is harvested from Task 10's baselines. Merge the four "Rationalizations extracted" tables into one consolidated table. Annotate each row with the baseline scenario it came from.

Skeleton structure — fill in each `<copy from baseline>` and `<verbatim>` from the captured Task 10 transcripts. The "Universal counters" section below is template content you keep as-is.

```markdown
# Rationalization Table — /deep-review

Harvested from four `/skill-baseline` runs against the unaided subagent.
Each row pairs a verbatim excuse with its reality counter. If you catch
yourself thinking any phrase in column 1, stop and read column 2 before
continuing.

## Time-pressure rationalizations

| Verbatim excuse | Reality |
|-----------------|---------|
| <copy from docs/skill-baselines/deep-review-time-pressure-DATE.md> | <copy from same file> |
| ... | ... |

## Sunk-cost rationalizations

| Verbatim excuse | Reality |
|-----------------|---------|
| <copy from sunk-cost baseline> | <copy> |

## Authority-deference rationalizations

| Verbatim excuse | Reality |
|-----------------|---------|
| <copy from authority baseline> | <copy> |

## Context-exhaustion rationalizations

| Verbatim excuse | Reality |
|-----------------|---------|
| <copy from context-exhaustion baseline> | <copy> |

## Universal counters

These apply regardless of pressure stack:

| If you find yourself thinking... | The reality is... |
|-----------------------------------|-------------------|
| "Spot-checking is fine for this diff" | The 15-dim fan-out IS the audit. Spot-checking is the failure mode this skill exists to prevent. |
| "N dimensions don't apply, I'll skip them" | Every dim either produces a verdict or N/A with a one-line justification. "Doesn't apply" is not a verdict. |
| "Subagent says PASS, accept it" | Subagent summaries are inputs to YOUR judgment. Read at least one file:line per HIGH/CRITICAL finding directly. |
| "Triage filtered, revalidate is overkill" | Triage handles conviction-floor + dedup. Revalidate handles context-expansion FPs (the security FP problem). Not the same job. |
```

- [ ] **Step 2: Replace the deferred body in `SKILL.md`**

Open `skills/deep-review/SKILL.md` and replace `_Body deferred to Task 11 — written after baselines._` with the full body. Final SKILL.md:

```markdown
---
name: deep-review
description: Use when the user says "/deep-review", "deep review", "thorough review", or wants the deepest possible code review before pushing a branch.
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

# Deep Review

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

The deepest pre-ship review tier. Runs a 5-stage pipeline (SCAN → DISPATCH → TRIAGE → REVALIDATE → SYNTHESIZE) across 15 dimensions in parallel. Advisory only — does not auto-fire from `/ship` or `/pre-deploy`. Optimized for completeness over speed; typical mid-PR cost is $10–15 and 3–8 minutes wall-clock.

## The Iron Law

```
NO REVIEW VERDICT WITHOUT EVERY DIMENSION REACHING PASS/WARN/FAIL/N/A AND EVERY PIPELINE STAGE EXECUTED
```

No exceptions:
- Spot-checking is not depth. The 15-dimension fan-out IS the audit.
- N/A requires a one-line justification naming what the dimension would have caught and why this diff has no surface for it. "Probably doesn't apply" is not a verdict.
- Subagent summaries are inputs to the orchestrator's judgment, not the verdict itself (harness §27 — "trust but verify"). The orchestrator reads at least one cited `file:line` per HIGH/CRITICAL finding directly.
- Triage filters; revalidate confirms; synthesis ranks. Skipping any stage collapses depth into noise.

## Gate Sequence

**REQUIRED SUB-FILE:** Read `pipeline.md` for the full 5-stage spec (routing table, prompt assembly, report format).

1. **Stage 1 — SCAN.** Run `bin/deep-review-scan`; parse the JSON manifest.
2. **Stage 2 — DISPATCH.** Emit ONE message with N parallel `Agent` tool-use blocks per the routing table in `pipeline.md`. Delegate `security`, `db`, `langgraph` to their existing skills.
3. **Stage 3 — TRIAGE.** Dispatch `subagent_type: triage` (haiku) over all findings. Apply per-FP-profile conviction thresholds + dedup.
4. **Stage 4 — REVALIDATE.** Dispatch `subagent_type: revalidator` (opus) over findings ≥ WARN from `{security, performance, concurrency, structural, error-handling, deps, dead-code}`. Apply CONFIRMED/DISPUTED/FIXED verdicts.
5. **Stage 5 — SYNTHESIZE.** Build the report per `pipeline.md`'s skeleton. Save to `docs/deep-reviews/<YYYY-MM-DD>-<branch-slug>.md`. Run `bin/deep-review-validate` against it — must exit 0. Offer fixes via `AskUserQuestion`.

## Red Flags — STOP

- "The diff is small, just check the obvious ones."
- "Most dimensions don't apply, skip them."
- "Triage already filtered, revalidate is overkill."
- "Subagent says PASS — accept it."
- "We've shipped 100 PRs without this; the bar is too high."
- "Condense the report to fit context — drop the LOW findings."
- "Run dimensions sequentially to save context — don't fan out."
- "I read the subagent's summary; reading the code is theatre."
- Marking the `security` or `error-handling` dimension N/A without justification.
- Producing a verdict without saving the report to `docs/deep-reviews/`.

**All of these mean: stop. Run the missing stage / dispatch against the current diff before any verdict.**

## Common Rationalizations

**REQUIRED SUB-FILE:** Read `rationalizations.md` if you find yourself making excuses. The verbatim-excuse-to-reality table is harvested from four `/skill-baseline` runs (time-pressure, sunk-cost, authority, context-exhaustion) against the unaided subagent.

## Self-Review Checklist

- [ ] Every one of the 15 dimensions produced a verdict (or N/A with one-line justification).
- [ ] All stage-2 dispatches went out as parallel `Agent` calls in a single message.
- [ ] Triage was run; conviction-below-threshold findings dropped (not just buried).
- [ ] Every high-FP-dimension finding ≥ WARN went through revalidate; verdict is CONFIRMED / DISPUTED / FIXED.
- [ ] At least one `file:line` evidence quote read directly (not just from subagent summary) for each HIGH/CRITICAL finding.
- [ ] Report saved to `docs/deep-reviews/<date>-<slug>.md` AND `bin/deep-review-validate <path>` exits 0.

Cannot check all boxes? You skipped the skill. Start over from the missing stage.

## What this skill does NOT cover

- **The cheap per-commit pass.** Use `/pre-deploy`, `/simplify`, or `/security-review` standalone for that. `/deep-review` is the deep tier.
- **Full-repo / module-wide audits.** Scope is always `main..HEAD`. Repo-wide deepsec-style scans are a future feature.
- **Penetration testing, threat modeling, runtime monitoring.** Same boundaries as `/security-review`.
- **GitHub PR review comments.** Use the built-in `/review` for that. `/deep-review` produces a local markdown report.
```

Word count check — target < 500 words in the body, hard ceiling 700 per `skills/CONVENTIONS.md`:

```bash
wc -w skills/deep-review/SKILL.md
```

Expected: ≤ 700 words.

- [ ] **Step 3: Run frontmatter validator**

```bash
bin/test-frontmatter
```

Expected: PASS for deep-review.

- [ ] **Step 4: Commit**

```bash
git add skills/deep-review/SKILL.md skills/deep-review/rationalizations.md
git commit -m "feat(deep-review): SKILL.md body + rationalizations.md

Body filled in from rigid template + spec §7. Iron Law:
'NO REVIEW VERDICT WITHOUT EVERY DIMENSION REACHING PASS/WARN/FAIL/N/A
AND EVERY PIPELINE STAGE EXECUTED.'

rationalizations.md harvested from four baseline transcripts captured
in Task 10 (time-pressure, sunk-cost, authority, context-exhaustion).
"
```

---

## Task 12: GREEN re-baseline — confirm pass with skill loaded

For each scenario, re-run the subagent — this time WITH `/deep-review` loaded — and confirm the GREEN behavior described in each scenario file. If any scenario still fails (subagent still cuts corners), identify the new rationalization, append a row to `rationalizations.md`, and re-baseline (REFACTOR phase).

- [ ] **Step 1: Re-run time-pressure with skill loaded**

Dispatch a fresh subagent via `Agent` (or a fresh Claude Code session) WITH `/deep-review` in the loaded skill list. Use the same scenario task from `_scenarios/deep-review-time-pressure.md`. Capture the response.

Verify GREEN expectations:
- All 15 dimensions produce a verdict (or explicit N/A with justification)
- Stage 2 dispatches go out in a single message
- Revalidate runs for HIGH-FP findings ≥ WARN
- Report saves to `docs/deep-reviews/`

If any GREEN expectation fails: read the new transcript, identify the new rationalization the upgraded subagent is using to slip past the skill, append a row to `rationalizations.md`, repeat.

- [ ] **Step 2: Re-run sunk-cost with skill loaded**

Same as Step 1 for the sunk-cost scenario.

- [ ] **Step 3: Re-run authority with skill loaded**

Same as Step 1 for the authority scenario.

- [ ] **Step 4: Re-run context-exhaustion with skill loaded**

Same as Step 1 for the context-exhaustion scenario.

- [ ] **Step 5: Save the GREEN transcript that will anchor `eval.yaml`**

Pick the time-pressure GREEN transcript as the canonical reference (it exercises the most of the pipeline). Save it under `docs/skill-baselines/deep-review-time-pressure-GREEN-<YYYY-MM-DD>.md`.

Add a header:

```markdown
# Baseline: deep-review-time-pressure (GREEN, with skill loaded)

**Date:** <YYYY-MM-DD>
**Status:** GREEN — skill produced expected behavior under pressure.

## Scenario
<reference to _scenarios/deep-review-time-pressure.md>

## Transcript
<verbatim transcript>

## Why this is GREEN
- [ ] All 15 dimensions verdicted
- [ ] Parallel dispatch in one message
- [ ] Revalidate fired on HIGH-FP WARN+ findings
- [ ] Report saved to docs/deep-reviews/
```

- [ ] **Step 6: Commit GREEN transcripts + any rationalization additions**

```bash
git add docs/skill-baselines/deep-review-*-GREEN-*.md skills/deep-review/rationalizations.md
git commit -m "test(deep-review): GREEN re-baselines — skill passes all four scenarios

time-pressure, sunk-cost, authority, context-exhaustion all produce
the expected behavior with /deep-review loaded. Any new rationalizations
surfaced during REFACTOR appended to rationalizations.md.
"
```

---

## Task 13: `eval.yaml` — trajectory eval traced to GREEN transcript

Author the real `eval.yaml` content, replacing the empty-array stub from Task 1.

**Files:**
- Modify: `skills/deep-review/eval.yaml`

- [ ] **Step 1: Author trajectory eval**

Replace the stub `eval.yaml` with:

```yaml
schema_version: 1
skill_name: deep-review
subagent_only: false

triggers:
  - "/deep-review"
  - "deep review"
  - "thorough review"
  - "deepest possible code review"

trajectory_evals:
  - id: time-pressure
    scenario: docs/skill-baselines/_scenarios/deep-review-time-pressure.md
    description: "Under time pressure, skill still runs all 15 dimensions in parallel + revalidates."
    expected_sequence:
      - action: bash_run
        cmd_pattern: "bin/deep-review-scan"
      - action: agent_dispatch
        target_contains: "dim-investigator"
      - action: agent_dispatch
        target_contains: "triage"
      - action: agent_dispatch
        target_contains: "revalidator"
      - action: bash_run
        cmd_pattern: "bin/deep-review-validate"
      - action: write
        target_contains: "docs/deep-reviews/"
    forbidden_actions:
      - action: agent_dispatch
        target_contains: "dim-investigator"
        before:
          action: bash_run
          cmd_pattern: "bin/deep-review-scan"
    must_cite:
      - "Iron Law"
      - "NO REVIEW VERDICT WITHOUT EVERY DIMENSION"
    must_recognize:
      - "<verbatim time-pressure rationalization from Task 10 baseline>"

  - id: authority-deference
    scenario: docs/skill-baselines/_scenarios/deep-review-authority.md
    description: "Social-proof authority (senior engineer reviewed it) does not shortcut the audit."
    expected_sequence:
      - action: bash_run
        cmd_pattern: "bin/deep-review-scan"
      - action: agent_dispatch
        target_contains: "dim-investigator"
    must_cite:
      - "Iron Law"
    must_recognize:
      - "<verbatim authority rationalization from Task 10 baseline>"
```

Fill in the `must_recognize` phrases by copying verbatim from `rationalizations.md` (which itself was copied verbatim from the baseline transcripts).

- [ ] **Step 2: Validate the eval schema**

```bash
bin/skill-eval --validate
```

Expected: `deep-review` validates without warnings or errors.

- [ ] **Step 3: List eval inventory**

```bash
bin/skill-eval --list | grep deep-review
```

Expected: `deep-review` appears with `trajectory_evals: 2`.

- [ ] **Step 4: Commit**

```bash
git add skills/deep-review/eval.yaml
git commit -m "test(deep-review): eval.yaml with trajectory evals traced to GREEN

Two trajectory_evals: time-pressure (full pipeline + revalidate) and
authority-deference (Iron Law citation). must_recognize fields contain
verbatim rationalizations from the captured RED baselines.
"
```

---

## Task 14: End-to-end smoke test

Run `/deep-review` against a real branch with synthetic findings planted across multiple dimensions; verify the report flags them and that revalidate handles a planted-fix scenario.

**Files:** none committed (the smoke test report itself is throwaway).

- [ ] **Step 1: Create a test branch with planted findings**

```bash
git checkout -b deep-review-smoke-test
mkdir -p smoke/{src,migrations}
```

Plant findings:
- **structural:** add a file with 1,100 lines (template a large file)
- **types:** add `smoke/src/types-bad.ts` with `export function bad(x: any): any { return x; }`
- **tests:** add `smoke/src/untested.ts` with an exported function and no test file
- **a11y:** add `smoke/src/a11y-bad.tsx` with `export const Btn = () => <div onClick={() => {}}>click</div>;`
- **deps:** add `"legacy-shim-xyz": "^0.3.1"` to `package.json` (only if a `package.json` exists)
- **db (gated):** add `smoke/migrations/001_drop.sql` with `ALTER TABLE foo DROP COLUMN bar;` and ensure `HARNESS_DB_MIGRATIONS_DIR=smoke/migrations` is set

```bash
git add smoke/ package.json 2>/dev/null
git commit -m "smoke: planted findings across dimensions"
```

- [ ] **Step 2: Invoke `/deep-review` from a fresh Claude Code session**

In an active Claude Code conversation on this branch, type:

> /deep-review

- [ ] **Step 3: Verify the report**

After the skill completes, inspect:

```bash
ls -1 docs/deep-reviews/
bin/deep-review-validate docs/deep-reviews/<latest>.md
```

Expected:
- Report file exists at `docs/deep-reviews/<YYYY-MM-DD>-deep-review-smoke-test.md`
- `bin/deep-review-validate` exits 0
- Each planted finding appears in the report at the correct severity level
- Verdict matrix has all 15 dimensions; gated dims are appropriately N/A or active

- [ ] **Step 4: Test the "FIXED-IN-COMMIT" revalidate path**

```bash
# Fix one of the planted findings and commit
# (e.g., remove the `any` from smoke/src/types-bad.ts)
git commit -am "smoke: fix planted typescript any"
```

In Claude Code, re-run:

> /deep-review

Expected: the revalidator emits `FIXED-IN-COMMIT-<sha>` for the now-fixed finding; the report drops it from the BLOCKING/HIGH list.

- [ ] **Step 5: Cleanup**

```bash
git checkout markhazlett/deep-review
git branch -D deep-review-smoke-test
rm -rf smoke/
```

Don't commit the smoke artifacts to the production branch.

- [ ] **Step 6: Log smoke results in spec**

Append a `## Smoke test results — <YYYY-MM-DD>` section to `docs/superpowers/specs/2026-05-24-deep-review-design.md` documenting which planted findings the skill caught and any gaps surfaced.

```bash
git add docs/superpowers/specs/2026-05-24-deep-review-design.md
git commit -m "docs(deep-review): smoke test results

Ran /deep-review against synthetic branch with planted findings across
[structural, types, tests, a11y, deps, db]. <N>/<M> caught. <details>.
"
```

---

## Task 15: VERSION bump + PR

Per `CLAUDE.md` § VERSION rule: new skill = minor bump, same PR as the feature.

**Files:**
- Modify: `VERSION`

- [ ] **Step 1: Bump VERSION**

Current: `0.15.0` → New: `0.16.0`.

```bash
echo "0.16.0" > VERSION
```

- [ ] **Step 2: Run harness-health to confirm everything still passes**

```bash
bin/test-frontmatter
bin/skill-eval --validate
bin/test-plan-self-review 2>/dev/null || true
bin/test-terminal-states 2>/dev/null || true
```

Expected: all pass.

- [ ] **Step 3: Commit the version bump**

```bash
git add VERSION
git commit -m "chore: bump version to 0.16.0

New skill: /deep-review. Adds rigid 5-stage code-review pipeline across
15 dimensions. See skills/deep-review/SKILL.md and
docs/superpowers/specs/2026-05-24-deep-review-design.md.
"
```

- [ ] **Step 4: Open the PR**

```bash
git push -u origin markhazlett/deep-review
gh pr create --title "feat: add /deep-review — multi-stage code review skill" --body "$(cat <<'EOF'
## Summary
- Adds `/deep-review` — a rigid, user-invocable skill that runs a 5-stage pipeline (SCAN → DISPATCH(15) → TRIAGE → REVALIDATE → SYNTHESIZE) over a branch diff
- 12 new dimension prompts + 3 delegations to existing rigid skills (`/security-review`, `/db-review`, `/lg-review`)
- Four agent definitions for model-tier routing (`dim-investigator-deep`/opus, `dim-investigator`/sonnet, `triage`/haiku, `revalidator`/opus)
- Two shell helpers: `bin/deep-review-scan` (SCAN stage) and `bin/deep-review-validate` (report validator)
- Iron Law: "NO REVIEW VERDICT WITHOUT EVERY DIMENSION REACHING PASS/WARN/FAIL/N/A AND EVERY PIPELINE STAGE EXECUTED"
- Bumped VERSION 0.15.0 → 0.16.0

## Inspirations
- Cursor's [thermo-nuclear-code-quality-review](https://github.com/cursor/plugins/blob/main/cursor-team-kit/skills/thermo-nuclear-code-quality-review/SKILL.md) (structural / maintainability lens)
- Vercel's [deepsec](https://github.com/vercel-labs/deepsec) (staged pipeline, FP reduction)

## Test plan
- [x] `bin/test-frontmatter` passes (deep-review skill validates)
- [x] `bin/skill-eval --validate` passes
- [x] `bin/tests/test-deep-review-scan` passes
- [x] `bin/tests/test-deep-review-validate` passes
- [x] Four `/skill-baseline` RED transcripts captured under pressure
- [x] Four GREEN re-baselines confirm the skill prevents the RED rationalizations
- [x] End-to-end smoke test against synthetic branch — planted findings caught at expected severities; revalidate marks a planted fix as FIXED-IN-COMMIT
- [x] VERSION bumped in same PR per CLAUDE.md § VERSION rule

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR opens. Capture the URL.

---

## Self-review

Re-read this plan against the spec (`docs/superpowers/specs/2026-05-24-deep-review-design.md`) before kicking off execution:

1. **Spec coverage:**
   - §3 Architecture (5 stages) → Tasks 2, 5, plus stage logic in SKILL.md (Task 11) ✓
   - §4.1 SCAN → Task 2 ✓
   - §4.2 DISPATCH (15 dims, parallel) → Tasks 6–8 (dim prompts) + pipeline.md routing (Task 5) + SKILL.md gate sequence (Task 11) ✓
   - §4.3 TRIAGE → triage agent def (Task 4) + pipeline.md (Task 5) ✓
   - §4.4 REVALIDATE (conditional) → revalidator agent def (Task 4) + pipeline.md (Task 5) ✓
   - §4.5 SYNTHESIZE → pipeline.md report skeleton (Task 5) + SKILL.md (Task 11) ✓
   - §5 Report format → pipeline.md ✓
   - §6 File layout → covered across all tasks ✓
   - §7 Iron Law / red flags / rationalizations → Tasks 9–11 ✓
   - §8 Cost story → SKILL.md "does NOT cover" section (Task 11) ✓
   - §9 Integration → not auto-fired; covered implicitly by NOT touching `/pre-deploy` or `/ship` ✓
   - §11 Acceptance criteria → all 8 items hit across Tasks 1–15 ✓
   - §12 Smoke test (planted findings) → Task 14 ✓

2. **Placeholder scan:** Three legitimate `<copy from baseline>` and `<verbatim ... rationalization>` placeholders remain in Task 11 (rationalizations.md skeleton) and Task 13 (eval.yaml `must_recognize` field). These are **not** plan failures because the content is data harvested at runtime (Task 10) and explicitly defined as "fill from transcript." Per writing-plans § "No Placeholders," forbidden placeholders are TBD-style ones where the content is unknowable from the plan. Baseline-harvested content is knowable at execution; the plan tells the implementer exactly how to extract it.

3. **Type consistency:**
   - Dimension names consistent across the plan: `security`, `db`, `langgraph`, `structural`, `performance`, `concurrency`, `types`, `error-handling`, `observability`, `tests`, `api-drift`, `deps`, `a11y`, `dead-code`, `docs` (15 total, matches spec §4.2.3).
   - Agent definition names consistent: `dim-investigator-deep`, `dim-investigator`, `triage`, `revalidator` (matches spec §6.2).
   - File paths use `skills/deep-review/` consistently (canonical; `.claude/skills/` is symlinked but not used as the source path).
   - `bin/deep-review-scan` and `bin/deep-review-validate` referenced identically everywhere.

Plan validates against spec; no inline fixes needed.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-24-deep-review.md`. Two execution options:

**1. Subagent-Driven (recommended)** — Dispatch a fresh subagent per task, review between tasks, fast iteration. Best for this plan because Tasks 2/3 (shell + TDD), 4/5 (agent defs + pipeline), 6/7/8 (dimension prompts) are independent and parallel-safe.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints. Slower wall-clock but the parent agent (you) holds full context.

Which approach?
