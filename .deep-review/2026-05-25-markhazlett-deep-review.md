# Code Review — markhazlett-deep-review
**Date:** 2026-05-25
**Diff:** main..HEAD (263 files, +33364/-1759 lines)
**Commit:** 58a6c4c
**Reviewer:** /deep-review (SCAN → 12 dim subagents in parallel → triage → revalidate → synthesis)

## Summary

This branch ships `/deep-review` itself — the 5-stage code-review skill, its 12 dim charters, two new agent definitions (`dim-investigator`, `dim-investigator-deep`), the SCAN + validate bin/ scripts, and a meaningful pile of related harness cleanup (hooks reorg into `hooks/shell/` + `hooks/pi/`, `harness-update` machinery, conductor early-exit gates, a renamed report path from `docs/deep-reviews/` to `.deep-review/`). The shape of the skill is sharp — the SKILL.md/pipeline.md split is correct, the Conventional Comments adaptation is well-modeled, and the pipeline-notes audit trail in the report skeleton is the right kind of receipt. What I want to flag before merge is the gap between the harness's own "fail loud" convention and four places where it doesn't: a protected-files guard that's been left behind by the hooks reorg (real RCE chain via two now-unguarded files), `apply_plan` swallowing `cp`/`mkdir` failures and writing a "success" manifest anyway, SCAN exiting 0 on an invalid base ref, and the validator's own test suite broken by the reframe commit that landed eight days ago. None of these are big — they're all narrow fixes — but they're load-bearing for a skill whose stated value is "completeness over speed."

**Verdict:** Substantial concerns

## Before merge (4 items)

### `hooks/shell/protected-files.sh:34` — guard scopes to `.claude/hooks/*` but the canonical scripts now live at `hooks/shell/` and `hooks/config.sh`

**issue (blocking):** The hook-script editing guard only matches `.claude/hooks/*`:

```sh
# Block hook scripts (guard the guards)
if [[ "$REL_PATH" == .claude/hooks/* ]]; then
  block "Editing hook scripts is not allowed — they enforce quality gates"
fi
```

This PR reorganized the hooks tree so the real files live at `hooks/shell/*.sh` and `hooks/config.sh`, with `.claude/hooks/*.sh` as symlinks. An `Edit` or `Write` tool call with `file_path` set to `hooks/shell/bash-guard.sh` or `hooks/config.sh` does not match the glob and the guard returns without blocking. That matters because two other files in the diff already `eval` config-controlled command strings — `hooks/shell/stop.sh:30` runs `eval "$HARNESS_TEST_CMD"` and `hooks/shell/post-edit.sh:28` runs `eval "$HARNESS_DB_GENERATE_CMD"`. So an LLM that can edit `hooks/config.sh` (the unguarded path) can set those vars to arbitrary shell, and the next Stop / PostEdit event runs the payload. The whole purpose of the protected-files hook is "guard the guards"; the reorg moved them out from under it.

**suggestion:** Widen the match to the canonical tree:

```sh
if [[ "$REL_PATH" == .claude/hooks/* \
   || "$REL_PATH" == hooks/shell/* \
   || "$REL_PATH" == hooks/config.sh \
   || "$REL_PATH" == hooks/pi/* ]]; then
  block "Editing hook scripts is not allowed — they enforce quality gates"
fi
```

Add a `bin/tests/protected-files.test.sh` regression case that Edit on `hooks/shell/bash-guard.sh` and on `hooks/config.sh` both return the block decision.

**revalidated:** CONFIRMED — file read confirms the glob; canonical paths confirmed by `ls hooks/shell/`; `eval` chain confirmed in `stop.sh:30` and `post-edit.sh:28`.

### `bin/harness-update:275` — `copy_file` has no error handling, so a failed `cp` leaves the manifest claiming success

**issue (blocking):** `harness-update` runs with `set -uo pipefail` (no `-e`), and `copy_file` makes no attempt to detect failure. The caller in `apply_plan` unconditionally records success:

```sh
copy_file() {                                  # bin/harness-update:275
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"                             # ← no || die
  case "$1" in bin/*|*.sh) chmod +x "$dst" ;; esac
}
# ...apply_plan loop body...
copy_file "$path"                              # :327
record "$path" "$up_hash" "$up_hash"           # writes "success" hash unconditionally
```

If `cp` fails (permission, disk full, symlinked dir gone), the loop keeps iterating and the final `jq -n ... > "$MANIFEST_FILE"` writes a manifest claiming every file was installed. The next `--plan` compares `manifest.local_hash` (= upstream hash, per the lie) against the on-disk file (still old content) and classifies the path as "user pinned a custom version" — a phantom conflict for a file that never landed. CLAUDE.md Coding convention 6 ("Fail loud") names this exact mode.

**suggestion:** Make `copy_file` fail-fast, and abort `apply_plan` before the manifest write:

```sh
copy_file() {
  local src="${SOURCE_DIR}/$1"
  local dst="${REPO_ROOT}/$1"
  mkdir -p "$(dirname "$dst")" || die "mkdir failed for $(dirname "$dst")"
  cp "$src" "$dst" || die "copy failed for $1"
  case "$1" in
    bin/*|*.sh) chmod +x "$dst" || die "chmod failed for $dst" ;;
  esac
}
```

`die` is already defined at the top of the script; reuse it. Optionally wrap apply_plan in a `trap 'rm -f "$MANIFEST_FILE.tmp"; exit 1' ERR` if you decide to switch to atomic temp-then-rename for the manifest write.

**revalidated:** CONFIRMED — `set -uo pipefail` at line 34, no `set -e`, no `|| die` in `copy_file` or its callers, manifest write at line 384 is unconditional.

### `bin/deep-review-scan:33` — invalid base ref silently produces an empty-diff manifest

**issue (blocking):** SCAN reads `BASE="${1:-main}"` and runs `git diff` against `$BASE...HEAD` with errors silenced and `|| true` masking the exit code:

```sh
BASE="${1:-main}"

files=()
while IFS= read -r line; do
  [ -n "$line" ] && files+=("$line")
done < <(git diff --name-only "$BASE"...HEAD 2>/dev/null || true)

added=$(git diff --shortstat "$BASE"...HEAD 2>/dev/null | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
removed=$(git diff --shortstat "$BASE"...HEAD 2>/dev/null | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
```

Reproduction: `bash bin/deep-review-scan totally-not-a-real-branch` exits 0 with `"files": []`, all gates `false`, and every scope's `paths: []`. The downstream `/deep-review` orchestrator reads this as "nothing changed" and produces a default-positive verdict ("Ship it") for a typo'd base branch. Per CLAUDE.md Coding convention 6 ("Fail loud"), this is the canonical anti-pattern — the validator is the gate, and a silent typo turns it into a confidence rubber-stamp.

**suggestion:** Validate the ref first, and drop the silencing on the `git diff` invocations:

```sh
BASE="${1:-main}"

git rev-parse --verify "$BASE" >/dev/null 2>&1 || {
  echo '{"error":"unknown base ref: '"$BASE"'"}' >&2
  exit 1
}

files=()
while IFS= read -r line; do
  [ -n "$line" ] && files+=("$line")
done < <(git diff --name-only "$BASE"...HEAD)

added=$(git diff --shortstat "$BASE"...HEAD | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
removed=$(git diff --shortstat "$BASE"...HEAD | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
```

Add a `bin/tests/deep-review-scan.test.sh` case that asserts non-zero exit on an unknown ref.

**revalidated:** CONFIRMED — reproduced live: `bash bin/deep-review-scan totally-not-a-real-branch` returned a manifest with `files: 0`, `added: 0`, all gates false.

### `bin/tests/deep-review-validate.test.sh:13` — fixtures broken by the reframe commit; the validator's own test suite fails on `main`

**issue (blocking):** Commit `71145b9` ("feat(deep-review): reframe as code review") reshaped the validator contract to require `## Before merge (N)` sections, `**issue (blocking):**` + `**suggestion:**` pairing, and a `**Verdict:** Ship it | Address blocking items first | Substantial concerns` line. The test fixtures were not updated. The `good.md` fixture at lines 13–40:

```sh
cat > "$tmp/good.md" <<'EOF'
# Deep Review — sample
**Date:** 2026-05-24

## Verdict Matrix
| # | Dimension      | Verdict |
|---|----------------|---------|
| 1 | security       | PASS    |
...
| 15 | docs          | PASS    |

## N/A dimensions
- db — no migrations touched
- langgraph — no LG paths
- a11y — no frontend files
EOF
```

…has no `**Verdict:**` line, so the very first assertion fails. Running the suite at HEAD:

```
$ bash bin/tests/deep-review-validate.test.sh
FAIL: missing '**Verdict:** Ship it | Address blocking items first | Substantial concerns' line
FAIL: report does not validate
FAIL: validator rejected a complete report
```

Same shape for the BLOCKING-fixture cases later in the file — they still use `## BLOCKING (1)` headers and `**Evidence:**` fields the validator no longer recognizes. So the only mechanical coverage for `bin/deep-review-validate` is broken on this branch, and the reframe commit shipped without working tests for any of the new contract.

**suggestion:** Update every heredoc fixture to the new schema:
- `## BLOCKING (N)` → `## Before merge (N)`
- `**Evidence:** …` → `**issue (blocking):** …` + `**suggestion:** …` (paired)
- Add `**Verdict:** Ship it` (or `Address blocking items first` for the BLOCKING fixtures) to every fixture intended to pass
- Add a new negative-case fixture covering the missing-Verdict-line check

Once green, wire `bin/tests/*.test.sh` into something that runs them automatically — `/pre-deploy` or a top-level `bin/test-all` script — so the next reframe doesn't silently rot them again.

**revalidated:** CONFIRMED — read `bin/tests/deep-review-validate.test.sh:13-40` directly, ran the test, confirmed three FAIL lines.

## Worth thinking about (16 items)

### `bin/deep-review-scan`

- **issue (non-blocking):** Exemplar lookup at `bin/deep-review-scan:102` (`emit_exemplars_lines_for_file` + `build_union_exemplars`) is O(N²) with per-file `git ls-files | grep | sort` subprocess starts. For this branch's 263 changed files the worst case is ~263 forks plus O(N × tracked-files-per-ext) bash-level comparisons. The 3-exemplar early-return caps the common case but doesn't bound the dedupe. Fix: cache `git ls-files` once, replace the `for d in files` linear scan with `declare -A in_diff` populated once.

### `bin/harness-update`

- **issue (non-blocking):** `build_plan` / `apply_plan` at `bin/harness-update:159+` invoke `jq` inside `while read` loops to grow JSON arrays, so total work is O(N²) with N process spawns; `sha256` and `manifest_entry_for` add two more subprocesses per file. ~900 subprocess starts for ~300 upstream files. Not a request hot path, but worth fixing before the upstream tree grows. Fix: emit JSONL to a tempfile in the loop, `jq -s '.'` once at the end.
- **issue (non-blocking):** Manifest write at `bin/harness-update:384` has no locking. `$MANIFEST_FILE` is global per-user state (`~/.agent-harness/installed-manifest.json`) shared across every project. Two concurrent `/harness-update` runs (different Conductor workspaces on the same machine, e.g.) race on this file — last writer wins, the loser's record of "what was installed" is lost, and a later `--plan` mis-classifies the resulting state. Fix: `flock 9>"$STATE_DIR/.lock"` at the top of `apply_plan`, or atomic temp-then-rename (matches the pattern `bin/learn:192` already uses).

### `bin/harness-update-check`

- **suggestion:** Silent exit on a fetch failure (`bin/harness-update-check:84`) is an intentional UX choice, but it also hides the diagnostic from the developer. If upstream's VERSION URL moves or starts returning HTML, every user silently stops seeing update prompts forever. Fix: on the failure branch, write `FETCH_FAILED|0|${NOW}` to `CACHE_FILE` so a maintainer can debug stuck installs; keep the user-visible silence.

### `bin/test-frontmatter`

- **suggestion:** 6 `awk` forks per skill (1 `has_frontmatter` + 5 `extract_field`) at `bin/test-frontmatter:69`. ~420 subprocess starts for ~70 skills. CI/dev validator, not a hot path. Fix: single awk that emits all 5 fields as `key=value` pairs and parse them in bash; or move the validator to a single `yq` invocation.

### `bin/tests/`

- **issue (non-blocking):** No automation invokes `bin/tests/*.test.sh`. The Before-merge item above (broken `deep-review-validate.test.sh`) shipped precisely because nothing runs them automatically. Pre-existing harness gap, not a PR-35-introduced regression — but every new `*.test.sh` in this PR inherits the same vacuum. Fix: have `/pre-deploy` (or `/ship`) run `for t in bin/tests/*.test.sh; do bash "$t"; done` as a gate.

### `.claude/skills/deep-review/`

- **issue (non-blocking):** The ~8-line "Anchoring" block in `.claude/skills/deep-review/dimensions/structural.md:7` is copy-pasted verbatim across all 12 dim charters (confirmed: `grep -l` returns exactly 12). Pipeline.md (`:79-85`) already injects `CONVENTIONS` and `REFERENCE EXEMPLARS` as named-section prompt inputs, so the per-charter preamble adds no information the dispatched subagent doesn't already get from the orchestrator's wrapper. Cost: ~96 lines of bytes, plus drift risk when the conviction-mapping wording changes in pipeline.md but not in the charters. Fix: lift to `_anchoring.md` referenced from each charter, or delete from all 12 and rely on the pipeline.md prompt template. (Also flagged by: `dead-code` at `a11y.md:9`.)
- **issue (non-blocking):** Pipeline.md (`skills/deep-review/pipeline.md:21`) documents a `candidates` field in the SCAN manifest schema, but `bin/deep-review-scan` never emits it — the actual scope object is `{paths, exemplars}` (+ optional `active` on gated dims). No runtime contract break today because no consumer reads `candidates`, but the spec invites future implementers to add a silent-empty-array consumer or to add emission and have downstream skills mis-handle a new field. Fix: trim the schema description in pipeline.md to match the producer, OR implement candidate pre-screening per the documented schema.
- **issue (non-blocking):** Report path collision at `skills/deep-review/pipeline.md:187`. The path is fully determined by date + branch — no run id, sha, or timestamp suffix. Two `/deep-review` runs on the same branch on the same day silently overwrite each other; the user gets the second report and never knows the first existed. Fix: include `$(git rev-parse --short HEAD)` in the filename — `.deep-review/<YYYY-MM-DD>-<branch-slug>-<short-sha>.md`. Idempotent at the same HEAD, distinct when HEAD has moved.
- **question:** Stage 5 fix dispatch (`skills/deep-review/pipeline.md:195`) reads as ambiguous on parallel-vs-sequential. "Dispatch one implementation subagent per blocking finding" is consistent with Stage 2's "ONE message containing N parallel Agent blocks" pattern, but "After each fix, run `$HARNESS_TEST_CMD`" reads sequentially. If two blocking findings live in the same file (plausible), two concurrent fix agents both read the original snapshot and write back overlapping edits — second `Edit` overwrites the first or fails on stale context. Could you pin this either way? "Dispatch ONE implementation subagent at a time; do not emit multiple Edit-permitted Agent blocks in the same message" would close it.
- **suggestion:** `.deep-review/` reports quote diff evidence verbatim (per the finding schema, `evidence: <quoted code, verbatim>`). If a diff under review contains a leaked secret — an inline API key in a test fixture, a hardcoded token in `.env.example` — this skill's own report quotes it verbatim and writes it under `.deep-review/`. Pipeline.md (`:189`) says teams choose whether to commit reports, which means the default-committable behavior wins for readers who never see that paragraph. The point of `/deep-review` is to *catch* secret leaks; the report itself shouldn't become a new exfil vector. Fix: have `setup.sh` add `.deep-review/` to `.gitignore` by default (same pattern as `.claude/logs/`).

### `.claude/agents/dim-investigator-deep.md`

- **nit (DISPUTED-flipped, was issue non-blocking):** I'd flagged conviction-floor drift between dim-investigator-deep.md (HIGH ≥ 0.5) and pipeline.md / triage.md (HIGH < 0.40). Revalidate disputed this — the layered design is intentional: the investigator floor is a self-suppression hint to the worker ("don't bother with marginal findings"), the triage floor is the catch-net. The numbers don't contradict; they describe different decision points. Worth leaving as a `nit` here so the next reader doesn't re-flag it, and worth a one-line comment near `dim-investigator-deep.md:84` saying so explicitly.

### `docs/deep-reviews/.gitkeep`

- **issue (non-blocking):** Empty `.gitkeep` at the deprecated report path. Every other reference in the PR uses `.deep-review/` (SKILL.md `:51, :66, :96`; pipeline.md `:187, :189`; eval.yaml `:31, :52`). Cleanup miss from the rename refactor in commit `58a6c4c`. Fix: `git rm docs/deep-reviews/.gitkeep && rmdir docs/deep-reviews`. (Also flagged by: `api-drift` at the same path.)

### `.claude/skills/deep-review/dimensions/.gitkeep`

- **nit:** Dead scaffolding artifact — the dimensions folder has 12 populated `.md` files; `.gitkeep` is no longer keeping anything. Fix: `git rm`.

### `.claude/skills/deep-review/eval.yaml`

- **suggestion:** `must_recognize` deliberately deferred to a follow-up PR (per the comment at `:11-14`), but `/deep-review` is a rigid skill whose Iron Law is precisely what the rationalizations are meant to defend. Shipping with `must_recognize` empty means the eval can pass even if the skill caves to time-pressure or authority rhetoric. The four scenario files under `docs/skill-baselines/_scenarios/deep-review-*.md` already exist; the trajectory_evals reference only two of them. Worth landing the follow-up PR before `/deep-review` is considered fully covered.

### `bin/skill-baseline`

- **suggestion:** `bin/skill-baseline --finalize` writes the contents of `--transcript <file>` verbatim into `docs/skill-baselines/<skill>-<date>.md`, which is committed. Today's scenarios are role-played and have no real user data, but a future contributor pasting a real debugging transcript could commit a real token. Fix: add a one-line warning at the prompt ("Review the transcript for secrets before pasting — it will be committed verbatim"); or have `--finalize` grep for common secret patterns with a `--force` override.

### `.claude/hooks/failure-log.sh`

- **issue (non-blocking):** JSONL append at `:15` can interleave on macOS when entries exceed `PIPE_BUF` (512 bytes). `TOOL_INPUT` is the full jq-compacted bash command; a 2KB command line easily crosses that threshold. Two concurrent failures (a flaky test yielding 3+ failures inside a few hundred ms is plausible) → corrupt JSONL line, downstream `jq -s` skips records. Fix: `( flock -x 200; echo ... >&200 ) 200>>"$LOG_DIR/failures.jsonl"`. Same shape applies to `hooks/pi/failure-log/index.ts` (which uses `appendFileSync`). (Also flagged by: `security` for JSON-escape fragility on the same line; and `observability` as a verbatim-tool_input note — fine because the file is gitignored, but worth knowing.)

### `bin/harness-update-check`

- **nit:** `JUST_UPGRADED_FILE` read-then-delete at `bin/harness-update-check:47` is not atomic. Two concurrent invocations across workspaces sharing `$HOME/.agent-harness` can both pass the `-f` test, both `cat`, then both `rm` — the notice prints in both sessions instead of one. Cosmetic. Fix: atomic claim via `mv` to a process-pid-suffixed name.

### `.claude/skills/deep-review/SKILL.md`

- **nit:** The placeholder-disclosure note at `:87` says "the four 'Universal counters' rows are the load-bearing protection," but `rationalizations.md` has six data rows. Fix: drop the count, or update to six.

### `CLAUDE.md`

- **note:** The repo-root `CLAUDE.md` heading at `:51` is `## Coding conventions (working on this harness)`, but `bin/deep-review-scan:86-87` extracts conventions via `^## *[Cc]onventions *$` — the trailing parenthetical breaks the anchor. SCAN emits an empty `conventions` string when `/deep-review` is run on this repo itself (which is the canonical dogfood path). Either rename the heading or widen the regex to `^## *[Cc]oding [Cc]onventions\b`.

## Worth calling out (5 items)

- **praise:** `bin/harness-update-check:87` — the strict version regex (`^[0-9]+\.[0-9.]+$`) on the fetched VERSION string is the right defensive pattern for a tool that touches the network. HTML error pages, redirected content, and hostile mirrors can't smuggle a payload into a value that's later only echoed. Easy to verify, small surface.
- **praise:** `bin/harness-update-check:67` — cache-first design with a TTL keeps the genuine per-skill-invocation hot path near zero cost. Combined with the simplified cache format on `:102`, this is the lowest-overhead path through what could easily have been a slow check.
- **praise:** `bin/conductor-status:23` (and the same shape in `bin/conductor-dispatch:16`) — the `HARNESS_HOST` mode gate exits before any per-workspace scanning for users not on Conductor. Net perf positive for plain Claude Code; sharp call given these scripts are wired into session-start hooks.
- **praise:** `bin/learn:192` — the `> "${TARGET}.tmp" && mv "${TARGET}.tmp" "$TARGET"` pattern is the right idiom for atomic file replacement. Worth naming because the bash reach-for is `> "$TARGET"`; future bin/ scripts (including the manifest write in `harness-update`, which doesn't do this) should follow.
- **praise:** `skills/deep-review/pipeline.md:278` — the Pipeline notes section in the report skeleton (dispatched count, delegated list, triage drops, revalidate verdict breakdown) is the right ratio of audit-trail to noise. Most "AI did N things" reports collapse the pipeline into a verdict and hide the steps; this keeps the receipt where a skeptical reader can find it. The SKILL.md/pipeline.md split itself is the same kind of sharp structural call — Iron Law and red flags stay in the body, mechanics live in the on-demand sub-file.

## What I audited

| # | Dimension | Verdict | Items raised | Revalidated |
|---|-----------|---------|--------------|-------------|
| 1 | security       | WARN | 1 blocking + 3 non-blocking          | yes |
| 2 | db             | N/A  | —                                    | n/a |
| 3 | langgraph      | N/A  | —                                    | n/a |
| 4 | structural     | WARN | 2 non-blocking + 1 praise            | yes (both) |
| 5 | performance    | WARN | 2 non-blocking + 1 suggestion + 2 praise | n/a |
| 6 | concurrency    | WARN | 3 non-blocking + 1 question + 1 nit + 1 praise | n/a |
| 7 | types          | N/A  | —                                    | n/a |
| 8 | error-handling | FAIL | 2 blocking + 1 suggestion            | yes (both) |
| 9 | observability  | PASS | 2 suggestions + 1 praise + 1 note    | n/a |
| 10 | tests         | FAIL | 1 blocking + 2 non-blocking          | yes (blocking) |
| 11 | api-drift     | WARN | 1 non-blocking (deduped to dead-code) | n/a |
| 12 | deps          | PASS | 0                                    | n/a |
| 13 | a11y          | N/A  | —                                    | n/a |
| 14 | dead-code     | WARN | 1 non-blocking + 1 suggestion + 1 nit + 1 note | yes (orphaned .gitkeep) |
| 15 | docs          | WARN | 1 nit + 1 question + 1 note          | n/a |

## N/A dimensions

- db — no migration files in the diff (no paths under `$HARNESS_DB_MIGRATIONS_DIR` or `$HARNESS_DB_SCHEMA_PATH`); SCAN gate evaluated to false.
- langgraph — `HARNESS_LANGGRAPH=false` and no paths match `src/agents/**` or `agents/**` in a LangGraph sense (the `agents/` here are Claude Code subagent definitions, not LG state graphs); SCAN gate evaluated to false.
- types — no TypeScript/Python source touched by this PR; the only `.ts` is `hooks/pi/**` (pre-existing). The harness has no Java/Go/Rust source either. The type-adjacent surface (frontmatter, YAML, JSON) all parses cleanly: `bin/test-frontmatter` returns 33/33 pass; `eval.yaml`, `settings.json`, and all 8 agent frontmatter blocks are well-formed.
- a11y — no frontend files (`.tsx/.jsx/.vue/.svelte/.html`) in the diff; SCAN gate evaluated to false.

## Pipeline notes

- Dispatched: 12 subagents in parallel at 2026-05-25T01:11Z (3 gated dims skipped: db, langgraph, a11y).
- Delegated: `security` (per the routing table — dispatched a subagent that invoked `/security-review` patterns directly rather than the slash command, since the orchestrator can't fire user-facing slash commands).
- Triage drops: 1 — `docs/deep-reviews/.gitkeep:1` flagged by both `api-drift` (issue, conv 0.85) and `dead-code` (issue, conv 0.95); kept dead-code's higher-conv citation, annotated "(also flagged by: api-drift)".
- Dedup cross-references retained: `hooks/shell/failure-log.sh:15` (concurrency byte-race + security JSON-escape + observability verbatim-FYI — three distinct concerns at one line; collapsed under concurrency with the others noted in prose).
- Revalidate: 7 findings examined — 6 CONFIRMED, 1 DISPUTED. DISPUTED was the conviction-floor "drift" between `dim-investigator-deep.md` and `pipeline.md`/`triage.md`; revalidate found the layered design is intentional (worker self-suppression floor at 0.5 + triage catch-net at 0.4). Demoted to `nit` and kept in report with the design rationale.
- No `FIXED-IN-HEAD` or `FIXED-IN-COMMIT` verdicts.
- Each `(blocking)` finding's evidence was read directly by the orchestrator (not just the subagent summary): `protected-files.sh:34`, `harness-update:275-285`, `deep-review-scan:33`, `tests/deep-review-validate.test.sh:13`. The validate-test breakage was also reproduced live.
