# Skill Evals — Specification

Skill evals are the **regression layer** for the harness's own rigid skills. Where `bin/skill-baseline` captures a one-shot RED/GREEN transcript, `bin/skill-eval` re-runs scenarios and asserts the agent's trajectory, decisions, and outputs against declared expectations. This is what catches drift when the model version changes, when a parent skill's calling pattern changes, or when a skill's own body is edited in ways that break compliance.

This spec covers the YAML schema, the four eval types, and the runner contract. It's intentionally staged — Phase 1 ships the schema, validator, and skeleton runner; Phase 2 wires in actual subagent dispatch + trajectory capture.

## Why evals (beyond baseline)

Baselines are one-shot. They prove the skill works *once*, on the day it was written, against one model version. After that:

- Model versions ship and trajectories shift.
- A parent skill (`/build`, `/ship`) changes its dispatch logic and a subagent-only child skill stops firing.
- A skill's own body gets edited (typo fix, section reorder) and the rationalization table no longer aligns with the new structure.
- A user-facing skill regresses silently because nobody runs the scenario again.

Evals exist to catch these. They run on demand (`/harness-health`) and pre-merge in CI (when CI exists). They re-execute the same scenarios baseline used, but with the skill loaded, and assert the trajectory matched expectations.

## File location

Each rigid skill has a sibling `eval.yaml`:

```
.claude/skills/<skill>/
  SKILL.md
  rationalizations.md
  red-flags.md       (optional)
  eval.yaml          ← THIS FILE
```

Flexible and util skills *may* have `eval.yaml` (recommended for orchestrators like `/build-plan`) but are not required.

## Schema (version 1)

```yaml
schema_version: 1
skill_name: <must equal parent folder name>

# True for skills only invoked by other skills (not user-facing).
# When true, invocation_evals is REQUIRED — that is how subagent-only
# skills get verified at all.
subagent_only: false

# Triggers this skill should fire on. Used for trigger-detection evals.
# These can be user phrases, slash commands, or situational symptoms.
triggers:
  - "/<skill-name>"
  - "user phrase that should trigger this"
  - "situational symptom"

# ── Trajectory evals ────────────────────────────────────────────────
# Expected ordered actions for a given scenario. The runner dispatches
# the scenario with the skill loaded, captures the subagent's tool
# calls, and diffs against expected_sequence.
trajectory_evals:
  - id: <unique-within-this-file>
    scenario: docs/skill-baselines/_scenarios/<slug>.md
    description: "One sentence — what does this verify?"
    expected_sequence:
      - action: read | edit | write | bash_run | skill_load | agent_dispatch
        target_contains: "regex or substring of file/cmd/skill"
        # Optional fields:
        expect_exit: zero | nonzero            # bash_run only
        cmd_pattern: "regex"                    # bash_run only
        before: <action ref>                    # for ordering constraints
    forbidden_actions:
      # Actions that must NOT appear (anywhere, or with the given ordering)
      - action: <type>
        target_contains: "..."
        before: <action ref>
    must_cite:
      # Strings that must appear in the agent's response (typically
      # references back to the skill's Iron Law or rationalization rows)
      - "Iron Law"
      - "rationalizations.md"
    # If a rationalization is expected to fire, name the verbatim phrase.
    must_recognize:
      - "verbatim excuse the agent should catch"

# ── Invocation evals (REQUIRED if subagent_only: true) ──────────────
# Verifies that a parent skill correctly dispatches this skill given a
# scenario the parent receives.
invocation_evals:
  - id: <unique>
    parent_skill: <skill-name>        # the calling skill
    parent_scenario: "one-sentence setup of what the parent receives"
    expected: "this skill loads before <some action>"
    forbidden: "parent emits <action> without this skill firing first"

# ── Decision-point evals ────────────────────────────────────────────
# At each named branch in the skill's flow, did the agent pick the
# correct path? Used for skills with conditional logic (debug, e2e-verify).
decision_evals:
  - id: <unique>
    branch: "one-sentence description of the decision point"
    given: "the input/context at the branch"
    expected_choice: "the path the agent should take"
    forbidden_choices:
      - "the wrong path 1"
      - "the wrong path 2"

# ── Output evals ────────────────────────────────────────────────────
# For skills that produce artifacts (plan docs, demo scripts, eval files,
# learning entries). Validates the artifact's shape, not the prose.
output_evals:
  - id: <unique>
    artifact_path_pattern: "docs/plans/*/sprint-plans/*.md"
    must_contain_sections:
      - "## Done Criteria"
      - "## File Footprint"
    must_not_contain:
      - "TODO"
      - "TBD"
      - "implement later"
    must_match_regex:
      # Optional: arbitrary regex patterns the artifact must contain
      - "(?m)^- \\[ \\] .+$"   # at least one checkbox line
```

## Eval types in detail

### Trajectory evals

**What they check:** the agent took the right *actions* in the right *order*. This is the highest-signal eval for discipline skills (`/tdd`, `/debug`, `/incident`) where the *sequence* is the discipline.

**Example assertion (for `/tdd`):**

1. `read` a test file or related code
2. `edit` or `write` a test file
3. `bash_run` matching `(npm|pnpm|yarn|pytest|go) test` with `expect_exit: nonzero`
4. `edit` an implementation file
5. `bash_run` matching test command with `expect_exit: zero`

**Forbidden actions:** any `edit` to implementation code *before* a corresponding `edit_or_write` to a test file.

### Invocation evals

**What they check:** a parent skill (`/build`, `/ship`) correctly fires this skill when the parent's context matches. These are the only evals that meaningfully test *subagent-only* skills — those skills are never user-triggered, so their failure modes only surface when their parent fails to dispatch.

**Example (for `/security-review`):**

```yaml
invocation_evals:
  - id: ship-fires-security-review-when-touching-auth
    parent_skill: ship
    parent_scenario: "diff contains changes under packages/auth/ or apps/web/api/auth/"
    expected: "/security-review loads before /ship completes the push"
    forbidden: "ship pushes without firing /security-review"
```

### Decision-point evals

**What they check:** at conditional branches in a skill's flow, the agent picks the correct path. These catch the failure where the skill body is correct but the *interpretation* of an ambiguous input is wrong.

**Example (for `/debug`):**

```yaml
decision_evals:
  - id: flaky-test-routes-to-investigation
    branch: "test is flaky (sometimes passes, sometimes fails)"
    given: "user reports a test that fails 30% of the time"
    expected_choice: "run Phase 1 root-cause investigation"
    forbidden_choices:
      - "retry the test"
      - "add a random delay"
      - "mark as flaky and skip"
```

### Output evals

**What they check:** for skills that produce artifacts (plan docs, demo scripts, learning entries, baseline files), the artifact has the right *shape*. Output evals validate structure, not prose quality.

**Example (for `/plan-sprint`):**

```yaml
output_evals:
  - id: sprint-plan-has-required-sections
    artifact_path_pattern: "docs/plans/*/sprint-plans/*.md"
    must_contain_sections:
      - "## Done Criteria"
      - "## File Footprint"
      - "## Test Plan"
    must_not_contain:
      - "TODO"
      - "implement later"
```

## Runner contract — `bin/skill-eval`

```
bin/skill-eval --validate                # Schema-validate every eval.yaml in .claude/skills/
bin/skill-eval --list                    # List skills with/without evals + summary
bin/skill-eval --plan <skill>            # Print the eval plan for one skill (Phase 1)
bin/skill-eval --run <skill> [<eval-id>] # Execute scenarios + diff (Phase 2)
bin/skill-eval --report                  # Aggregate report across all skills (Phase 2)
```

Exit codes (matching the harness convention):

- `0` — all evals (in scope) pass
- `1` — one or more evals failed
- `2` — usage error / repo not found / schema invalid

The runner is consumed by:

- `/harness-health` — runs `bin/skill-eval --validate` (Phase 1) and `--report --quick` (Phase 2).
- `/write-skill` — the Iron Law mandates `eval.yaml` for rigid skills.
- CI (when present) — runs `bin/skill-eval --validate` + `--run` on pre-merge.

## Phase 1 vs Phase 2

**Phase 1 (this PR):**

- ✅ Schema spec (this file) — all four eval types documented
- ✅ `bin/skill-eval --validate` — YAML parses, schema_version is 1, required fields present, scenario paths exist
- ✅ `bin/skill-eval --list` — inventory of which skills have evals
- ✅ `bin/skill-eval --plan <skill>` — pretty-prints what would run for a skill
- ✅ Integrated into `/write-skill` Iron Law + checklist
- ✅ Wired into `/harness-health`
- ✅ Worked examples for `/write-skill`, `/tdd`

**Phase 2 (follow-up PRs):**

- 🚧 `bin/skill-eval --run` — actual subagent dispatch + tool-trace capture + assertion engine
- 🚧 Judge-LLM "close enough" matching for fuzzy assertions (e.g., synonym tool calls)
- 🚧 LangSmith / external dashboards if needed
- 🚧 CI integration (GitHub Actions) running `--run` on PRs that touch `.claude/skills/`

The Phase 1 schema is forward-compatible: every field documented above is consumed by Phase 2 without reshaping.

## When evals are required

| Skill kind | trajectory | invocation | decisions | outputs |
|------------|-----------|------------|-----------|---------|
| Rigid, user-invocable | REQUIRED | optional | recommended | when artifacts |
| Rigid, subagent-only (`subagent_only: true`) | optional | **REQUIRED** | recommended | when artifacts |
| Flexible, orchestrator (e.g., `/build-plan`) | recommended | recommended | recommended | when artifacts |
| Flexible, generative (e.g., `/demo-script`) | optional | optional | optional | **REQUIRED** |
| Util | not required |

`/write-skill` enforces these via its Iron Law's 5th clause. `bin/skill-eval --validate` enforces them at the schema layer.

## Authoring an eval.yaml

1. **After GREEN baseline passes**, run `bin/skill-baseline --finalize` to record the GREEN transcript.
2. **Extract the trajectory** from the GREEN transcript: which tools did the agent call, in what order, with what targets?
3. **Translate to `expected_sequence`** in `eval.yaml`. Use `target_contains` (substring/regex) — don't pin exact paths that will drift.
4. **Add `must_cite` and `must_recognize`** for the rationalization rows that fired.
5. **For subagent-only skills**, write at least one `invocation_eval` naming the parent and the dispatch condition.
6. **For artifact-producing skills**, write an `output_eval` with the structure contract.
7. **Run `bin/skill-eval --plan <skill>`** to verify the file parses and lists what would run.
8. **Run `bin/skill-eval --validate`** to confirm schema conformance.

## Reading this spec

If you're authoring a new skill, start with `/write-skill` — it points back here when you reach the eval step. The four-corners structure (frontmatter + body + rationalizations + eval) is the full rigid-skill contract as of harness 0.10.0.
