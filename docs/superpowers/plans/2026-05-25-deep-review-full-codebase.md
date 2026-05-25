# /deep-review Full-Codebase Mode — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `--full-codebase` mode to `/deep-review` that audits the entire tracked codebase chunk-by-chunk (by detected module boundary), gated by an explicit cost-acknowledgement prompt before any model fan-out.

**Architecture:** SCAN gets a new flag that walks `git ls-files`, groups files by detected manifest (`package.json`, `pyproject.toml`, `setup.py`, `go.mod`, `Cargo.toml`, `Gemfile`), and emits a chunk-shaped manifest. The orchestrator (SKILL.md prose) detects a natural-language trigger in args, prints a cost estimate, calls `AskUserQuestion` for Proceed/Cancel, then loops the existing 5-stage pipeline once per chunk. Validator extended to accept the aggregate report shape. No new binaries.

**Tech Stack:** Bash 3.2+ (stock macOS — no associative arrays; use `$'\n'`-delimited strings + awk filters, matching the existing script's `files_str` / `is_in_diff` pattern), Python 3 (for JSON assertions in tests), git CLI.

**Spec:** `docs/superpowers/specs/2026-05-25-deep-review-full-codebase-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `bin/deep-review-scan` | Modify | Add `--full-codebase` flag + module detection + chunk-shaped manifest emission |
| `bin/tests/deep-review-scan-full-codebase.test.sh` | Create | TDD tests for the new mode |
| `bin/deep-review-validate` | Modify | Accept aggregate report shape (full-codebase) alongside diff shape |
| `bin/tests/deep-review-validate.test.sh` | Modify | Add tests for aggregate report acceptance |
| `skills/deep-review/SKILL.md` | Modify | Trigger phrases in `description:`, cost callout, new `## Full-codebase mode` section, remove obsolete out-of-scope line, add Self-Review checkbox |
| `skills/deep-review/pipeline.md` | Modify | New `## Full-codebase mode` section describing manifest shape, cost gate, per-chunk loop, aggregate synthesis |
| `VERSION` | Modify | `0.19.1` → `0.20.0` |

---

## Task 1: Scan — TDD tests for `--full-codebase`

**Files:**
- Create: `bin/tests/deep-review-scan-full-codebase.test.sh`

The test file follows the existing convention from `bin/tests/deep-review-scan.test.sh`: each test creates a synthetic git repo under a tempdir, invokes `bin/deep-review-scan --full-codebase`, asserts the resulting JSON shape with Python.

- [ ] **Step 1: Create the failing test file**

```bash
cat > bin/tests/deep-review-scan-full-codebase.test.sh <<'TESTEOF'
#!/usr/bin/env bash
# bin/tests/deep-review-scan-full-codebase.test.sh — tests for the
# --full-codebase mode of deep-review-scan. Each test builds an isolated
# git repo under a tempdir and asserts the emitted JSON manifest.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
SCAN="$repo_root/bin/deep-review-scan"
test -x "$SCAN" || { echo "FAIL: $SCAN not executable"; exit 1; }

tmp=
cleanup() { [ -n "${tmp:-}" ] && rm -rf "$tmp"; return 0; }
trap cleanup EXIT

setup_repo() {
  cleanup
  tmp=$(mktemp -d)
  cd "$tmp"
  git init -q
  git config user.email "test@test"
  git config user.name "test"
}

# Test 1: no manifests anywhere → falls back to top-level dir chunks
setup_repo
mkdir -p src/api src/ui scripts
echo "a" > src/api/a.ts
echo "b" > src/ui/b.tsx
echo "c" > scripts/c.sh
echo "root" > README.md
git add . && git commit -q -m "base"

out=$("$SCAN" --full-codebase 2>&1) || { echo "FAIL test 1: scan exited nonzero"; echo "$out"; exit 1; }
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
assert m['mode'] == 'full-codebase', f'expected mode=full-codebase, got {m.get(\"mode\")!r}'
names = sorted(c['name'] for c in m['chunks'])
assert 'src' in names, f'expected src chunk, got {names}'
assert 'scripts' in names, f'expected scripts chunk, got {names}'
" || { echo "FAIL test 1"; echo "$out"; exit 1; }
echo "  test 1 OK (top-level fallback)"

# Test 2: package.json at subdir → that subdir is a chunk root
setup_repo
mkdir -p packages/web/src packages/cli/src
echo '{}' > packages/web/package.json
echo '{}' > packages/cli/package.json
echo "a" > packages/web/src/a.ts
echo "b" > packages/cli/src/b.ts
git add . && git commit -q -m "base"

out=$("$SCAN" --full-codebase 2>&1) || { echo "FAIL test 2: scan exited nonzero"; echo "$out"; exit 1; }
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
names = sorted(c['name'] for c in m['chunks'])
assert 'packages/web' in names, f'expected packages/web chunk, got {names}'
assert 'packages/cli' in names, f'expected packages/cli chunk, got {names}'
web = [c for c in m['chunks'] if c['name'] == 'packages/web'][0]
assert any(f.endswith('packages/web/src/a.ts') for f in web['files']), f'expected a.ts in web chunk, got {web[\"files\"]}'
assert not any('packages/cli' in f for f in web['files']), f'web chunk leaked cli files: {web[\"files\"]}'
" || { echo "FAIL test 2"; echo "$out"; exit 1; }
echo "  test 2 OK (package.json subdir = chunk)"

# Test 3: mixed-ecosystem (package.json + pyproject.toml)
setup_repo
mkdir -p web/src service
echo '{}' > web/package.json
echo "[project]" > service/pyproject.toml
echo "a" > web/src/a.ts
echo "b" > service/main.py
git add . && git commit -q -m "base"

out=$("$SCAN" --full-codebase 2>&1) || { echo "FAIL test 3"; echo "$out"; exit 1; }
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
names = sorted(c['name'] for c in m['chunks'])
assert 'web' in names and 'service' in names, f'expected web + service, got {names}'
" || { echo "FAIL test 3"; echo "$out"; exit 1; }
echo "  test 3 OK (mixed-ecosystem)"

# Test 4: .gitignored files do not appear in any chunk
setup_repo
mkdir -p src node_modules
echo "node_modules/" > .gitignore
echo "a" > src/a.ts
echo "bad" > node_modules/bad.js
git add .gitignore src/a.ts && git commit -q -m "base"

out=$("$SCAN" --full-codebase 2>&1) || { echo "FAIL test 4"; echo "$out"; exit 1; }
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
all_files = [f for c in m['chunks'] for f in c['files']]
assert not any('node_modules' in f for f in all_files), f'gitignored file leaked: {all_files}'
" || { echo "FAIL test 4"; echo "$out"; exit 1; }
echo "  test 4 OK (.gitignore respected)"

# Test 5: totals object present + sums
setup_repo
mkdir -p src
echo -e "a\nb\nc" > src/a.ts
echo -e "d\ne" > src/b.ts
git add . && git commit -q -m "base"

out=$("$SCAN" --full-codebase 2>&1) || { echo "FAIL test 5"; echo "$out"; exit 1; }
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
t = m.get('totals')
assert t is not None, 'totals missing'
assert t['files'] == 2, f'expected 2 files, got {t.get(\"files\")}'
assert t['chunks'] >= 1, f'expected at least 1 chunk, got {t.get(\"chunks\")}'
" || { echo "FAIL test 5"; echo "$out"; exit 1; }
echo "  test 5 OK (totals)"

# Test 6: per-chunk gate detection — a11y fires only on chunks with frontend files
setup_repo
mkdir -p ui/src api/src
echo '{}' > ui/package.json
echo '{}' > api/package.json
echo "export const X = () => <div/>;" > ui/src/x.tsx
echo "export const y = 1;" > api/src/y.ts
git add . && git commit -q -m "base"

out=$("$SCAN" --full-codebase 2>&1) || { echo "FAIL test 6"; echo "$out"; exit 1; }
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
ui = [c for c in m['chunks'] if c['name'] == 'ui'][0]
api = [c for c in m['chunks'] if c['name'] == 'api'][0]
assert ui['gates']['a11y'] is True, f'expected ui a11y=true, got {ui[\"gates\"]}'
assert api['gates']['a11y'] is False, f'expected api a11y=false, got {api[\"gates\"]}'
" || { echo "FAIL test 6"; echo "$out"; exit 1; }
echo "  test 6 OK (per-chunk a11y gate)"

# Test 7: back-compat — calling without --full-codebase still emits diff manifest
setup_repo
mkdir -p src
echo "a" > src/a.ts
git add . && git commit -q -m "base"
git checkout -q -b feature
echo "b" >> src/a.ts
git add . && git commit -q -m "feature"

out=$("$SCAN" 2>&1) || { echo "FAIL test 7"; echo "$out"; exit 1; }
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
assert 'diff' in m, 'diff field missing from default scan'
assert m.get('mode', 'diff') == 'diff', f'unexpected mode in default scan: {m.get(\"mode\")!r}'
" || { echo "FAIL test 7"; echo "$out"; exit 1; }
echo "  test 7 OK (back-compat)"

echo "PASS: bin/deep-review-scan --full-codebase"
TESTEOF
chmod +x bin/tests/deep-review-scan-full-codebase.test.sh
```

- [ ] **Step 2: Run the new test — expect it to fail (RED)**

Run: `bin/tests/deep-review-scan-full-codebase.test.sh`

Expected: `FAIL test 1` (or similar) — the script doesn't yet recognize `--full-codebase`, so it treats it as a bad git ref and exits with `{"error":"unknown base ref: --full-codebase"}`.

- [ ] **Step 3: Commit the failing test**

```bash
git add bin/tests/deep-review-scan-full-codebase.test.sh
git commit -m "test(deep-review): failing tests for --full-codebase scan mode"
```

---

## Task 2: Scan — implement `--full-codebase` (GREEN)

**Files:**
- Modify: `bin/deep-review-scan`

The new mode is implemented as a self-contained branch at the top of the script. The existing diff branch stays untouched.

- [ ] **Step 1: Add arg parsing for `--full-codebase`**

Replace the existing `BASE="${1:-main}"` block (around line 28) with a small parser that recognizes the flag while preserving the positional `BASE` argument for back-compat.

Old (around line 28):

```bash
BASE="${1:-main}"
```

New:

```bash
MODE="diff"
BASE="main"
positional=()
while [ $# -gt 0 ]; do
  case "$1" in
    --full-codebase) MODE="full-codebase" ;;
    --) shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done; break ;;
    -*) echo '{"error":"unknown flag: '"$1"'"}' >&2; exit 1 ;;
    *) positional+=("$1") ;;
  esac
  shift
done
if [ "${#positional[@]}" -gt 0 ]; then
  BASE="${positional[0]}"
fi
```

- [ ] **Step 2: Add a module-detection helper near the top of the script**

After the `cd "$repo_root"` line (around line 17) and the existing config sourcing, add this helper. Place it before the `BASE` parsing block from Step 1.

```bash
# Walk up from a path looking for a module manifest. Echoes the manifest's
# directory (relative to repo_root) or empty string if none found.
detect_module_root() {
  local dir
  dir=$(dirname "$1")
  while [ "$dir" != "." ] && [ "$dir" != "/" ] && [ -n "$dir" ]; do
    for m in package.json pyproject.toml setup.py go.mod Cargo.toml Gemfile; do
      if [ -f "$dir/$m" ]; then
        echo "$dir"
        return
      fi
    done
    dir=$(dirname "$dir")
  done
  for m in package.json pyproject.toml setup.py go.mod Cargo.toml Gemfile; do
    if [ -f "./$m" ]; then
      echo "."
      return
    fi
  done
  echo ""
}
```

- [ ] **Step 3: Add the full-codebase emission branch**

After the helpers (`emit_paths_json`, `emit_conventions_json`, `is_in_diff`, `emit_exemplars_lines_for_file`, `build_union_exemplars`) and after the `files_str` / `all_files` cache build (around line 187), but BEFORE the existing `cat <<EOF` that emits the diff-mode JSON (line 193), insert the full-codebase branch:

```bash
if [ "$MODE" = "full-codebase" ]; then
  # ===== Bash-3.2 compatible chunk grouping =====
  # No associative arrays (macOS ships bash 3.2). file_chunk_map is a
  # \n-delimited string of "<file>\t<chunk>" lines — same trick the existing
  # script uses for files_str / is_in_diff.
  file_chunk_map=""
  has_any_manifest=false

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    chunk=$(detect_module_root "$f")
    if [ -n "$chunk" ]; then
      has_any_manifest=true
    fi
    file_chunk_map="${file_chunk_map}${f}"$'\t'"${chunk}"$'\n'
  done <<< "$all_files"

  # Fallback to top-level dir if no manifests anywhere; else label empty → "misc".
  new_map=""
  while IFS=$'\t' read -r f c; do
    [ -z "$f" ] && continue
    if [ "$has_any_manifest" = "false" ]; then
      top="${f%%/*}"
      if [ "$top" = "$f" ]; then
        c="."
      else
        c="$top"
      fi
    else
      [ -z "$c" ] && c="misc"
    fi
    new_map="${new_map}${f}"$'\t'"${c}"$'\n'
  done <<< "$file_chunk_map"
  file_chunk_map="$new_map"

  # Unique sorted chunk names + per-chunk file lookup
  chunk_names_sorted=$(printf '%s' "$file_chunk_map" | awk -F'\t' 'NF>=2 && $2!="" {print $2}' | sort -u)

  files_in_chunk() {
    printf '%s' "$file_chunk_map" | awk -F'\t' -v c="$1" 'NF>=2 && $2==c {print $1}'
  }

  emit_chunk_paths_json() {
    local first=1
    printf '['
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      if [ $first -eq 1 ]; then first=0; else printf ','; fi
      local esc="${f//\\/\\\\}"; esc="${esc//\"/\\\"}"
      printf '"%s"' "$esc"
    done <<< "$1"
    printf ']'
  }

  emit_chunk_exemplars_json() {
    # Reuse build_union_exemplars by temporarily overriding files/files_str.
    local saved_files=("${files[@]+"${files[@]}"}")
    local saved_files_str="$files_str"
    files=()
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      files+=("$f")
    done <<< "$1"
    files_str=$'\n'
    for _f in "${files[@]+"${files[@]}"}"; do files_str="${files_str}${_f}"$'\n'; done
    build_union_exemplars
    files=("${saved_files[@]+"${saved_files[@]}"}")
    files_str="$saved_files_str"
  }

  chunk_gates() {
    local files_in="$1"
    local g_db=false g_lg=false g_a11y=false
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      if [ -n "$HARNESS_DB_MIGRATIONS_DIR" ] && [[ "$f" == "$HARNESS_DB_MIGRATIONS_DIR"* ]]; then
        g_db=true
      fi
      if [ -n "$HARNESS_DB_SCHEMA_PATH" ] && [[ "$f" == "$HARNESS_DB_SCHEMA_PATH"* ]]; then
        g_db=true
      fi
      if [ "$HARNESS_LANGGRAPH" = "true" ]; then
        case "$f" in src/agents/*|agents/*) g_lg=true ;; esac
      fi
      case "$f" in *.tsx|*.jsx|*.vue|*.svelte|*.html) g_a11y=true ;; esac
    done <<< "$files_in"
    printf '{"db":%s,"langgraph":%s,"a11y":%s}' "$g_db" "$g_lg" "$g_a11y"
  }

  conv_json=$(emit_conventions_json)
  total_files=0
  total_lines=0
  n_chunks=0

  chunks_json="["
  first_chunk=1
  while IFS= read -r cname; do
    [ -z "$cname" ] && continue
    n_chunks=$((n_chunks + 1))
    files_in=$(files_in_chunk "$cname")
    nfiles=$(printf '%s\n' "$files_in" | grep -c . || true)
    nlines=0
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      [ -f "$f" ] || continue
      flines=$(wc -l < "$f" 2>/dev/null | tr -d ' ' || echo 0)
      nlines=$((nlines + flines))
    done <<< "$files_in"
    total_files=$((total_files + nfiles))
    total_lines=$((total_lines + nlines))

    paths_j=$(emit_chunk_paths_json "$files_in")
    exemplars_j=$(emit_chunk_exemplars_json "$files_in")
    gates_j=$(chunk_gates "$files_in")
    g_db_v=$(echo "$gates_j" | python3 -c 'import sys,json;print(str(json.load(sys.stdin)["db"]).lower())')
    g_lg_v=$(echo "$gates_j" | python3 -c 'import sys,json;print(str(json.load(sys.stdin)["langgraph"]).lower())')
    g_a11y_v=$(echo "$gates_j" | python3 -c 'import sys,json;print(str(json.load(sys.stdin)["a11y"]).lower())')
    cname_esc="${cname//\\/\\\\}"; cname_esc="${cname_esc//\"/\\\"}"

    if [ $first_chunk -eq 1 ]; then first_chunk=0; else chunks_json="${chunks_json},"; fi
    chunks_json="${chunks_json}{\"name\":\"${cname_esc}\",\"files\":${paths_j},\"stats\":{\"files\":${nfiles},\"lines\":${nlines}},\"gates\":${gates_j},\"scopes\":{"
    chunks_json="${chunks_json}\"security\":{\"paths\":${paths_j},\"exemplars\":${exemplars_j}},"
    chunks_json="${chunks_json}\"db\":{\"paths\":${paths_j},\"exemplars\":${exemplars_j},\"active\":${g_db_v}},"
    chunks_json="${chunks_json}\"langgraph\":{\"paths\":${paths_j},\"exemplars\":${exemplars_j},\"active\":${g_lg_v}},"
    chunks_json="${chunks_json}\"structural\":{\"paths\":${paths_j},\"exemplars\":${exemplars_j}},"
    chunks_json="${chunks_json}\"performance\":{\"paths\":${paths_j},\"exemplars\":${exemplars_j}},"
    chunks_json="${chunks_json}\"concurrency\":{\"paths\":${paths_j},\"exemplars\":${exemplars_j}},"
    chunks_json="${chunks_json}\"types\":{\"paths\":${paths_j},\"exemplars\":${exemplars_j}},"
    chunks_json="${chunks_json}\"error-handling\":{\"paths\":${paths_j},\"exemplars\":${exemplars_j}},"
    chunks_json="${chunks_json}\"observability\":{\"paths\":${paths_j},\"exemplars\":${exemplars_j}},"
    chunks_json="${chunks_json}\"tests\":{\"paths\":${paths_j},\"exemplars\":${exemplars_j}},"
    chunks_json="${chunks_json}\"api-drift\":{\"paths\":${paths_j},\"exemplars\":${exemplars_j}},"
    chunks_json="${chunks_json}\"deps\":{\"paths\":${paths_j},\"exemplars\":${exemplars_j}},"
    chunks_json="${chunks_json}\"a11y\":{\"paths\":${paths_j},\"exemplars\":${exemplars_j},\"active\":${g_a11y_v}},"
    chunks_json="${chunks_json}\"dead-code\":{\"paths\":${paths_j},\"exemplars\":${exemplars_j}},"
    chunks_json="${chunks_json}\"docs\":{\"paths\":${paths_j},\"exemplars\":${exemplars_j}}"
    chunks_json="${chunks_json}}}"
  done <<< "$chunk_names_sorted"
  chunks_json="${chunks_json}]"

  cat <<EOF2
{
  "mode": "full-codebase",
  "chunks": ${chunks_json},
  "conventions": ${conv_json},
  "totals": { "chunks": ${n_chunks}, "files": ${total_files}, "lines": ${total_lines} }
}
EOF2
  exit 0
fi
```

The `exit 0` at the end ensures we never fall through into the diff-mode emission below.

- [ ] **Step 4: Run the new test — expect it to pass (GREEN)**

Run: `bin/tests/deep-review-scan-full-codebase.test.sh`

Expected: `PASS: bin/deep-review-scan --full-codebase` (all 7 sub-tests passing).

- [ ] **Step 5: Run the existing diff-mode scan test to confirm no regression**

Run: `bin/tests/deep-review-scan.test.sh`

Expected: `PASS: bin/deep-review-scan smoke test` — unchanged behavior in diff mode.

- [ ] **Step 6: Commit**

```bash
git add bin/deep-review-scan
git commit -m "feat(deep-review): scan --full-codebase mode emits chunked manifest"
```

---

## Task 3: Validator — accept aggregate report shape

**Files:**
- Modify: `bin/deep-review-validate`
- Modify: `bin/tests/deep-review-validate.test.sh`

The aggregate report differs from the diff report in three ways:
1. `**Scope:** Full codebase ...` line instead of `**Diff:** main..HEAD ...`.
2. A top-level `## Chunks reviewed` table summarising per-chunk verdicts.
3. Each chunk's dimension matrix lives inside a `## Chunk: <name>` subsection (the validator's existing matrix check still applies, since markdown matrices match anywhere in the file).

Most validator logic still works (dimension matrix grep, N/A justification grep, blocking-pairing grep, verdict-line grep) — the matrix happens to appear once per chunk in the aggregate, but the validator currently just checks "does any matrix row name this dim", which is still true.

The validator needs ONE change: when the report is full-codebase (detectable by the `**Scope:** Full codebase` line), require the presence of `## Chunks reviewed` and accept the per-chunk subsection structure.

- [ ] **Step 1: Add failing tests to `bin/tests/deep-review-validate.test.sh`**

Append these tests to the file, before the final `echo "PASS:"` line. Use `Edit` to insert before `echo "PASS: bin/deep-review-validate smoke test"`.

```bash
# 8. Full-codebase aggregate report — must pass
cat > "$tmp/full-codebase-good.md" <<EOF
# Code Review — full-codebase
**Date:** 2026-05-25
**Scope:** Full codebase (2 chunks, 5 files, 200 lines)

**Verdict:** Ship it

## Chunks reviewed
| # | Chunk | Files | Lines | Verdict | (blocking) items |
|---|-------|-------|-------|---------|-----------------|
| 1 | web   | 3     | 120   | Ship it | 0                |
| 2 | api   | 2     | 80    | Ship it | 0                |

## Chunk: web

$matrix

## Chunk: api

$matrix
EOF

"\$VAL" "\$tmp/full-codebase-good.md" >/dev/null \
  || { echo "FAIL: validator rejected a complete full-codebase aggregate"; exit 1; }

# 9. Full-codebase report missing the "## Chunks reviewed" section — must fail
cat > "$tmp/full-codebase-no-chunks-table.md" <<EOF
# Code Review — full-codebase
**Scope:** Full codebase (1 chunk, 1 file, 10 lines)

**Verdict:** Ship it

## Chunk: web

$matrix
EOF

"\$VAL" "\$tmp/full-codebase-no-chunks-table.md" >/dev/null 2>&1 \
  && { echo "FAIL: validator accepted full-codebase report missing '## Chunks reviewed' table"; exit 1; }
```

Concrete Edit instruction: find the line `echo "PASS: bin/deep-review-validate smoke test"` and prepend the above block immediately before it.

- [ ] **Step 2: Run the test — expect new tests to fail (RED)**

Run: `bin/tests/deep-review-validate.test.sh`

Expected: `FAIL: validator rejected a complete full-codebase aggregate` — because the validator's "Verdict line" check matches but other implicit assumptions may fail; more importantly, the missing-`## Chunks reviewed` test will fail (the validator currently doesn't check for that section at all, so it'll PASS the bad report).

- [ ] **Step 3: Extend the validator**

Modify `bin/deep-review-validate`. After the existing rule-4 (verdict-line) block and before the `if [ $fail -eq 0 ]` final block, insert:

```bash
# 5. Full-codebase aggregate reports must include a "## Chunks reviewed" table.
#    Detect aggregate shape via the "**Scope:** Full codebase" line.
if grep -qE '^\*\*Scope:\*\* *Full codebase' "$REPORT"; then
  if ! grep -q "^## Chunks reviewed" "$REPORT"; then
    echo "FAIL: full-codebase report missing '## Chunks reviewed' section" >&2
    fail=1
  fi
fi
```

- [ ] **Step 4: Run the validator test — expect GREEN**

Run: `bin/tests/deep-review-validate.test.sh`

Expected: `PASS: bin/deep-review-validate smoke test` — all 9 sub-tests passing.

- [ ] **Step 5: Commit**

```bash
git add bin/deep-review-validate bin/tests/deep-review-validate.test.sh
git commit -m "feat(deep-review): validate aggregate full-codebase reports"
```

---

## Task 4: SKILL.md — trigger phrases, cost callout, new section, cleanups

**Files:**
- Modify: `skills/deep-review/SKILL.md`

Four discrete edits, in order. Each one is an exact `Edit` with `old_string` + `new_string`.

- [ ] **Step 1: Update the `description:` frontmatter to include full-codebase trigger phrases**

`old_string`:

```
description: Use when the user says "/deep-review", "deep review", "thorough review", or wants the deepest possible code review before pushing a branch.
```

`new_string`:

```
description: Use when the user says "/deep-review", "deep review", "thorough review", "deep-review the entire codebase", "deep-review the whole repo", or wants the deepest possible code review before pushing a branch. Includes a full-codebase mode triggered by NL phrases like "entire codebase" / "full codebase" / "whole repo" / "whole codebase" in args.
```

- [ ] **Step 2: Update the line-20 cost callout**

`old_string`:

```
The deepest pre-ship code review tier. Runs a 6-stage pipeline (SCAN → DISPATCH → TRIAGE → REVALIDATE → DECIDE → SYNTHESIZE) across 15 dimensions in parallel, then delivers the result as a code review — not a severity-graded incident report. Advisory only; does not auto-fire from `/ship` or `/pre-deploy`. Optimized for completeness over speed; typical mid-PR cost is $10–15 and 3–8 minutes wall-clock.
```

`new_string`:

```
The deepest pre-ship code review tier. Runs a 6-stage pipeline (SCAN → DISPATCH → TRIAGE → REVALIDATE → DECIDE → SYNTHESIZE) across 15 dimensions in parallel, then delivers the result as a code review — not a severity-graded incident report. Advisory only; does not auto-fire from `/ship` or `/pre-deploy`. Optimized for completeness over speed; typical mid-PR cost is $10–15 and 3–8 minutes wall-clock. **Full-codebase mode** (triggered by NL phrases like "the entire codebase" / "the whole repo" in args) audits every tracked file chunk-by-chunk; cost scales ≈ `$10–15 × chunk-count` and wall-clock ≈ `3–8 min × chunk-count`. A cost-gate `AskUserQuestion` fires before any model dispatch.
```

- [ ] **Step 3: Add the `## Full-codebase mode` section**

Find the line `## Red Flags — STOP` and insert the new section immediately above it (i.e. between the end of `## Gate Sequence` block and the start of `## Red Flags`).

`old_string`:

```
## Red Flags — STOP
```

`new_string`:

```
## Full-codebase mode

Triggered by NL phrases in the `/deep-review` args. Detect by substring match (case-insensitive) against the user's arg string:

- `entire codebase`
- `full codebase`
- `whole codebase`
- `whole repo`
- `the whole repository`

Any match → full-codebase mode. No match → default branch-diff mode (unchanged).

**Stage 0.5 — cost gate (mandatory).** After SCAN returns the chunk manifest, BEFORE any Stage 2 dispatch, the orchestrator:

1. Reads `totals.chunks` from the manifest.
2. Computes `low = chunks × $10`, `high = chunks × $15`, `low_min = chunks × 3`, `high_min = chunks × 8`.
3. Prints the chunk list (name, file count, line count) to the transcript.
4. Calls `AskUserQuestion` with one single-select question:
   - `question`: "Full-codebase /deep-review will run the 15-dim pipeline against N chunks. Proceed?"
   - `header`: "Cost gate"
   - `options`:
     - `{label: "Proceed", description: "Estimated cost $<low>–$<high>, wall-clock ~<low_min>–<high_min> min."}`
     - `{label: "Cancel", description: "Abort. No model calls made."}`
5. If the user answers `Cancel`, exit cleanly with a one-line note and NO report written.

**Per-chunk loop.** For each chunk in `manifest.chunks`, run Stages 2–5 exactly as documented in `pipeline.md` (parallel 15-dim fan-out within the chunk, sequential between chunks). Each chunk's scope packet uses the chunk's `paths` and `exemplars`. Stage 4.5 DECIDE cap raised from 4 to 8 per chunk.

**Aggregate synthesis.** After all chunks complete, compose one report at `.deep-review/<YYYY-MM-DD>-full-codebase-<short-sha>.md`. Top-level verdict rolls up the worst per-chunk verdict (`Substantial concerns` > `Address blocking items first` > `Ship it`). See `pipeline.md` § Full-codebase mode for the report skeleton.

## Red Flags — STOP
```

- [ ] **Step 4: Remove the obsolete out-of-scope line**

`old_string`:

```
- **Full-repo / module-wide audits.** Scope is always `main..HEAD`. Repo-wide deepsec-style scans are a future feature.
```

`new_string`:

```
```

(i.e. delete the line entirely. The surrounding bullets stay.)

- [ ] **Step 5: Add a Self-Review checkbox**

`old_string`:

```
- [ ] Every `issue (blocking)` is paired with a concrete `suggestion`. If not, the review is incomplete.
```

`new_string`:

```
- [ ] Every `issue (blocking)` is paired with a concrete `suggestion`. If not, the review is incomplete.
- [ ] If full-codebase mode: cost gate `AskUserQuestion` was acknowledged with `Proceed` before any Stage 2 dispatch; aggregate report includes the `## Chunks reviewed` table and per-chunk subsections.
```

- [ ] **Step 6: Commit**

```bash
git add skills/deep-review/SKILL.md
git commit -m "feat(deep-review): document full-codebase mode in SKILL.md"
```

---

## Task 5: pipeline.md — Full-codebase mode mechanics section

**Files:**
- Modify: `skills/deep-review/pipeline.md`

- [ ] **Step 1: Append a new `## Full-codebase mode` section to pipeline.md**

Use `Edit` to insert at the end of the file (after the existing last line "Per-finding labels follow Conventional Comments, which gives the reader fast scannability without implying false severity precision.").

`old_string`:

```
- Per-finding labels follow Conventional Comments, which gives the reader fast scannability without implying false severity precision.
```

`new_string`:

```
- Per-finding labels follow Conventional Comments, which gives the reader fast scannability without implying false severity precision.

---

## Full-codebase mode

Triggered from `SKILL.md` § Full-codebase mode. This section documents the mechanics: manifest shape, cost gate, per-chunk loop, aggregate synthesis.

### Stage 1 — SCAN (`bin/deep-review-scan --full-codebase`)

Invoke `bin/deep-review-scan --full-codebase`. The scan walks `git ls-files` (honoring `.gitignore`), groups files by detected module manifest, and emits:

```json
{
  "mode": "full-codebase",
  "chunks": [
    {
      "name": "packages/web",
      "files": ["packages/web/src/a.ts", ...],
      "stats": {"files": 42, "lines": 8400},
      "gates": {"db": false, "langgraph": false, "a11y": true},
      "scopes": { "<dim>": { "paths": [...], "exemplars": [...] } }
    },
    ...
  ],
  "conventions": "<verbatim ## Conventions from CLAUDE.md>",
  "totals": {"chunks": N, "files": M, "lines": K}
}
```

Module detection walks each file's parent directories looking for `package.json`, `pyproject.toml`, `setup.py`, `go.mod`, `Cargo.toml`, or `Gemfile`. If no manifest is found anywhere in the repo, the scan falls back to top-level-directory grouping (one chunk per top-level dir, plus a `.` chunk for root files). Files under no detected module root go to a `misc` chunk.

### Stage 0.5 — cost gate

Mandatory before any Stage 2 dispatch in full-codebase mode. The orchestrator:

1. Reads `manifest.totals.chunks` (call it `N`).
2. Prints the chunk list to the transcript: `chunk-name (file-count files, line-count lines)`, sorted descending by line count.
3. Calls `AskUserQuestion`:
   - `question`: `"Full-codebase /deep-review will run the 15-dim pipeline against <N> chunks. Proceed?"`
   - `header`: `"Cost gate"`
   - `options`:
     - `Proceed` — `description`: `"Estimated cost $<N×10>–$<N×15>, wall-clock ~<N×3>–<N×8> min."`
     - `Cancel` — `description`: `"Abort. No model calls made."`
4. `Cancel` → exit with `"/deep-review --full-codebase cancelled at cost gate."` and no report file. `Proceed` → continue to the per-chunk loop.

### Stages 2–5 per chunk

For each chunk in `manifest.chunks`:
- **Stage 2 DISPATCH.** Emit one message with N parallel `Agent` calls (15 minus gated-skip count). The SCOPE PACKET section of each per-dim prompt drops the "Diff hunks" subsection and uses `"File contents:"` instead — subagents read whole files in the chunk's paths.
- **Stage 3 TRIAGE.** Same conviction floors per FP profile.
- **Stage 4 REVALIDATE.** Same trigger rules.
- **Stage 4.5 DECIDE.** Cap raised from 4 to **8 per chunk** since full-codebase audits legitimately surface more pattern divergences.
- **Stage 5 partial synthesis.** Build the per-chunk report fragment using today's report skeleton, with `**Diff:**` replaced by `**Scope:** <chunk-name> (<files> files, <lines> lines)`.

Chunks run sequentially in the orchestrator's outer loop.

### Stage 5.5 — aggregate synthesis

Compose the aggregate report at `.deep-review/<YYYY-MM-DD>-full-codebase-<short-sha>.md`. Top-level verdict rolls up the worst per-chunk verdict: any chunk `Substantial concerns` → aggregate `Substantial concerns`; else any chunk `Address blocking items first` → aggregate `Address blocking items first`; else `Ship it`.

Skeleton:

```markdown
# Code Review — full-codebase
**Date:** <YYYY-MM-DD>
**Scope:** Full codebase (<N> chunks, <M> files, <K> lines)
**Commit:** <short-sha>
**Reviewer:** /deep-review --full-codebase (<N> × (SCAN → 15 dim subagents → triage → revalidate → decide → synthesis))

## Summary

<one paragraph; aggregate framing>

**Verdict:** Ship it | Address blocking items first | Substantial concerns

## Chunks reviewed

| # | Chunk | Files | Lines | Verdict | (blocking) items |
|---|-------|-------|-------|---------|-----------------|
| 1 | <name> | <N> | <L> | <verdict> | <count> |
| ... | | | | | |

## Chunk: <module-name>

<the per-chunk report skeleton, as-is — with **Scope:** instead of **Diff:**>

## Chunk: <next-module>

<...>

## Conventions recorded (aggregate)

<merged from all chunks; same per-domain format>

## Pipeline notes

- Mode: full-codebase
- Chunks: <N>
- Total dispatches: <N × 15> (minus gated skips)
- Cost (estimated): $<low>–$<high>
- Wall-clock (actual): <recorded by orchestrator>
```

Run `bin/deep-review-validate <path>` — must exit 0. Apply-fixes prompt runs once at the aggregate level, listing all `(blocking)` findings across chunks.

### Validator notes

`bin/deep-review-validate` accepts both diff and aggregate shapes. For aggregate reports (detected by the `**Scope:** Full codebase` prefix), the validator additionally requires a `## Chunks reviewed` section. Per-chunk dimension matrices satisfy the existing matrix-row checks because each chunk's `## What I audited` table is grep-matched at file scope.
```

- [ ] **Step 2: Commit**

```bash
git add skills/deep-review/pipeline.md
git commit -m "feat(deep-review): document full-codebase pipeline in pipeline.md"
```

---

## Task 6: VERSION bump + run full test suite

**Files:**
- Modify: `VERSION`

- [ ] **Step 1: Bump VERSION**

Use `Edit`:

`old_string`:

```
0.19.1
```

`new_string`:

```
0.20.0
```

- [ ] **Step 2: Run the full test suite**

Run: `bin/test-all`

Expected: every `*.test.sh` passes (specifically including `deep-review-scan.test.sh`, `deep-review-scan-full-codebase.test.sh`, `deep-review-validate.test.sh`). If any test fails, stop and diagnose — do not commit until green.

- [ ] **Step 3: Commit VERSION bump**

```bash
git add VERSION
git commit -m "chore: bump version to 0.20.0

Adds /deep-review --full-codebase mode."
```

---

## Task 7: Manual end-to-end sanity check

**Files:** none (read-only validation)

This is a sanity check — no commits — to confirm the orchestrator wiring works in practice against a real repo. The harness itself is the test target.

- [ ] **Step 1: Run the scan manually and inspect**

Run: `bin/deep-review-scan --full-codebase | python3 -m json.tool | head -40`

Expected: valid JSON with `"mode": "full-codebase"`, a `chunks` array (at least one entry — the harness itself has no `package.json`/`pyproject.toml`/etc. in its tracked tree so it should fall back to top-level dirs: `bin`, `skills`, `prompts`, `docs`, etc.), and a `totals` object.

- [ ] **Step 2: Verify chunk membership for a known file**

Run: `bin/deep-review-scan --full-codebase | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
for c in m['chunks']:
    if any(f.startswith('bin/') for f in c['files']):
        print(f'bin files in chunk: {c[\"name\"]}')
        break
"`

Expected: a single line showing `bin files in chunk: bin` (or similar) — confirming the top-level-dir fallback grouped correctly.

- [ ] **Step 3: Sanity-check that the cost-gate prompt the orchestrator will assemble makes sense**

Run: `bin/deep-review-scan --full-codebase | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
n = m['totals']['chunks']
print(f'Would prompt: cost \${n*10}-\${n*15}, wall-clock ~{n*3}-{n*8} min, across {n} chunks')
for c in sorted(m['chunks'], key=lambda x: -x['stats']['lines']):
    print(f'  - {c[\"name\"]}: {c[\"stats\"][\"files\"]} files, {c[\"stats\"][\"lines\"]} lines')
"`

Expected: a plausible cost line + a chunk breakdown sorted by lines descending.

No commit for this task — it's a final smoke check.

---

## Self-Review

Spec coverage check (each spec section → which task implements it):

| Spec section | Implemented in |
|--------------|----------------|
| Trigger (NL phrase parsing) | Task 4 Step 1 (description) + Task 4 Step 3 (Full-codebase mode section). Parsing logic is in the orchestrator prose, not in code. |
| Stage 1 SCAN (`--full-codebase` flag, module detection, manifest) | Tasks 1, 2 |
| Cost gate (`AskUserQuestion` Stage 0.5) | Task 4 Step 3, Task 5 Step 1 (documented contract; runtime is the orchestrator) |
| Stages 2–5 per chunk | Task 5 Step 1 (per-chunk loop semantics) |
| Stage 5.5 aggregate synthesis | Task 5 Step 1 (report skeleton) |
| Validator changes | Task 3 |
| `bin/deep-review-record-convention` (no change) | covered — explicitly listed as unchanged in plan/spec |
| SKILL.md description, cost callout, new section, remove old line, self-review checkbox | Task 4 (all 5 steps) |
| pipeline.md new section | Task 5 |
| VERSION bump | Task 6 |
| Risks: validator regression | Task 3 Step 4 explicitly re-runs existing tests; Task 6 Step 2 runs full suite |
| Testing | Tasks 1–3 (TDD), Task 6 Step 2 (full suite), Task 7 (manual E2E) |

No spec gaps identified.

Placeholder scan: every step contains literal code, exact paths, and exact run commands. No `TBD`/`TODO`/`fill in` remains.

Type consistency: the manifest field names (`mode`, `chunks`, `files`, `stats`, `gates`, `scopes`, `conventions`, `totals`) match across spec, plan, scan implementation, validator detection, and tests. Cost-gate copy uses the same `Proceed` / `Cancel` labels everywhere.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-25-deep-review-full-codebase.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
