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

## expect_exit (NOT yet enforced)

`expect_exit: zero | nonzero` on bash_run steps describes the expected exit code. The subagent's trajectory report does NOT currently capture exit codes — that's Phase 3 (richer report schema with `result` field per action).

## Trajectory report parsing

The orchestrator extracts the JSON between `<trajectory-report>` and `</trajectory-report>` tags. Failure modes:

- **Tag missing.** FAIL: "subagent did not emit trajectory-report block".
- **JSON does not parse.** FAIL: "trajectory-report present but JSON parse error: <error>".
- **`actions` missing or not a list.** FAIL: "trajectory-report missing `actions` array".
- **`skill_section_cited` missing.** WARN (not FAIL) — the eval may still pass if other assertions hold, but surfacing the warning helps debug "the model did the right things but didn't know why".

## On FAIL — what to surface

A FAIL report itemizes:

1. The eval id and trajectory description.
2. Each missing expected step (action + pattern + position).
3. Each absent `must_cite`.
4. Each undetected `must_recognize`.
5. The full captured `actions` list for context.
6. The subagent's `outcome` line.

Do NOT mutate `eval.yaml` to make the test pass. Do NOT silently retry. Surface to the user and let them decide: fix the skill, fix the eval, or accept the regression.
