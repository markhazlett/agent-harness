# Assertion rules for /skill-eval

The orchestrator diffs the subagent's `<trajectory-report>` against the eval.yaml's contracts. Below is the full per-field rule table.

## Expected sequence matching

For each step in `expected_sequence`, find the next captured action that matches BOTH the `action` type AND the `target_contains` regex.

| eval.yaml field | actual report field | match rule |
|-----------------|---------------------|------------|
| `action: read` | `tool: Read` | tool name match |
| `action: edit` | `tool: Edit` | tool name match |
| `action: write` | `tool: Write` | tool name match |
| `action: bash_run` | `tool: Bash` | tool name match |
| `action: glob` | `tool: Glob` | tool name match |
| `action: grep` | `tool: Grep` | tool name match |
| `action: agent_dispatch` | `tool: Agent` | tool name match |
| `action: skill_load` | `tool: Skill` | tool name match |
| `target_contains: <pattern>` | `target` | regex `re.search` against the captured target string |

Matching is **in-order with skipping allowed** — captured action[k] satisfies expected step[i], and expected step[i+1] looks for matches starting at captured action[k+1]. Captured actions that don't match any expected step are fine (the model can take extra reasonable steps).

If any expected step has no matching captured action, FAIL with:

```
missing expected step[<i>]: action=<X> target~<pattern> (after position <cursor>)
```

## must_cite

Each string in `must_cite` is checked as a strict substring against the subagent's free-text response (everything OUTSIDE the `<trajectory-report>` block).

- Case-sensitive.
- No regex; literal substring match.
- Whitespace is normalized: collapse runs of whitespace to single spaces before matching.

If absent: FAIL with `must_cite not present in response: <string>`.

## must_recognize

Each string in `must_recognize` is checked against the response with the **3-word window** rule: tokenize both the needle and the haystack into lowercased `\w+` tokens; any 3+ consecutive token window from the needle that appears (as a substring of the joined token stream) in the haystack counts as a match.

This is intentionally permissive: the subagent may paraphrase but should engage with the substance of the rationalization.

If no 3-word window matches: FAIL with `must_recognize not detected (no 3-word window from): <string>`.

## forbidden_actions (Phase 3 — enforced)

Each entry in `forbidden_actions[]` has the shape:

```yaml
forbidden_actions:
  - action: <type>                    # required: read | edit | write | bash_run | glob | grep | agent_dispatch | skill_load
    target_contains: "<regex>"        # required: regex matched against captured target string
    before: <ref>                     # optional: ordering anchor (see below)
```

### Match resolution

A captured action *matches* a forbidden_actions entry when:

1. Its `tool` corresponds to the `action` type (same mapping table used by expected_sequence).
2. `re.search(target_contains, captured.target)` is true.

### Two assertion modes

**Mode 1 — `before:` absent (global ban).**

Fail if ANY captured action matches the entry. Use for "this action must never happen for this scenario at all".

**Mode 2 — `before:` present (ordering ban).**

The forbidden action must not appear BEFORE the resolved anchor index. Capture index 0 is the first action the subagent emitted.

The `before:` value is interpreted in one of two forms:

- **String form** (legacy / current eval.yaml usage). The string is a free-form label naming an anchor in the expected_sequence — e.g., `before: agent_dispatch` or `before: bash_run_failing_test`. The orchestrator resolves the anchor by scanning `expected_sequence` left-to-right and picking the FIRST step whose `action` type appears as a token in the label (split on `_`). For `before: bash_run_failing_test`, the tokens `bash_run` match the `action: bash_run` step. Once the orchestrator picks an expected step, it finds the FIRST captured action that matches that step (same matcher as expected_sequence) — that captured index becomes the anchor.

  If no expected_sequence step is resolved by token-match, FAIL the eval with `forbidden_actions[<i>].before='<label>' did not resolve to any expected_sequence step (use nested form for clarity)`.

- **Nested object form** (recommended for new eval.yaml files; more explicit):

  ```yaml
  forbidden_actions:
    - action: edit
      target_contains: "src/|lib/|app/"
      before:
        action: bash_run
        target_contains: "(npm|pnpm|yarn|jest|vitest|pytest|go test|cargo test)"
  ```

  The orchestrator finds the FIRST captured action matching the nested descriptor (same `tool` + regex matcher) — that captured index becomes the anchor.

### FAIL messages

- Mode 1 (global ban hit): `forbidden_actions[<i>] matched captured action[<j>]: tool=<X> target='<captured>'`
- Mode 2 (ordering ban hit): `forbidden_actions[<i>] appeared at captured[<j>] before anchor 'captured[<k>]' (anchor matched: tool=<X> target='<captured>')`
- Mode 2 (anchor never appeared): WARN, not FAIL. If the anchor never appeared in the captured trajectory, ordering is undefined — surface the warning and let the expected_sequence diff fail loudly instead.

### Backward compatibility

String form is preserved for existing eval.yaml files (`write-skill`, `tdd`). New rigid skills SHOULD use the nested form — it removes ambiguity when an expected_sequence has two steps of the same type.

## decision_evals (Phase 3 — enforced)

For each entry in `decision_evals[]`:

1. The orchestrator injects a "## Decision points" block into the subagent dispatch (see `subagent-prompt.md`) carrying the `id` and `given` only — NEVER the `expected_choice` or `forbidden_choices`.
2. The subagent answers in `<trajectory-report>.decisions[]` keyed by `branch_id`.

### Match rule

Find the entry in `decisions[]` where `branch_id == decision_evals[i].id`. Let `chosen = decisions[i].chosen` after normalization (lowercase, collapse runs of whitespace to single spaces, strip).

- **Expected**: `decision_evals[i].expected_choice` (normalized the same way) must appear as a substring of `chosen`. Substring match — the model can elaborate, but the named path must be present verbatim (case-insensitive, whitespace-normalized).
- **Forbidden**: for each `forbidden_choices[j]` (normalized), it must NOT appear as a substring of `chosen`.

### FAIL messages

- Missing decision: `decision_evals[<i>] branch_id='<id>' was not answered by subagent`.
- Expected absent: `decision_evals[<i>] expected_choice not in chosen: expected~'<expected>' chosen='<chosen>'`.
- Forbidden hit: `decision_evals[<i>] forbidden_choices[<j>] appeared in chosen: forbidden='<forbidden>' chosen='<chosen>'`.

### Empty decisions field

If `decision_evals[]` is non-empty in eval.yaml but the subagent returns `decisions: []` or omits the field, FAIL the eval with `decision_evals declared but subagent emitted no decisions[] in trajectory-report`. The orchestrator must always inject the "Decision points" block when decision_evals is present — if it didn't, that's an orchestrator bug, not a subagent failure.

## expect_exit (Phase 3 — enforced)

`expect_exit: zero | nonzero` on `expected_sequence` bash_run steps describes the expected exit code. Phase 3 trajectory-report v2 captures exit codes via the optional `result` field on each action.

### Match rule

For each `expected_sequence[i]` step with `expect_exit: zero | nonzero`:

1. Find the matching captured action (same matcher used for expected_sequence — tool match + `target_contains` regex + `cmd_pattern` regex if present).
2. If the matched captured action has no `result` field: FAIL with `expected_sequence[<i>] expects exit code but subagent did not report result.exit_code (Bash actions must include result when expect_exit is asserted)`.
3. If `expect_exit: zero` and `result.exit_code != 0`: FAIL with `expected_sequence[<i>] expected exit zero, got <code> (cmd: '<captured.target>')`.
4. If `expect_exit: nonzero` and `result.exit_code == 0`: FAIL with `expected_sequence[<i>] expected exit nonzero, got 0 (cmd: '<captured.target>')`.

### Trajectory report version compatibility

- **v1 reports** (no `version` field, no `result` on any action): treated as legacy. If any `expected_sequence` step uses `expect_exit`, FAIL with the missing-result message above — the subagent is on an old prompt template and must be re-dispatched with the v2 template.
- **v2 reports** (`version: 2`): `result` is optional per-action but REQUIRED on Bash actions that the eval.yaml asserts `expect_exit` on. Non-Bash tools may include `result` but the orchestrator ignores it.

The `version` field is the only schema-versioning signal. When changing the trajectory-report shape again, bump it and document both versions here.

## output_evals (Phase 3 — enforced)

For each entry in `output_evals[]`:

1. After the subagent dispatch returns, the orchestrator searches the working tree for files matching `artifact_path_pattern`. The pattern is a **glob** (NOT a regex). Use shell-style globbing — `*`, `**`, `?`, `[abc]`. The orchestrator runs the glob from the repo root (`git rev-parse --show-toplevel`). Use the Glob tool or Bash `ls`.
2. If NO files match: FAIL with `output_evals[<i>] no artifacts found matching pattern '<pattern>'`.
3. For each matched file, apply the three checks:
   - **`must_contain_sections[]`**: each entry is a markdown heading. Match by exact-line equality after stripping trailing whitespace (e.g., `## Done Criteria` matches `## Done Criteria   `). Headings inside fenced code blocks DO NOT count. FAIL with `output_evals[<i>] file '<path>' missing section '<heading>'`.
   - **`must_not_contain[]`**: each entry is a strict substring. Case-sensitive. If found anywhere in the file, FAIL with `output_evals[<i>] file '<path>' contains forbidden substring '<needle>'`.
   - **`must_match_regex[]`**: each entry is a regex. `re.search` (not `re.fullmatch`); MULTILINE flag OFF by default — use `(?m)` in the pattern when needed. If no match, FAIL with `output_evals[<i>] file '<path>' did not match regex '<pattern>'`.

### Why glob, not regex

The `artifact_path_pattern` is for *discovery* (which artifacts to check), not validation. Globs are simpler, less error-prone, and align with how users describe paths (`docs/plans/*/sprint-plans/*.md`). Regex is reserved for `must_match_regex[]` which operates on file *contents*.

### Why this works from the orchestrator

The subagent's file ops are real Claude Code Read/Edit/Write — they touch the same filesystem the orchestrator sees. After the Agent dispatch returns, `Glob` from the orchestrator picks up artifacts the subagent produced. No special handoff needed.

### Empty match-list edge case

If `must_contain_sections[]`, `must_not_contain[]`, and `must_match_regex[]` are ALL empty (or absent) — the entry is a no-op that only asserts "at least one file matched the pattern". That is intentional and allowed; the FAIL on no-match (step 2) is the entire contract for those entries.

## Trajectory report parsing

The orchestrator extracts the JSON between `<trajectory-report>` and `</trajectory-report>` tags. Failure modes:

- **Tag missing.** FAIL: "subagent did not emit trajectory-report block".
- **JSON does not parse.** FAIL: "trajectory-report present but JSON parse error: <error>".
- **`actions` missing or not a list.** FAIL: "trajectory-report missing `actions` array".
- **`skill_section_cited` missing.** WARN (not FAIL) — the eval may still pass if other assertions hold, but surfacing the warning helps debug "the model did the right things but didn't know why".

## Phase 4 — judge-LLM fuzzy matching (enforced)

Strict diffing is brittle: equivalent tool choices (e.g., `Glob "**/*.test.ts"` vs `Bash "find . -name '*.test.ts'"`) FAIL as missing-expected-step. Phase 4 adds an opt-in judge that fires *only* when a strict step fails, dispatches a fresh subagent via the `Agent` tool with the prompt in `judge-prompt.md`, and returns one of three verdicts.

### When the judge fires

- ONLY on `expected_sequence` "missing expected step" failures. Other assertion failures (`forbidden_actions`, `decision_evals`, `must_cite`, `must_recognize`, `output_evals`, `expect_exit`) are NOT routed through the judge. Those are deterministic and the judge can't recover them.
- Triggered automatically by the orchestrator unless `SKILL_EVAL_JUDGE=off` is in the environment (CI / `--quick` mode disables).

### Per-eval cap

- **5 judge dispatches per eval run** (total across all missing-expected-step failures in that run). If a single trajectory has > 5 missing-expected-step failures, the first 5 are judged; the rest stay as strict FAIL. This prevents runaway token cost on broken evals.
- Cache verdicts keyed by `sha256(skill_name + eval_id + expected_step_json + captured_trajectory_json)`. Repeated runs of the same captured trajectory reuse the cached verdict. Cache lives at `/tmp/skill-eval-judge-cache.json` (ephemeral; safe to delete).

### Verdict format

The judge returns exactly:

```
verdict: <equivalent | not_equivalent | ambiguous>
matched_captured_index: <integer or null>
because: <one sentence, ≤ 200 chars>
```

Orchestrator decision rule:

| Verdict | Action |
|---------|--------|
| `equivalent` + valid `matched_captured_index` | Flip the missing-expected-step from FAIL to **PASS-with-judge-note**. The PASS report shows: "expected[i] matched captured[k] via judge — because: <reason>". |
| `equivalent` + null/invalid `matched_captured_index` | FAIL with `judge returned equivalent but matched_captured_index was null/invalid — judge prompt regression?`. |
| `not_equivalent` | The original strict FAIL stands. Report shows the judge's `because` as context. |
| `ambiguous` | FAIL-with-judge-warning. Eval fails; report surfaces the judge's `because` so the user can disambiguate. |

### Substitution accounting

When the judge flips an expected step to PASS via `matched_captured_index = k`, capture[k] is **claimed** by that expected step — subsequent expected_sequence iterations skip it (same semantics as a strict match). The cursor advances past k.

### Anti-rubberstamp discipline

`anti-evals/judge-rubberstamp-canary.md` is the regression test for the judge prompt. Run it before shipping any change to `judge-prompt.md`. The canary feeds the judge a trajectory of clearly-wrong Bash actions for a TDD scenario; the expected verdict is `not_equivalent`. If the judge returns `equivalent`, the prompt is overfitting and the change must NOT ship.

This anti-eval is **mandatory** for any PR that touches `judge-prompt.md` or this Phase 4 section. The reverse coupling — the anti-eval embeds the current prompt inline — means stale anti-evals also block; bump both together.

### What the judge does NOT see

- `must_cite`, `must_recognize`, `forbidden_actions`, `decision_evals`, `output_evals`, `expect_exit` — the judge's scope is *one expected step*. Other assertions are graded separately and not re-litigated by the judge.
- The full skill body (judge gets a one-sentence Iron Law summary, not the whole body). Keeps the dispatch small and avoids the judge re-implementing the skill's discipline.
- Other captured trajectories (no cross-eval contamination).

### Configuration knobs

- `SKILL_EVAL_JUDGE=off` — disables Phase 4 entirely; revert to strict-only.
- `SKILL_EVAL_JUDGE_CAP=<int>` — overrides the per-run cap (default 5). Use sparingly.
- The judge always uses `subagent_type: general-purpose` — no override.

## Phase 4 — headless CI adapter (DEFERRED — blocked on Claude Code SDK headless mode)

The Phase 4 design questions for a headless executor remain valid (see `follow-ups.md` § F), but the recommended path — wait for Claude Code SDK headless mode rather than resurrect a Python mock — is what this PR explicitly chose. Re-evaluate when:

- Claude Code ships an SDK with headless dispatch (`subagent_type` parity + tool palette parity + system prompt parity).
- OR the harness has accumulated enough Phase 2/3/4 eval surface that the cost of NOT having CI coverage outweighs the fidelity loss of a Python mock.

When either trigger fires, reopen `follow-ups.md` § F, answer Q1 (SDK vs mock) explicitly, then proceed. The Phase 2 deletion of `bin/skill-eval-run` was deliberate; any resurrection requires the same level of intentionality.

## On FAIL — what to surface

A FAIL report itemizes:

1. The eval id and trajectory description.
2. Each missing expected step (action + pattern + position).
3. Each absent `must_cite`.
4. Each undetected `must_recognize`.
5. The full captured `actions` list for context.
6. The subagent's `outcome` line.

Do NOT mutate `eval.yaml` to make the test pass. Do NOT silently retry. Surface to the user and let them decide: fix the skill, fix the eval, or accept the regression.
