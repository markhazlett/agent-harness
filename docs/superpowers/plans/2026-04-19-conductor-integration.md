# Conductor Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the agent-harness so `/plan-sprint` detects parallel-safe waves and dispatches Conductor workspaces, and `/build` maintains per-workspace status + internally orchestrates quality skills. Ship a SessionStart hook for sibling-workspace awareness and auto-generate `conductor.json` from `setup.sh`.

**Architecture:** Two new bash helpers (`bin/conductor-status`, `bin/conductor-dispatch`) hold all Conductor-specific mechanics. One new hook (`conductor-context.sh`) injects sibling state at SessionStart. Skills (`/plan-sprint`, `/build`) are edited to invoke the helpers and use the new status-file contract. `setup.sh` gains a second output: `conductor.json`. Shared state is a per-workspace `.context/conductor-status.json` file; siblings read each other via the filesystem layout `~/conductor/workspaces/<repo>/*/`.

**Tech Stack:** Bash + `jq` (matches existing hooks), plain-markdown skill files, macOS `open` for deep links. Tests are bash scripts under `bin/tests/` invoked with `bash <file>`.

**Spec:** `docs/superpowers/specs/2026-04-19-conductor-integration-design.md`

---

## File Structure

### Creates
- `bin/conductor-status` — CLI for reading/updating/listing the per-workspace status manifest
- `bin/conductor-dispatch` — CLI that base64-encodes a plan and `open`s a `conductor://async` deep link
- `bin/tests/conductor-status.test.sh` — shell tests for status helper
- `bin/tests/conductor-dispatch.test.sh` — shell tests for dispatch helper
- `bin/tests/conductor-context.test.sh` — shell tests for the hook
- `.claude/hooks/conductor-context.sh` — SessionStart hook that injects sibling rollup
- `docs/superpowers/reference/conductor-json-schema.md` — captured schema from Conductor docs (reference for setup.sh)

### Modifies
- `.claude/settings.json` — wire the new hook into `SessionStart` (matcher `startup`)
- `setup.sh` — add a segment that generates `conductor.json` at repo root
- `.claude/skills/plan-sprint/SKILL.md` — add Parallel-safe field to plan template, add Phase 3.5 (wave detection), Phase 5 (dispatch offer)
- `.claude/skills/build-plan/SKILL.md` — add status-file maintenance at phase boundaries, add internal quality-skill decision rules, add Conductor Todos probe
- `.claude/commands/harness-health.md` — add probes for new files
- `VERSION` — bump `0.2.0` → `0.3.0`
- `README.md` — add "Conductor integration" section

### Reads (no modifications)
- `.claude/hooks/init.sh` — pattern for SessionStart hook output
- `.claude/hooks/harness.config.sh` — sourced by new hook
- `.claude/skills/ship/SKILL.md` — understand how /ship ends so /build's status update runs at the right moment

---

## Task 1: Capture Conductor schemas (reference)

**Files:**
- Create: `docs/superpowers/reference/conductor-json-schema.md`

- [ ] **Step 1: Fetch the scripts docs and write reference**

Use WebFetch on `https://docs.conductor.build/core/scripts` asking for the exact `conductor.json` structure, required keys, optional keys, and any version field. Also fetch `https://docs.conductor.build/core/deep-links` for the deep-link formats.

Write `docs/superpowers/reference/conductor-json-schema.md` containing:

````markdown
# Conductor reference

Captured: 2026-04-19. Re-run Task 1 of the conductor-integration plan if Conductor changes.

## conductor.json schema

```json
{
  "scripts": {
    "setup": "<zsh script — runs each time you create a workspace>",
    "run":   "<zsh script — triggered by the Run button>",
    "archive": "<zsh script — runs when archiving a workspace>"
  }
}
```

**Execution:** scripts run under zsh with Conductor env vars available.
**Process lifecycle:** on teardown Conductor sends `SIGHUP`, waits 200ms, then `SIGKILL`.

## Deep link formats

- `conductor://prompt=<encoded-prompt>` — new workspace, first repo, prompt pre-filled
- `conductor://prompt=<encoded-prompt>&path=<repo-path>` — targets a specific repo path
- `conductor://linear_id=<issue-id>&prompt=<optional-encoded-prompt>` — Linear issue
- `conductor://async?repo=<repo>&plan=<base64-md>` — attaches a base64-encoded markdown plan file

All values URL-encoded; `async` uses standard URL structure with hostname, others use flat `key=value&key=value`.
````

If the fetched docs contradict any of the above, update this file AND the design spec, AND propagate the correction into `setup.sh` and `bin/conductor-dispatch` before finishing later tasks.

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/reference/conductor-json-schema.md
git commit -m "docs(reference): capture Conductor schemas for integration

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: `bin/conductor-status` — failing tests

**Files:**
- Create: `bin/tests/conductor-status.test.sh`

- [ ] **Step 1: Write the test script**

```bash
#!/usr/bin/env bash
# Tests for bin/conductor-status.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BIN="$REPO_ROOT/bin/conductor-status"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

# ── Setup: fake workspaces root with 3 sibling workspaces ──
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT
mkdir -p "$ROOT/repo/alpha/.context" "$ROOT/repo/bravo/.context" "$ROOT/repo/charlie/.context"

cat > "$ROOT/repo/alpha/.context/conductor-status.json" <<'EOF'
{"schema_version":1,"workspace":"alpha","repo":"repo","plan":"docs/plans/2026-w16/sprint-plans/P0.1.md","branch":"feat/a","phase":"implementing","done_criteria":[],"dev_server_port":3000,"pr_url":null,"last_error":null,"started_at":"2026-04-19T10:00:00Z","updated_at":"2026-04-19T10:05:00Z"}
EOF
cat > "$ROOT/repo/bravo/.context/conductor-status.json" <<'EOF'
{"schema_version":1,"workspace":"bravo","repo":"repo","plan":"docs/plans/2026-w16/sprint-plans/P0.2.md","branch":"feat/b","phase":"shipped","done_criteria":[],"dev_server_port":null,"pr_url":"https://github.com/x/y/pull/42","last_error":null,"started_at":"2026-04-19T09:00:00Z","updated_at":"2026-04-19T11:00:00Z"}
EOF

# ── Test: `get` reads a field from the current workspace's status ──
out=$(cd "$ROOT/repo/alpha" && "$BIN" get phase)
[[ "$out" == "implementing" ]] || fail "get phase" "got '$out'"
pass "get phase"

out=$(cd "$ROOT/repo/alpha" && "$BIN" get branch)
[[ "$out" == "feat/a" ]] || fail "get branch" "got '$out'"
pass "get branch"

# ── Test: `get` on missing file returns empty + exits 0 ──
out=$(cd "$ROOT/repo/charlie" && "$BIN" get phase)
[[ -z "$out" ]] || fail "get on missing file returns empty" "got '$out'"
pass "get on missing file returns empty"

# ── Test: `update` creates the status file with initial fields ──
(cd "$ROOT/repo/charlie" && "$BIN" update phase=planning workspace=charlie repo=repo)
[[ -f "$ROOT/repo/charlie/.context/conductor-status.json" ]] || fail "update creates file" "file not found"
phase=$(jq -r .phase "$ROOT/repo/charlie/.context/conductor-status.json")
[[ "$phase" == "planning" ]] || fail "update writes phase" "got '$phase'"
sv=$(jq -r .schema_version "$ROOT/repo/charlie/.context/conductor-status.json")
[[ "$sv" == "1" ]] || fail "update writes schema_version=1" "got '$sv'"
pass "update creates file with fields"

# ── Test: `update` preserves existing fields when updating one ──
(cd "$ROOT/repo/alpha" && "$BIN" update phase=verifying)
phase=$(jq -r .phase "$ROOT/repo/alpha/.context/conductor-status.json")
branch=$(jq -r .branch "$ROOT/repo/alpha/.context/conductor-status.json")
[[ "$phase" == "verifying" ]] || fail "update phase preserved others" "got phase=$phase"
[[ "$branch" == "feat/a" ]] || fail "update preserves branch" "got branch=$branch"
pass "update preserves other fields"

# ── Test: `update` sets updated_at to a fresh ISO-8601 timestamp ──
sleep 1
(cd "$ROOT/repo/alpha" && "$BIN" update phase=verifying)
updated=$(jq -r .updated_at "$ROOT/repo/alpha/.context/conductor-status.json")
[[ "$updated" =~ ^2[0-9]{3}-[0-9]{2}-[0-9]{2}T ]] || fail "update sets ISO-8601 updated_at" "got '$updated'"
pass "update sets updated_at"

# ── Test: `list` honors CONDUCTOR_WORKSPACES_ROOT + prints rollup ──
out=$(CONDUCTOR_WORKSPACES_ROOT="$ROOT" CONDUCTOR_REPO_NAME=repo "$BIN" list)
echo "$out" | grep -q "alpha" || fail "list includes alpha" "output: $out"
echo "$out" | grep -q "bravo" || fail "list includes bravo" "output: $out"
echo "$out" | grep -q "verifying" || fail "list shows phase" "output: $out"
echo "$out" | grep -q "shipped" || fail "list shows shipped" "output: $out"
pass "list prints rollup"

# ── Test: `list` excludes the current workspace when run from inside one ──
out=$(cd "$ROOT/repo/alpha" && CONDUCTOR_WORKSPACES_ROOT="$ROOT" CONDUCTOR_REPO_NAME=repo "$BIN" list --exclude-self)
echo "$out" | grep -q "alpha" && fail "list --exclude-self omits self" "alpha unexpectedly present: $out" || true
echo "$out" | grep -q "bravo" || fail "list --exclude-self still shows bravo" "output: $out"
pass "list --exclude-self omits current workspace"

echo ""
echo "ALL PASSED"
```

- [ ] **Step 2: Run and verify failure**

```bash
chmod +x bin/tests/conductor-status.test.sh
bash bin/tests/conductor-status.test.sh
```

Expected: FAIL with `conductor-status: command not found` or similar (the script doesn't exist yet).

---

## Task 3: `bin/conductor-status` — implementation

**Files:**
- Create: `bin/conductor-status`

- [ ] **Step 1: Write the implementation**

```bash
#!/usr/bin/env bash
# =============================================================================
# conductor-status — per-workspace status manifest CLI.
#
# Subcommands:
#   get <key>                            — print a field from current workspace
#   update <key>=<val> [<key>=<val>...]  — merge fields into current workspace's status
#   list [--exclude-self]                — print a rollup of sibling workspaces
#
# Resolves the workspace root (current dir by default). The manifest lives at
# <workspace>/.context/conductor-status.json.
#
# Env overrides (used by tests):
#   CONDUCTOR_WORKSPACES_ROOT — override ~/conductor/workspaces
#   CONDUCTOR_REPO_NAME       — override repo-name detection
# =============================================================================
set -euo pipefail

workspace_root() { pwd; }

status_file() { echo "$(workspace_root)/.context/conductor-status.json"; }

ensure_context_dir() { mkdir -p "$(workspace_root)/.context"; }

repo_name() {
  if [ -n "${CONDUCTOR_REPO_NAME:-}" ]; then
    echo "$CONDUCTOR_REPO_NAME"
    return
  fi
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  basename "$(dirname "$root")"  # ~/conductor/workspaces/<repo>/<workspace>/ → repo
}

workspaces_root() {
  if [ -n "${CONDUCTOR_WORKSPACES_ROOT:-}" ]; then
    echo "$CONDUCTOR_WORKSPACES_ROOT"
  else
    echo "$HOME/conductor/workspaces"
  fi
}

cmd_get() {
  local key="${1:?usage: conductor-status get <key>}"
  local f; f="$(status_file)"
  [ -f "$f" ] || { echo ""; return 0; }
  jq -r --arg k "$key" '.[$k] // ""' "$f"
}

cmd_update() {
  (( $# > 0 )) || { echo "usage: conductor-status update <key>=<val> [...]" >&2; exit 2; }
  ensure_context_dir
  local f; f="$(status_file)"
  [ -f "$f" ] || echo '{"schema_version":1}' > "$f"

  local jq_args=() jq_expr='.'
  local i=0
  for kv in "$@"; do
    local key="${kv%%=*}" val="${kv#*=}"
    [[ "$kv" == *=* ]] || { echo "bad arg '$kv'" >&2; exit 2; }
    jq_args+=(--arg "k$i" "$key" --arg "v$i" "$val")
    jq_expr="$jq_expr | .[\$k$i] = \$v$i"
    i=$((i+1))
  done
  local now; now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq_args+=(--arg "tsnow" "$now")
  jq_expr="$jq_expr | .updated_at = \$tsnow | .started_at = (.started_at // \$tsnow) | .schema_version = 1"

  local tmp; tmp=$(mktemp)
  jq "${jq_args[@]}" "$jq_expr" "$f" > "$tmp" && mv "$tmp" "$f"
}

cmd_list() {
  local exclude_self=0
  [[ "${1:-}" == "--exclude-self" ]] && exclude_self=1

  local repo; repo="$(repo_name)"
  local root; root="$(workspaces_root)/$repo"
  [ -d "$root" ] || { echo "(no workspaces under $root)"; return 0; }

  local self=""
  (( exclude_self )) && self="$(basename "$(workspace_root)")"

  echo "## Conductor workspace state"
  echo ""
  [ -n "$self" ] && {
    local self_f="$root/$self/.context/conductor-status.json"
    if [ -f "$self_f" ]; then
      local sp sb
      sp=$(jq -r '.phase // "unknown"' "$self_f")
      sb=$(jq -r '.branch // "-"' "$self_f")
      echo "You are: $self (branch: $sb, phase: $sp)"
      echo ""
    else
      echo "You are: $self (no status yet)"
      echo ""
    fi
  }

  local printed_header=0
  local d
  for d in "$root"/*/; do
    local name; name=$(basename "$d")
    (( exclude_self )) && [ "$name" = "$self" ] && continue
    local f="$d/.context/conductor-status.json"
    [ -f "$f" ] || continue
    if (( ! printed_header )); then
      (( exclude_self )) && echo "Siblings:" || echo "Workspaces:"
      printed_header=1
    fi
    local phase branch plan pr
    phase=$(jq -r '.phase // "unknown"' "$f")
    branch=$(jq -r '.branch // "-"' "$f")
    plan=$(jq -r '.plan // "-"' "$f")
    pr=$(jq -r '.pr_url // ""' "$f")
    local plan_short="${plan##*/}"
    plan_short="${plan_short%.md}"
    local extra=""
    [ -n "$pr" ] && extra=" — $pr"
    printf "  - %-12s [%s]  %-13s — %s%s\n" "$name" "$plan_short" "$phase" "$branch" "$extra"
  done
}

case "${1:-}" in
  get)    shift; cmd_get "$@" ;;
  update) shift; cmd_update "$@" ;;
  list)   shift; cmd_list "$@" ;;
  ""|-h|--help)
    sed -n '3,13p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *) echo "unknown subcommand: $1" >&2; exit 2 ;;
esac
```

- [ ] **Step 2: Make executable and run tests**

```bash
chmod +x bin/conductor-status
bash bin/tests/conductor-status.test.sh
```

Expected: all `PASS:` lines, final `ALL PASSED`.

- [ ] **Step 3: Commit**

```bash
git add bin/conductor-status bin/tests/conductor-status.test.sh
git commit -m "feat(bin): add conductor-status helper with tests

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: `bin/conductor-dispatch` — failing tests

**Files:**
- Create: `bin/tests/conductor-dispatch.test.sh`

- [ ] **Step 1: Write the test script**

```bash
#!/usr/bin/env bash
# Tests for bin/conductor-dispatch. Uses a PATH-shim to capture what `open`
# would have been called with instead of actually opening a URL.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BIN="$REPO_ROOT/bin/conductor-dispatch"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Create a fake `open` that records its arg to a file.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/open" <<'EOF'
#!/usr/bin/env bash
echo "$1" > "$OPEN_CAPTURE"
EOF
chmod +x "$TMP/bin/open"

# Create a fake plan to dispatch.
cat > "$TMP/plan.md" <<'EOF'
# P0.1 — Test plan

This is the plan body.
EOF

# ── Test: --print mode emits the conductor:// URL on stdout ──
out=$(CONDUCTOR_REPO_NAME=myrepo "$BIN" "$TMP/plan.md" --print)
echo "$out" | grep -q '^conductor://async?' || fail "--print emits URL" "got: $out"
echo "$out" | grep -q 'repo=myrepo' || fail "--print includes repo" "got: $out"
echo "$out" | grep -q 'plan=' || fail "--print includes plan=" "got: $out"
pass "--print emits conductor:// URL"

# ── Test: the plan= value decodes back to the plan body ──
b64=$(echo "$out" | sed -E 's|^.*plan=([^&]+).*|\1|')
decoded=$(echo "$b64" | base64 -d)
echo "$decoded" | grep -q "This is the plan body." || fail "plan= decodes to body" "decoded: $decoded"
pass "plan= decodes to body"

# ── Test: --open mode invokes `open` with the URL ──
OPEN_CAPTURE="$TMP/captured.txt"
PATH="$TMP/bin:$PATH" CONDUCTOR_REPO_NAME=myrepo OPEN_CAPTURE="$OPEN_CAPTURE" "$BIN" "$TMP/plan.md" --open >/dev/null
[ -f "$OPEN_CAPTURE" ] || fail "--open invokes open" "no captured URL"
captured=$(cat "$OPEN_CAPTURE")
echo "$captured" | grep -q '^conductor://async?' || fail "--open passes conductor URL" "got: $captured"
pass "--open invokes open"

# ── Test: default mode (no flag) opens + prints ──
: > "$OPEN_CAPTURE"
out=$(PATH="$TMP/bin:$PATH" CONDUCTOR_REPO_NAME=myrepo OPEN_CAPTURE="$OPEN_CAPTURE" "$BIN" "$TMP/plan.md")
[ -s "$OPEN_CAPTURE" ] || fail "default opens" "open not called"
echo "$out" | grep -q '^conductor://async?' || fail "default prints URL" "got: $out"
pass "default mode opens and prints"

# ── Test: missing file exits non-zero ──
set +e
"$BIN" "$TMP/does-not-exist.md" --print 2>/dev/null; rc=$?
set -e
[ "$rc" -ne 0 ] || fail "missing plan exits non-zero" "rc=$rc"
pass "missing plan exits non-zero"

echo ""
echo "ALL PASSED"
```

- [ ] **Step 2: Run and verify failure**

```bash
chmod +x bin/tests/conductor-dispatch.test.sh
bash bin/tests/conductor-dispatch.test.sh
```

Expected: FAIL — `conductor-dispatch: command not found` or "no such file".

---

## Task 5: `bin/conductor-dispatch` — implementation

**Files:**
- Create: `bin/conductor-dispatch`

- [ ] **Step 1: Write the implementation**

```bash
#!/usr/bin/env bash
# =============================================================================
# conductor-dispatch — spawn a new Conductor workspace via deep link, with a
# plan markdown file attached.
#
# Usage:
#   conductor-dispatch <path-to-plan.md>          # open + print
#   conductor-dispatch <path-to-plan.md> --open   # open only
#   conductor-dispatch <path-to-plan.md> --print  # print URL, don't open
#
# Env overrides (used by tests):
#   CONDUCTOR_REPO_NAME — override repo-name detection
# =============================================================================
set -euo pipefail

plan="${1:?usage: conductor-dispatch <plan.md> [--open|--print]}"
mode="${2:-both}"

[ -f "$plan" ] || { echo "error: plan not found: $plan" >&2; exit 1; }

if [ -n "${CONDUCTOR_REPO_NAME:-}" ]; then
  repo="$CONDUCTOR_REPO_NAME"
else
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  repo="$(basename "$(dirname "$root")")"
fi

b64=$(base64 < "$plan" | tr -d '\n')
url="conductor://async?repo=${repo}&plan=${b64}"

case "$mode" in
  --print) echo "$url" ;;
  --open)
    if command -v open >/dev/null 2>&1; then
      open "$url"
    else
      echo "error: 'open' not found; run with --print and open manually" >&2
      echo "$url"
      exit 1
    fi
    ;;
  both|"")
    if command -v open >/dev/null 2>&1; then
      open "$url"
    else
      echo "warning: 'open' not found; here is the URL to open manually:" >&2
    fi
    echo "$url"
    ;;
  *) echo "error: unknown mode '$mode'" >&2; exit 2 ;;
esac
```

- [ ] **Step 2: Make executable and run tests**

```bash
chmod +x bin/conductor-dispatch
bash bin/tests/conductor-dispatch.test.sh
```

Expected: all `PASS:` lines, final `ALL PASSED`.

- [ ] **Step 3: Commit**

```bash
git add bin/conductor-dispatch bin/tests/conductor-dispatch.test.sh
git commit -m "feat(bin): add conductor-dispatch helper with tests

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: `conductor-context.sh` hook — failing tests

**Files:**
- Create: `bin/tests/conductor-context.test.sh`

- [ ] **Step 1: Write the test script**

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
HOOK="$REPO_ROOT/.claude/hooks/conductor-context.sh"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/repo/accra/.context" "$TMP/repo/bali/.context"

cat > "$TMP/repo/bali/.context/conductor-status.json" <<'EOF'
{"schema_version":1,"workspace":"bali","repo":"repo","plan":"docs/plans/2026-w16/sprint-plans/P0.2-feat-y.md","branch":"feat/y","phase":"verifying","done_criteria":[],"dev_server_port":null,"pr_url":null,"last_error":null,"started_at":"2026-04-19T10:00:00Z","updated_at":"2026-04-19T11:00:00Z"}
EOF

# ── Test: hook prints sibling rollup when inside a workspace dir ──
out=$(cd "$TMP/repo/accra" && CONDUCTOR_WORKSPACES_ROOT="$TMP" CONDUCTOR_REPO_NAME=repo bash "$HOOK")
echo "$out" | grep -q "Conductor workspace state" || fail "header present" "out: $out"
echo "$out" | grep -q "bali" || fail "shows sibling bali" "out: $out"
echo "$out" | grep -q "verifying" || fail "shows sibling phase" "out: $out"
echo "$out" | grep -q "accra" && fail "excludes self" "unexpected self: $out" || true
pass "prints sibling rollup"

# ── Test: hook silently no-ops when outside a Conductor workspace tree ──
out=$(cd "$TMP" && CONDUCTOR_WORKSPACES_ROOT="/nonexistent" bash "$HOOK" 2>&1 || true)
[[ -z "$out" ]] || fail "silent outside workspace" "unexpected output: $out"
pass "silent outside Conductor workspace tree"

echo ""
echo "ALL PASSED"
```

- [ ] **Step 2: Run and verify failure**

```bash
chmod +x bin/tests/conductor-context.test.sh
bash bin/tests/conductor-context.test.sh
```

Expected: FAIL — hook script doesn't exist.

---

## Task 7: `conductor-context.sh` hook — implementation

**Files:**
- Create: `.claude/hooks/conductor-context.sh`

- [ ] **Step 1: Write the hook**

```bash
#!/usr/bin/env bash
# SessionStart hook — injects sibling Conductor workspace state into context.
# Silently no-ops outside a ~/conductor/workspaces/<repo>/<workspace>/ tree.
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
# shellcheck source=harness.config.sh
source "$REPO_ROOT/.claude/hooks/harness.config.sh" 2>/dev/null || true

ROOT="${CONDUCTOR_WORKSPACES_ROOT:-$HOME/conductor/workspaces}"

# Resolve: is the current directory under the workspaces root?
case "$PWD/" in
  "$ROOT"/*) ;;
  *) exit 0 ;;  # not in Conductor workspace tree — silent no-op
esac

STATUS_BIN="$REPO_ROOT/bin/conductor-status"
[ -x "$STATUS_BIN" ] || exit 0  # helper not installed yet — no-op

"$STATUS_BIN" list --exclude-self
```

- [ ] **Step 2: Make executable and run tests**

```bash
chmod +x .claude/hooks/conductor-context.sh
bash bin/tests/conductor-context.test.sh
```

Expected: all `PASS:` lines, final `ALL PASSED`.

- [ ] **Step 3: Commit**

```bash
git add .claude/hooks/conductor-context.sh bin/tests/conductor-context.test.sh
git commit -m "feat(hooks): add SessionStart hook for sibling workspace awareness

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: Wire `conductor-context.sh` into `settings.json`

**Files:**
- Modify: `.claude/settings.json`

- [ ] **Step 1: Add the hook to the `startup` matcher**

Edit `.claude/settings.json`. Replace the existing `startup` SessionStart block:

```json
{
  "matcher": "startup",
  "hooks": [
    {
      "type": "command",
      "command": ".claude/hooks/init.sh",
      "timeout": 15
    }
  ]
}
```

with:

```json
{
  "matcher": "startup",
  "hooks": [
    {
      "type": "command",
      "command": ".claude/hooks/init.sh",
      "timeout": 15
    },
    {
      "type": "command",
      "command": ".claude/hooks/conductor-context.sh",
      "timeout": 10
    }
  ]
}
```

- [ ] **Step 2: Validate JSON**

```bash
jq . .claude/settings.json > /dev/null
```

Expected: no output, exit 0. (jq errors if malformed.)

- [ ] **Step 3: Commit**

```bash
git add .claude/settings.json
git commit -m "feat(hooks): wire conductor-context.sh into SessionStart

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 9: Extend `setup.sh` to generate `conductor.json`

**Files:**
- Modify: `setup.sh`

- [ ] **Step 1: Add the generator segment**

Open `setup.sh`. After the "Write harness.config.sh" block (ends at line ~116 with `echo "Wrote $CONFIG"`), insert:

```bash
# ──────────────────────────────────────────────────────────────────────────────
# Generate conductor.json
# ──────────────────────────────────────────────────────────────────────────────

echo ""
read -p "Generate conductor.json for Conductor workspace scripts? [Y/n]: " GEN_CONDUCTOR
GEN_CONDUCTOR="${GEN_CONDUCTOR:-Y}"

if [[ "$GEN_CONDUCTOR" =~ ^[Yy]$ ]]; then
  CONDUCTOR_JSON="$REPO_ROOT/conductor.json"

  # Compose setup script: install deps, then copy .env.example if present,
  # then run DB generate + push if configured.
  SETUP_LINES=("${PKG_MGR} install")
  if [ -f "$REPO_ROOT/.env.example" ]; then
    SETUP_LINES+=("if [ ! -f .env ]; then cp .env.example .env; fi")
  fi
  if [ -n "${DB_GENERATE:-}" ]; then
    SETUP_LINES+=("${DB_GENERATE}")
  fi
  if [ -n "${DB_PUSH:-}" ]; then
    SETUP_LINES+=("${DB_PUSH}")
  fi
  # Join with &&
  SETUP_SCRIPT=$(IFS=' && '; echo "${SETUP_LINES[*]}")

  # Archive script: stop dev server on configured port + clean build artifacts.
  ARCHIVE_SCRIPT="lsof -ti:${DEV_PORT} | xargs -r kill -TERM 2>/dev/null; rm -rf node_modules .next .turbo dist build .cache"

  # Write conductor.json via jq for safe quoting.
  jq -n \
    --arg setup "$SETUP_SCRIPT" \
    --arg run "$DEV_CMD" \
    --arg archive "$ARCHIVE_SCRIPT" \
    '{scripts: {setup: $setup, run: $run, archive: $archive}}' > "$CONDUCTOR_JSON"

  echo "Wrote $CONDUCTOR_JSON"
  echo ""
  echo "  setup:   $SETUP_SCRIPT"
  echo "  run:     $DEV_CMD"
  echo "  archive: $ARCHIVE_SCRIPT"
  echo ""
  echo "Review and edit conductor.json before committing — the archive script"
  echo "removes build artifacts aggressively. Adjust for your stack."
fi
```

- [ ] **Step 2: Smoke-test against a temp repo**

```bash
TEST_DIR=$(mktemp -d)
cp setup.sh "$TEST_DIR/"
mkdir -p "$TEST_DIR/.claude/hooks"
echo "placeholder" > "$TEST_DIR/.claude/hooks/harness.config.sh"
touch "$TEST_DIR/.env.example"
cd "$TEST_DIR" && git init -q && git add . && git commit -q -m init

# Drive the wizard with canned answers.
printf 'TestApp\npnpm\nsrc\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nY\n' | bash setup.sh
```

Expected: `conductor.json` exists in `$TEST_DIR` and is valid JSON:

```bash
jq . "$TEST_DIR/conductor.json"
```

Expected output includes `"setup": "pnpm install && if [ ! -f .env ]; then cp .env.example .env; fi"` and `"run": "pnpm run dev"`.

Clean up: `rm -rf "$TEST_DIR" && cd -`.

- [ ] **Step 3: Commit**

```bash
git add setup.sh
git commit -m "feat(setup): generate conductor.json alongside harness.config.sh

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 10: `/plan-sprint` — add Parallel-safe field to plan template

**Files:**
- Modify: `.claude/skills/plan-sprint/SKILL.md`

- [ ] **Step 1: Insert the Parallel-safe field**

Open `.claude/skills/plan-sprint/SKILL.md`. Locate the plan template block (starts with `# [Project Title]`). Immediately after `**Estimated effort:** N pts (list [Build]/[Extend] items)`, add:

```markdown

**Parallel-safe:** yes | no (populated by wave detection in Phase 3.5)
```

- [ ] **Step 2: Verify the edit**

```bash
grep -n "Parallel-safe" .claude/skills/plan-sprint/SKILL.md
```

Expected: exactly one matching line inside the template.

---

## Task 11: `/plan-sprint` — add Phase 3.5 (wave detection)

**Files:**
- Modify: `.claude/skills/plan-sprint/SKILL.md`

- [ ] **Step 1: Insert the wave-detection phase**

In `.claude/skills/plan-sprint/SKILL.md`, locate the line `## Phase 4: Update goals document`. Insert this new phase immediately above it:

````markdown
## Phase 3.5: Detect parallel execution waves

After all plans are written (Phase 3 complete), compute execution waves using each plan's `Depends on` field AND `File Footprint` section.

**Algorithm:**

1. Build a dependency graph: each plan is a node; edges point from a plan to the plans listed in its `Depends on` field.
2. Topologically sort into candidate waves (plans with no unmet deps are candidate Wave 1, plans whose deps are all in Wave 1 are candidate Wave 2, etc.).
3. Within each candidate wave, compute file-footprint overlap:
   - Union the `Creates` and `Modifies` file paths from each plan.
   - Any pair with overlapping paths cannot run in parallel. Keep the earlier-priority plan in the current wave; move the lower-priority plan to the next wave.
4. For each plan, set `Parallel-safe: yes` iff it shares its wave with at least one other plan; `no` otherwise. Update the plan's header with `sed` or re-write the frontmatter section.

**Output:**

Print the wave summary to the user:

```
## Parallel Execution Plan

Wave 1 (parallel-safe, no unmet dependencies + no file overlap):
  - P0.1 feat-some-feature   (Parallel-safe: yes)
  - P0.2 feat-another-feature (Parallel-safe: yes)

Wave 2 (after Wave 1 ships):
  - P0.3 feat-builds-on-P0.1 (depends on P0.1)
```

If a wave has only one plan, mark it `Parallel-safe: no` — there's no one to run alongside.
````

- [ ] **Step 2: Verify the edit**

```bash
grep -n "Phase 3.5" .claude/skills/plan-sprint/SKILL.md
grep -n "Detect parallel execution waves" .claude/skills/plan-sprint/SKILL.md
```

Expected: one match each.

---

## Task 12: `/plan-sprint` — add Phase 5 (dispatch offer)

**Files:**
- Modify: `.claude/skills/plan-sprint/SKILL.md`

- [ ] **Step 1: Insert the dispatch phase**

In `.claude/skills/plan-sprint/SKILL.md`, locate the `## Naming conventions` section. Insert a new phase immediately above it:

````markdown
## Phase 5: Dispatch Wave 1 to Conductor workspaces (optional)

After Phase 4 (goals doc updated and committed), offer to dispatch the Wave-1 plans as new Conductor workspaces.

Prompt the user:

```
## Dispatch Wave 1

Open N Conductor workspaces now? Each will boot with its plan file
attached so you can type `/build <plan-path>` to start.

  [y] Open all N
  [s] Show deep links only (I'll open manually)
  [n] Skip
```

**On `y`:** for each Wave-1 plan, run:

```bash
bin/conductor-dispatch docs/plans/YYYY-wNN/sprint-plans/<plan>.md
```

Each invocation opens a new Conductor workspace with the plan attached as a markdown file. Print the URL so the user can see what was dispatched.

**On `s`:** for each Wave-1 plan, run the same command with `--print` and list the URLs.

**On `n`:** skip; the user can dispatch manually later.

**Wave 2+** is NOT auto-dispatched. After Wave 1 ships, re-run `/plan-sprint` (it will detect that Wave 1 is done and propose Wave 2 for dispatch) or run `bin/conductor-dispatch <plan>` directly.
````

- [ ] **Step 2: Verify the edit**

```bash
grep -n "Phase 5: Dispatch" .claude/skills/plan-sprint/SKILL.md
grep -n "bin/conductor-dispatch" .claude/skills/plan-sprint/SKILL.md
```

Expected: one match for Phase 5, at least two matches for the helper invocation.

- [ ] **Step 3: Commit all /plan-sprint changes**

```bash
git add .claude/skills/plan-sprint/SKILL.md
git commit -m "feat(skills): plan-sprint detects waves and dispatches to Conductor

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 13: `/build` — add status-file maintenance

**Files:**
- Modify: `.claude/skills/build-plan/SKILL.md`

- [ ] **Step 1: Add status updates at phase boundaries**

Open `.claude/skills/build-plan/SKILL.md`. At the end of **Phase 1: Read and Prepare** (after the "Ask clarifying questions" step), insert a new sub-step:

````markdown
### 7. Initialize the status manifest

Write the initial status file so sibling workspaces can see this work starting:

```bash
bin/conductor-status update \
  workspace="$(basename "$PWD")" \
  repo="$(basename "$(dirname "$(pwd)")")" \
  plan="<the-plan-path-you-read>" \
  branch="$(git symbolic-ref --short HEAD)" \
  phase=implementing
```

Also write the Done Criteria array. Parse each `- [ ] ...` line out of the plan's "Done Criteria" section and build a JSON array of `{item, status}` objects, then pass it as a single value:

```bash
# Example: plan has these criteria
#   - [ ] Unit tests passing
#   - [ ] E2E browser verification passing
criteria_json=$(jq -nc '[
  {"item":"Unit tests passing","status":"pending"},
  {"item":"E2E browser verification passing","status":"pending"}
]')
bin/conductor-status update done_criteria="$criteria_json"
```

One update call, one JSON string value. As criteria pass during Phases 3 and 4, re-serialize with the updated statuses and call `update done_criteria="$criteria_json"` again.
````

At the top of **Phase 3: Verify** (before "Run full test suite"), insert:

````markdown
### 0. Update status to verifying

```bash
bin/conductor-status update phase=verifying
```
````

At the end of **Phase 4: Ship** (after "Report to user"), insert:

````markdown
### 5. Update status to shipped

After the PR is created and pushed:

```bash
bin/conductor-status update phase=shipped pr_url="<pr-url>"
```
````

- [ ] **Step 2: Verify the edits**

```bash
grep -n "bin/conductor-status" .claude/skills/build-plan/SKILL.md
```

Expected: 3+ matches (Phase 1 init, Phase 3 verifying, Phase 4 shipped).

---

## Task 14: `/build` — add internal quality-skill orchestration rules

**Files:**
- Modify: `.claude/skills/build-plan/SKILL.md`

- [ ] **Step 1: Insert the decision-rule table**

In `.claude/skills/build-plan/SKILL.md`, locate the section `## Phase 3: Verify`. Immediately under that header, insert:

````markdown
### Quality-skill decision rules

Before running the test suite, evaluate which quality skills to invoke for this plan. Apply these rules in order:

| Plan characteristic | Skill to invoke |
|---|---|
| Implementation step creates a new function, class, or service | Use `/tdd` cadence during Phase 2 (write failing test → implement → run test) |
| Plan's Test Plan includes an "E2E Browser Verification" section | Run `/e2e-verify` during Phase 3 before `Check done criteria` |
| Plan's File Footprint touches auth/session/credential files, external HTTP handlers, data-access files, or file-upload handlers | Run `/security-review` during Phase 3 before `Check done criteria` |
| About to create the PR (Phase 4 step 2) | Run `/pre-deploy` as the final gate |

Invoke each skill via the Skill tool with its name as the argument. Each skill returns pass/fail; on fail, fix the issue before proceeding. On pass, continue down the checklist.
````

- [ ] **Step 2: Verify the edit**

```bash
grep -n "Quality-skill decision rules" .claude/skills/build-plan/SKILL.md
grep -c "/e2e-verify\|/security-review\|/pre-deploy\|/tdd" .claude/skills/build-plan/SKILL.md
```

Expected: first grep matches once; second grep returns ≥ 4.

---

## Task 15: `/build` — add Conductor Todos probe (best effort)

**Files:**
- Modify: `.claude/skills/build-plan/SKILL.md`

- [ ] **Step 1: Insert the Todos probe note in Phase 1**

In `.claude/skills/build-plan/SKILL.md`, locate the Phase 1 sub-step "7. Initialize the status manifest" you added in Task 13. After that sub-step, add:

````markdown
### 8. Mirror Done Criteria to Conductor Todos (best effort)

Conductor has a native "Todos" feature that gates merge-readiness. The public docs don't document a scriptable interface at time of writing (2026-04-19); the OpenAPI spec at `https://docs.conductor.build/openapi.json` may expose one.

During implementation, read the OpenAPI spec. If it contains a Todos endpoint, add a shell call here that POSTs each Done Criterion as a todo. If it doesn't, skip this step entirely — the status file and sibling rollup are sufficient.

No placeholder code ships in the skill file. This note exists so a future iteration knows where to add the integration when the API stabilizes.
````

- [ ] **Step 2: Commit all /build changes**

```bash
git add .claude/skills/build-plan/SKILL.md
git commit -m "feat(skills): build writes conductor-status and orchestrates quality skills

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 16: Extend `/harness-health` with new probes

**Files:**
- Modify: `.claude/commands/harness-health.md`

- [ ] **Step 1: Add probes for Conductor integration pieces**

Open `.claude/commands/harness-health.md` and add a new section. The file structure already describes probes as bash commands with expected output — follow that pattern. Append this block at the end of the file:

````markdown
## Conductor integration checks

Run:

```bash
test -x bin/conductor-status && echo "OK: conductor-status executable" || echo "FAIL: bin/conductor-status missing or not executable"
test -x bin/conductor-dispatch && echo "OK: conductor-dispatch executable" || echo "FAIL: bin/conductor-dispatch missing or not executable"
test -x .claude/hooks/conductor-context.sh && echo "OK: conductor-context hook executable" || echo "FAIL: conductor-context hook missing or not executable"
jq -e '.hooks.SessionStart[] | select(.matcher=="startup") | .hooks[] | select(.command=="'.claude/hooks/conductor-context.sh'")' .claude/settings.json >/dev/null && echo "OK: conductor-context hook wired in settings.json" || echo "FAIL: conductor-context hook not wired"
test -f conductor.json && echo "OK: conductor.json exists" || echo "WARN: conductor.json not present (run setup.sh to generate)"
bash bin/tests/conductor-status.test.sh >/dev/null 2>&1 && echo "OK: conductor-status tests pass" || echo "FAIL: conductor-status tests failing"
bash bin/tests/conductor-dispatch.test.sh >/dev/null 2>&1 && echo "OK: conductor-dispatch tests pass" || echo "FAIL: conductor-dispatch tests failing"
bash bin/tests/conductor-context.test.sh >/dev/null 2>&1 && echo "OK: conductor-context tests pass" || echo "FAIL: conductor-context tests failing"
```

All five `OK:` lines for the helpers + hook, and `WARN: conductor.json not present` is acceptable in the harness repo itself (we don't ship one). `FAIL` for any test indicates a regression; re-run the plan's relevant task.
````

- [ ] **Step 2: Verify the edit**

```bash
grep -n "Conductor integration checks" .claude/commands/harness-health.md
```

Expected: one match.

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/harness-health.md
git commit -m "feat(commands): harness-health probes Conductor integration

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 17: Bump VERSION and update README

**Files:**
- Modify: `VERSION`
- Modify: `README.md`

- [ ] **Step 1: Bump VERSION**

```bash
echo "0.3.0" > VERSION
```

- [ ] **Step 2: Append README section**

Open `README.md`. Add a new top-level section after the "Skills" section and before "Planning workflow":

````markdown
---

## Conductor integration

The harness auto-integrates with [Conductor](https://conductor.build) — when you run it inside a Conductor workspace (i.e. under `~/conductor/workspaces/<repo>/`), extra capabilities activate:

### What activates automatically

- **Sibling workspace awareness.** On SessionStart, `conductor-context.sh` injects a rollup of sibling workspaces into Claude's context: who's working on what, which branch, what phase.
- **Per-workspace status manifest.** `/build` writes `.context/conductor-status.json` at each phase (implementing → verifying → shipped). Siblings read it for the rollup; the file is `.gitignored`-per-workspace, so it never pollutes branches.

### Sprint dispatch flow

Inside `/plan-sprint`:

1. Plans get written as usual.
2. **Phase 3.5** detects parallel-safe waves by topologically sorting `Depends on` and eliminating pairs with overlapping `File Footprint`s.
3. **Phase 5** offers to dispatch Wave 1 — one `conductor://async` deep link per plan, opening new Conductor workspaces with the plan file pre-attached. Type `/build <plan-path>` in each child to execute.

### Bootstrapping a new project

Run `./setup.sh` in a fresh clone. The wizard generates both `.claude/hooks/harness.config.sh` and `conductor.json` (with `setup`/`run`/`archive` scripts tailored to your detected stack). Commit `conductor.json` to share Conductor setup across your team.

### Helpers

| Helper | What it does |
|---|---|
| `bin/conductor-status get/update/list` | Read/write the per-workspace manifest; used by `/build` and the SessionStart hook |
| `bin/conductor-dispatch <plan.md>` | Base64-encode a plan and `open` a `conductor://async` deep link |
| `.claude/hooks/conductor-context.sh` | SessionStart hook that prints the sibling rollup |

### Verifying

```bash
claude /harness-health  # includes Conductor integration checks
```

---
````

- [ ] **Step 3: Commit**

```bash
git add VERSION README.md
git commit -m "chore: bump version to 0.3.0, document Conductor integration

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 18: End-to-end integration smoke test

**Files:** none (manual verification)

- [ ] **Step 1: Run all helper tests**

```bash
bash bin/tests/conductor-status.test.sh
bash bin/tests/conductor-dispatch.test.sh
bash bin/tests/conductor-context.test.sh
```

Expected: `ALL PASSED` from each.

- [ ] **Step 2: Run harness-health manually**

Open a fresh Claude Code session in this repo and run `/harness-health`. Verify all new `OK:` lines appear.

- [ ] **Step 3: Verify no regressions in the existing SessionStart flow**

Open a new Claude Code session. The session start should show:
- The existing `=== Session Context ===` from `init.sh`
- AND (if the repo has any `.context/conductor-status.json` in sibling dirs) a `## Conductor workspace state` block from `conductor-context.sh`

If not in a Conductor workspace tree, only the first block should appear (the hook silently no-ops — correct behavior).

- [ ] **Step 4: Manually dispatch a plan and verify a child workspace opens**

In the Conductor UI this can't be automated. From this workspace:

```bash
echo "# Throwaway plan" > /tmp/throwaway-plan.md
bin/conductor-dispatch /tmp/throwaway-plan.md --print
```

Copy the URL, verify it matches `conductor://async?repo=<this-repo>&plan=<base64>` format, and if you're on the Conductor-enabled Mac, paste it into your browser address bar to confirm a new workspace spawns with the plan attached.

Report success to the user. If any step fails, stop and diagnose before continuing to a final PR.

---

## Done criteria

- [ ] All three helper test scripts pass (`bash bin/tests/*.test.sh`)
- [ ] `/harness-health` shows all new `OK:` lines
- [ ] SessionStart shows sibling rollup when siblings exist, no-ops otherwise
- [ ] `setup.sh` generates a valid `conductor.json` via the smoke test in Task 9
- [ ] `/plan-sprint` has Phase 3.5 and Phase 5 documented, plan template has Parallel-safe field
- [ ] `/build` has Phase 1 status init, Phase 3 verifying update, Phase 4 shipped update, and the decision-rules table
- [ ] `VERSION` reads `0.3.0`, README has the new "Conductor integration" section
- [ ] All commits use conventional-commit style, no `--no-verify`
- [ ] No regressions in existing hooks (`init.sh`, `bash-guard.sh`, `post-edit.sh`, etc.)
