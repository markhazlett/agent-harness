# Multi-Harness Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the Agent Harness install cleanly for plain Claude Code users alongside the existing Conductor path, controlled by a new `HARNESS_HOST` config value.

**Architecture:** Add `HARNESS_HOST="conductor" | "claude-code"` to the config written by `setup.sh`. Gate the Conductor-specific helpers (`bin/conductor-status`, `bin/conductor-dispatch`) on that value so they no-op cleanly in Claude Code mode without touching any skill files. Branch `setup.sh` so it only generates `conductor.json` in Conductor mode, and branch `/harness-health` so it reports `SKIP` (not `FAIL`) for Conductor probes when host is Claude Code.

**Tech Stack:** Bash scripts, `jq`, POSIX tools. No code changes in `.claude/skills/`, `.claude/agents/`, or `.claude/hooks/`.

**File Map:**

| File | Change |
|---|---|
| `bin/conductor-status` | Add 4-line self-gate at top |
| `bin/conductor-dispatch` | Add 4-line self-gate at top |
| `setup.sh` | New first prompt (host); wrap Conductor-specific block |
| `.claude/commands/harness-health.md` | Conditional SKIP for Conductor probes |
| `README.md` | New "Choose your host" section + quickstart line update |
| `bin/tests/helper-self-gate.test.sh` | **New** — tests both helpers self-gate on `HARNESS_HOST` |
| `bin/tests/setup-claude-code.test.sh` | **New** — drives `setup.sh` in Claude Code mode |
| `bin/tests/setup-conductor-json.test.sh` | Update canned input to include host prompt |

Reference spec: `docs/superpowers/specs/2026-04-22-multi-harness-support-design.md`

---

## Task 1: Self-gate `bin/conductor-status` on `HARNESS_HOST`

**Files:**
- Create: `bin/tests/helper-self-gate.test.sh`
- Modify: `bin/conductor-status` (insert after line 21, `set -euo pipefail`)

- [ ] **Step 1: Write the failing test**

Create `bin/tests/helper-self-gate.test.sh` with this content:

```bash
#!/usr/bin/env bash
# Tests that bin/conductor-status and bin/conductor-dispatch self-gate on
# HARNESS_HOST. When host is "claude-code", both helpers must exit 0 with
# no side effects (no .context/ file writes, no stdout). When host is
# "conductor" or unset, they behave normally.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
STATUS_BIN="$REPO_ROOT/bin/conductor-status"
DISPATCH_BIN="$REPO_ROOT/bin/conductor-dispatch"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ── Fixture: a fake "workspace" with its own .claude/hooks/harness.config.sh ──
# so the helper sources host=claude-code from the expected location.
mkdir -p "$TMP/ws/.claude/hooks" "$TMP/ws/.context"
cat > "$TMP/ws/.claude/hooks/harness.config.sh" <<'EOF'
HARNESS_HOST="claude-code"
EOF

# ── Test: conductor-status update is a silent no-op in Claude Code mode ──
out=$(cd "$TMP/ws" && HARNESS_HOST=claude-code "$STATUS_BIN" update phase=planning 2>&1)
[[ -z "$out" ]] || fail "status update silent in claude-code mode" "got output: $out"
[[ ! -f "$TMP/ws/.context/conductor-status.json" ]] \
  || fail "status update does not write file in claude-code mode" "file exists"
pass "status update is silent no-op in claude-code mode"

# ── Test: conductor-status get is a silent no-op in Claude Code mode ──
out=$(cd "$TMP/ws" && HARNESS_HOST=claude-code "$STATUS_BIN" get phase 2>&1)
[[ -z "$out" ]] || fail "status get silent in claude-code mode" "got output: $out"
pass "status get is silent no-op in claude-code mode"

# ── Test: conductor-status list is a silent no-op in Claude Code mode ──
out=$(cd "$TMP/ws" && HARNESS_HOST=claude-code "$STATUS_BIN" list 2>&1)
[[ -z "$out" ]] || fail "status list silent in claude-code mode" "got output: $out"
pass "status list is silent no-op in claude-code mode"

# ── Test: conductor-status exit code is 0 in Claude Code mode ──
(cd "$TMP/ws" && HARNESS_HOST=claude-code "$STATUS_BIN" update phase=planning) \
  || fail "status update exits 0 in claude-code mode" "non-zero exit"
pass "status update exits 0 in claude-code mode"

# ── Test: HARNESS_HOST=conductor runs status normally ──
mkdir -p "$TMP/ws2/.claude/hooks" "$TMP/ws2/.context"
cat > "$TMP/ws2/.claude/hooks/harness.config.sh" <<'EOF'
HARNESS_HOST="conductor"
EOF
(cd "$TMP/ws2" && HARNESS_HOST=conductor "$STATUS_BIN" update phase=planning workspace=ws2 repo=testrepo)
[[ -f "$TMP/ws2/.context/conductor-status.json" ]] \
  || fail "status runs normally with host=conductor" "no file written"
pass "status runs normally with host=conductor"

# ── Test: unset HARNESS_HOST defaults to conductor behavior (backward compat) ──
mkdir -p "$TMP/ws3/.claude/hooks" "$TMP/ws3/.context"
# harness.config.sh without HARNESS_HOST at all
echo "HARNESS_PKG_MGR=pnpm" > "$TMP/ws3/.claude/hooks/harness.config.sh"
(cd "$TMP/ws3" && unset HARNESS_HOST && "$STATUS_BIN" update phase=planning workspace=ws3 repo=testrepo)
[[ -f "$TMP/ws3/.context/conductor-status.json" ]] \
  || fail "unset HARNESS_HOST defaults to conductor (backward compat)" "no file written"
pass "unset HARNESS_HOST defaults to conductor (backward compat)"

echo ""
echo "ALL PASSED"
```

- [ ] **Step 2: Mark the test executable and run it to verify it fails**

Run:
```bash
chmod +x bin/tests/helper-self-gate.test.sh
bash bin/tests/helper-self-gate.test.sh
```

Expected: FAIL on the very first assertion ("status update silent in claude-code mode"). `bin/conductor-status` will actually create `.context/conductor-status.json` and complete the update, because the self-gate doesn't exist yet.

- [ ] **Step 3: Add the self-gate to `bin/conductor-status`**

Open `bin/conductor-status` and insert the following block immediately after line 21 (`set -euo pipefail`), before the function definitions:

```bash
# ── Mode gate: skip entirely when host is not Conductor ──────────────────────
# Sources harness.config.sh (if present) to read HARNESS_HOST. Env overrides
# config so tests can force a mode. Unset/empty = conductor for backward compat.
_SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
_HARNESS_CONFIG="$_SCRIPT_DIR/../.claude/hooks/harness.config.sh"
if [ -z "${HARNESS_HOST:-}" ] && [ -f "$_HARNESS_CONFIG" ]; then
  # shellcheck source=../.claude/hooks/harness.config.sh
  source "$_HARNESS_CONFIG" 2>/dev/null || true
fi
if [ "${HARNESS_HOST:-conductor}" != "conductor" ]; then
  exit 0
fi
unset _SCRIPT_DIR _HARNESS_CONFIG
```

- [ ] **Step 4: Run the new test to verify it passes**

Run:
```bash
bash bin/tests/helper-self-gate.test.sh
```

Expected: all PASS assertions for `bin/conductor-status`. The `bin/conductor-dispatch` tests aren't in the file yet — that's Task 2.

- [ ] **Step 5: Run the existing `conductor-status` tests to verify no regression**

Run:
```bash
bash bin/tests/conductor-status.test.sh
```

Expected: `ALL PASSED`. The existing tests do not set `HARNESS_HOST` in env; with the harness repo's own `harness.config.sh` also not defining it, the `${HARNESS_HOST:-conductor}` default kicks in and the script runs normally.

- [ ] **Step 6: Commit**

```bash
git add bin/conductor-status bin/tests/helper-self-gate.test.sh
git commit -m "feat(conductor-status): self-gate on HARNESS_HOST"
```

---

## Task 2: Self-gate `bin/conductor-dispatch` on `HARNESS_HOST`

**Files:**
- Modify: `bin/tests/helper-self-gate.test.sh` (add dispatch cases)
- Modify: `bin/conductor-dispatch` (insert after line 14, `set -euo pipefail`)

- [ ] **Step 1: Extend the test file with dispatch cases**

Append the following block to `bin/tests/helper-self-gate.test.sh`, after the existing `pass "unset HARNESS_HOST defaults to conductor (backward compat)"` line and before `echo ""`:

```bash
# ── Test: conductor-dispatch is a silent no-op in Claude Code mode ──
# Create a dummy plan file and a fake `open` that would record a URL if called.
echo "# plan" > "$TMP/plan.md"
mkdir -p "$TMP/fakebin"
cat > "$TMP/fakebin/open" <<'EOF'
#!/usr/bin/env bash
echo "open-called-with: $*" >> "$OPEN_LOG"
EOF
chmod +x "$TMP/fakebin/open"
OPEN_LOG="$TMP/open.log"
: > "$OPEN_LOG"

out=$(PATH="$TMP/fakebin:$PATH" OPEN_LOG="$OPEN_LOG" HARNESS_HOST=claude-code \
  "$DISPATCH_BIN" "$TMP/plan.md" --print 2>&1)
[[ -z "$out" ]] || fail "dispatch silent in claude-code mode" "got output: $out"
[[ ! -s "$OPEN_LOG" ]] || fail "dispatch does not call open in claude-code mode" "log: $(cat "$OPEN_LOG")"
pass "dispatch is silent no-op in claude-code mode"

# ── Test: dispatch exits 0 in Claude Code mode ──
PATH="$TMP/fakebin:$PATH" OPEN_LOG="$OPEN_LOG" HARNESS_HOST=claude-code \
  "$DISPATCH_BIN" "$TMP/plan.md" --print \
  || fail "dispatch exits 0 in claude-code mode" "non-zero exit"
pass "dispatch exits 0 in claude-code mode"

# ── Test: HARNESS_HOST=conductor runs dispatch normally ──
out=$(CONDUCTOR_REPO_NAME=testrepo HARNESS_HOST=conductor \
  "$DISPATCH_BIN" "$TMP/plan.md" --print)
echo "$out" | grep -q '^conductor://async?' \
  || fail "dispatch runs normally with host=conductor" "got: $out"
pass "dispatch runs normally with host=conductor"
```

- [ ] **Step 2: Run the test to verify the new cases fail**

Run:
```bash
bash bin/tests/helper-self-gate.test.sh
```

Expected: earlier `conductor-status` cases PASS, then FAIL on "dispatch silent in claude-code mode" — dispatch currently prints the `conductor://` URL regardless of `HARNESS_HOST`.

- [ ] **Step 3: Add the self-gate to `bin/conductor-dispatch`**

Open `bin/conductor-dispatch` and insert the following block immediately after line 14 (`set -euo pipefail`), before the `plan=` assignment:

```bash
# ── Mode gate: skip entirely when host is not Conductor ──────────────────────
# Same pattern as bin/conductor-status. Unset/empty = conductor (backward compat).
_SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
_HARNESS_CONFIG="$_SCRIPT_DIR/../.claude/hooks/harness.config.sh"
if [ -z "${HARNESS_HOST:-}" ] && [ -f "$_HARNESS_CONFIG" ]; then
  # shellcheck source=../.claude/hooks/harness.config.sh
  source "$_HARNESS_CONFIG" 2>/dev/null || true
fi
if [ "${HARNESS_HOST:-conductor}" != "conductor" ]; then
  exit 0
fi
unset _SCRIPT_DIR _HARNESS_CONFIG
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```bash
bash bin/tests/helper-self-gate.test.sh
```

Expected: `ALL PASSED`.

- [ ] **Step 5: Run the existing `conductor-dispatch` tests to verify no regression**

Run:
```bash
bash bin/tests/conductor-dispatch.test.sh
```

Expected: `ALL PASSED`.

- [ ] **Step 6: Commit**

```bash
git add bin/conductor-dispatch bin/tests/helper-self-gate.test.sh
git commit -m "feat(conductor-dispatch): self-gate on HARNESS_HOST"
```

---

## Task 3: Teach `setup.sh` about `HARNESS_HOST`

**Files:**
- Modify: `setup.sh`
- Create: `bin/tests/setup-claude-code.test.sh`
- Modify: `bin/tests/setup-conductor-json.test.sh` (update canned input)

- [ ] **Step 1: Write the failing "Claude Code mode" test**

Create `bin/tests/setup-claude-code.test.sh`:

```bash
#!/usr/bin/env bash
# Tests setup.sh in Claude Code mode: HARNESS_HOST=claude-code is written
# to the generated harness.config.sh, no conductor.json is created, and
# the wizard exits 0.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SETUP="$REPO_ROOT/setup.sh"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cp "$SETUP" "$TEST_DIR/"
mkdir -p "$TEST_DIR/.claude/hooks"
echo "placeholder" > "$TEST_DIR/.claude/hooks/harness.config.sh"
cd "$TEST_DIR" && git init -q && git add . && git commit -q -m init

# Drive the wizard:
#   1. Host: 2 (Claude Code only)
#   2. App name: TestApp
#   3. Package manager: pnpm
#   4. Source dirs: src
#   5-10. test/typecheck/lint/format/build/dev cmds: Enter (defaults)
#   11. dev port: 3000 (Enter)
#   12. lockfile: Enter
#   13-16. DB schema/generate/push/migrations: all Enter (blank)
#   17. required env: Enter (blank)
#
# Note: the "Generate conductor.json?" prompt must NOT appear in Claude Code
# mode, so no answer for it is provided.
printf '2\nTestApp\npnpm\nsrc\n\n\n\n\n\n\n3000\n\n\n\n\n\n\n' | bash "$TEST_DIR/setup.sh"

# ── Test: harness.config.sh contains HARNESS_HOST="claude-code" ──
grep -q '^HARNESS_HOST="claude-code"$' "$TEST_DIR/.claude/hooks/harness.config.sh" \
  || fail "HARNESS_HOST=claude-code in config" "config: $(cat "$TEST_DIR/.claude/hooks/harness.config.sh")"
pass "HARNESS_HOST=claude-code in harness.config.sh"

# ── Test: no conductor.json was created ──
[[ ! -f "$TEST_DIR/conductor.json" ]] \
  || fail "no conductor.json in claude-code mode" "file exists: $(cat "$TEST_DIR/conductor.json")"
pass "no conductor.json in claude-code mode"

# ── Test: harness.config.sh is still a valid bash file ──
bash -n "$TEST_DIR/.claude/hooks/harness.config.sh" \
  || fail "generated config is valid bash" "bash -n failed"
pass "generated config is valid bash"

echo ""
echo "ALL PASSED"
```

- [ ] **Step 2: Mark the test executable and run it — expect failure**

Run:
```bash
chmod +x bin/tests/setup-claude-code.test.sh
bash bin/tests/setup-claude-code.test.sh
```

Expected: FAIL at the `read -p "App / project name"` prompt or earlier — setup.sh doesn't understand the leading `2\n` for host selection, so the wizard consumes it as the app name and the rest of the canned input misaligns. Hard failure mid-script.

- [ ] **Step 3: Edit `setup.sh` — insert the host prompt as the first question**

In `setup.sh`, insert the following block immediately after the "Gather inputs" header comment (around line 34) and **before** the existing `read -p "App / project name ..."` prompt:

```bash
# ──────────────────────────────────────────────────────────────────────────────
# Workspace host: Conductor (default inside a Conductor workspace) or plain
# Claude Code. Controls whether we generate conductor.json and chmod Conductor
# helpers, and is written to harness.config.sh for runtime mode detection.
# ──────────────────────────────────────────────────────────────────────────────

# Auto-detect default: Conductor if workspaces dir exists or env var set, else claude-code.
if [ -n "${CONDUCTOR_WORKSPACES_ROOT:-}" ] || [ -d "$HOME/conductor/workspaces" ]; then
  HOST_DEFAULT=1
  HOST_DEFAULT_LABEL="Conductor"
else
  HOST_DEFAULT=2
  HOST_DEFAULT_LABEL="Claude Code"
fi

echo "Workspace host:"
echo "  [1] Conductor"
echo "  [2] Claude Code only"
read -p "Choice [${HOST_DEFAULT} = ${HOST_DEFAULT_LABEL}]: " HOST_CHOICE
HOST_CHOICE="${HOST_CHOICE:-$HOST_DEFAULT}"

case "$HOST_CHOICE" in
  1) HARNESS_HOST="conductor" ;;
  2) HARNESS_HOST="claude-code" ;;
  *) echo "error: invalid choice '$HOST_CHOICE' — expected 1 or 2" >&2; exit 1 ;;
esac

echo "Selected host: $HARNESS_HOST"
echo ""
```

- [ ] **Step 4: Edit `setup.sh` — add `HARNESS_HOST` to the generated config**

In `setup.sh`, find the `cat > "$CONFIG" <<EOF` heredoc (around line 88). Insert a new line for `HARNESS_HOST` immediately after the `# ===...===` banner and before `HARNESS_PKG_MGR=...`:

Change the heredoc body from:

```
HARNESS_PKG_MGR="${PKG_MGR}"
```

to:

```
HARNESS_HOST="${HARNESS_HOST}"
HARNESS_PKG_MGR="${PKG_MGR}"
```

- [ ] **Step 5: Edit `setup.sh` — wrap the Conductor-specific block**

In `setup.sh`, locate the "Generate conductor.json" section (currently around lines 118–172). Wrap the entire block (from `echo ""` before the `read -p "Generate conductor.json?"` prompt through `echo "removes build artifacts aggressively. Adjust for your stack."` and the closing `fi`) in a host guard. The resulting structure:

```bash
# ──────────────────────────────────────────────────────────────────────────────
# Generate conductor.json (Conductor mode only)
# ──────────────────────────────────────────────────────────────────────────────

if [ "$HARNESS_HOST" = "conductor" ]; then
  echo ""
  read -p "Generate conductor.json for Conductor workspace scripts? [Y/n]: " GEN_CONDUCTOR
  GEN_CONDUCTOR="${GEN_CONDUCTOR:-Y}"

  if [[ "$GEN_CONDUCTOR" =~ ^[Yy]$ ]]; then
    # ... existing generation logic unchanged ...
  fi
fi
```

The existing nested `if [[ "$GEN_CONDUCTOR" =~ ^[Yy]$ ]]; then ... fi` logic stays exactly as it is — just wrap the whole outer block in the new `if [ "$HARNESS_HOST" = "conductor" ]; then ... fi`.

- [ ] **Step 6: Edit `setup.sh` — host-aware "Next steps" summary**

In `setup.sh`, find the final summary block that currently prints `Next steps:` and the workflow line (around lines 219–230). Replace the static output with a host-aware branch:

Replace:

```bash
echo "Next steps:"
echo "  1. Review .claude/hooks/harness.config.sh and adjust if needed"
echo "  2. Add .claude/settings.json to your project if not already there"
echo "  3. Add a CLAUDE.md to your project documenting conventions"
echo "  4. Run: claude /harness-health"
echo "     to verify everything is wired up correctly"
echo ""
echo "Workflow:"
echo "  /weekly-goals  → /demo-script → /plan-sprint → /build → /sync"
echo ""
```

with:

```bash
echo "Next steps:"
echo "  1. Review .claude/hooks/harness.config.sh and adjust if needed"
echo "  2. Add .claude/settings.json to your project if not already there"
echo "  3. Add a CLAUDE.md to your project documenting conventions"
echo "  4. Run: claude /harness-health"
echo "     to verify everything is wired up correctly"
echo ""
if [ "$HARNESS_HOST" = "conductor" ]; then
  echo "Conductor workspace scripts written to: conductor.json"
  echo "Review and edit conductor.json before committing."
  echo ""
fi
echo "Workflow:"
echo "  /weekly-goals  → /demo-script → /plan-sprint → /build → /sync"
echo ""
```

- [ ] **Step 7: Run the Claude Code test to verify it passes**

Run:
```bash
bash bin/tests/setup-claude-code.test.sh
```

Expected: `ALL PASSED`.

- [ ] **Step 8: Update the existing Conductor setup test to include the new host prompt**

In `bin/tests/setup-conductor-json.test.sh` (line 31), change:

```bash
printf 'TestApp\npnpm\nsrc\n\n\n\n\n\n\n3000\n\n\n\n\n\n\nY\n' | bash "$TEST_DIR/setup.sh"
```

to:

```bash
# Host choice: 1 (Conductor), then all other existing canned inputs
printf '1\nTestApp\npnpm\nsrc\n\n\n\n\n\n\n3000\n\n\n\n\n\n\nY\n' | bash "$TEST_DIR/setup.sh"
```

Also add a new assertion block immediately after `pass "conductor.json created"`:

```bash
# ── Test: harness.config.sh contains HARNESS_HOST="conductor" ──
grep -q '^HARNESS_HOST="conductor"$' "$TEST_DIR/.claude/hooks/harness.config.sh" \
  || fail "HARNESS_HOST=conductor in config" "config: $(cat "$TEST_DIR/.claude/hooks/harness.config.sh")"
pass "HARNESS_HOST=conductor in harness.config.sh"
```

- [ ] **Step 9: Run the updated Conductor test to verify no regression**

Run:
```bash
bash bin/tests/setup-conductor-json.test.sh
```

Expected: `ALL PASSED`, now including the new `HARNESS_HOST=conductor in harness.config.sh` assertion.

- [ ] **Step 10: Commit**

```bash
git add setup.sh bin/tests/setup-claude-code.test.sh bin/tests/setup-conductor-json.test.sh
git commit -m "feat(setup): add workspace host prompt; write HARNESS_HOST to config"
```

---

## Task 4: Make `/harness-health` Conductor probes conditional

**Files:**
- Modify: `.claude/commands/harness-health.md` (currently lines 79–94)

This is a documentation file read by Claude at runtime; there's no runnable test for the doc itself, so we verify by re-reading after edit and confirming the prose describes both modes correctly.

- [ ] **Step 1: Replace the "Conductor integration checks" section**

In `.claude/commands/harness-health.md`, replace the existing `## Conductor integration checks` section (lines 79–94) with:

```markdown
## Conductor integration checks

First, read `HARNESS_HOST` from `.claude/hooks/harness.config.sh`:

```bash
HARNESS_HOST=$(grep -E '^HARNESS_HOST=' .claude/hooks/harness.config.sh 2>/dev/null | head -1 | sed -E 's/^HARNESS_HOST="?([^"]*)"?$/\1/')
HARNESS_HOST="${HARNESS_HOST:-conductor}"   # unset = conductor (backward compat)
```

If `HARNESS_HOST="claude-code"`, print one line per probe:

```
SKIP: conductor-status (host = claude-code)
SKIP: conductor-dispatch (host = claude-code)
SKIP: conductor-context hook (host = claude-code)
SKIP: conductor-context hook wired in settings.json (host = claude-code)
SKIP: conductor.json (host = claude-code)
SKIP: conductor-status tests (host = claude-code)
SKIP: conductor-dispatch tests (host = claude-code)
SKIP: conductor-context tests (host = claude-code)
```

No probes run. `SKIP` is not a failure — this is expected health for a Claude Code install.

If `HARNESS_HOST="conductor"` (or unset, for backward-compat installs), run:

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

**Conductor mode expected output:** all four `OK:` lines for the helpers + hook wiring. `WARN: conductor.json not present` is acceptable in the harness repo itself (we don't ship one). `FAIL` for any test invocation typically indicates a regression, but on a fresh clone where `bin/conductor-*` helpers are missing, probes 6–8 will also FAIL — the first three `FAIL:` lines from the existence checks are the authoritative signal in that case.

**Claude Code mode expected output:** eight `SKIP:` lines. No `FAIL:`, no `WARN:`.
```

- [ ] **Step 2: Manually re-read the edited file to confirm it's self-consistent**

Read `.claude/commands/harness-health.md` end-to-end. Check:
- The host-detection snippet at the top of the section works against a file that has `HARNESS_HOST="claude-code"` or `HARNESS_HOST="conductor"` quoted exactly as `setup.sh` writes it.
- The branching prose unambiguously tells Claude which set of commands to run in each mode.
- No leftover text from the old unconditional probe list.

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/harness-health.md
git commit -m "feat(harness-health): skip Conductor probes when host is claude-code"
```

---

## Task 5: README — "Choose your host" section + quickstart update

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the Quick Start step 3 to drop the `conductor.json` reference**

In `README.md` (around line 36), replace:

```
3. Run `./setup.sh` — ask me each prompt it shows (package manager, dev port, DB commands, conductor.json, etc.) and relay my answers
```

with:

```
3. Run `./setup.sh` — ask me each prompt it shows (workspace host, package manager, dev port, DB commands, etc.) and relay my answers
```

- [ ] **Step 2: Insert "Choose your host" section above Quick Start**

In `README.md`, insert the following new section immediately after the top intro block (after the `---` that closes the `What's included` file-tree section, before the `## Quick start` heading):

```markdown
## Choose your host

The harness runs in two modes, selected during `./setup.sh` (defaults to the one it detects).

**Conductor mode** — select this if you use [Conductor](https://conductor.build) to run parallel agents. `setup.sh` generates a `conductor.json` with setup/run/archive scripts tailored to your stack, and the `bin/conductor-*` helpers activate sibling-workspace awareness, status manifests, and the sprint-dispatch deep links described under "Conductor integration" below. This is the default when `~/conductor/workspaces` is detected.

**Claude Code mode** — select this for plain Claude Code with no multi-workspace orchestrator. `setup.sh` skips the `conductor.json` generation, and the Conductor helpers self-gate to no-ops so `/plan-sprint` and `/build` run cleanly without trying to dispatch URLs or write status files. Everything else in the harness — hooks, agents, skills, commands — works identically to Conductor mode. This is the default when Conductor is not detected on the machine.

The mode is recorded in `.claude/hooks/harness.config.sh` as `HARNESS_HOST="conductor"` or `HARNESS_HOST="claude-code"`. Re-run `./setup.sh` to switch.

---
```

- [ ] **Step 3: Add a one-line preface to the "Conductor integration" section**

In `README.md`, find the `## Conductor integration` heading (currently around line 191). Insert this line immediately after the heading and before the existing first paragraph:

```markdown
> Only activates when `HARNESS_HOST="conductor"` (default in a Conductor workspace).
```

- [ ] **Step 4: Sanity-check the README renders as intended**

Read the modified `README.md` and confirm:
- Table of sections still flows naturally (What's included → Choose your host → Quick start → Alternative install paths → …).
- The Conductor integration section now begins with the activation line.
- Quick Start step 3 mentions "workspace host" and no longer names `conductor.json`.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs(readme): document workspace host choice; claude-code as first-class mode"
```

---

## Final verification

- [ ] **Step 1: Run the full test suite**

Run each test script in sequence:

```bash
bash bin/tests/helper-self-gate.test.sh
bash bin/tests/setup-claude-code.test.sh
bash bin/tests/setup-conductor-json.test.sh
bash bin/tests/conductor-status.test.sh
bash bin/tests/conductor-dispatch.test.sh
bash bin/tests/conductor-context.test.sh
```

Expected: `ALL PASSED` from each.

- [ ] **Step 2: Simulate a fresh Claude Code install end-to-end**

```bash
TMP=$(mktemp -d)
cp -r .claude "$TMP/"
cp -r bin "$TMP/"
cp setup.sh VERSION "$TMP/"
cd "$TMP" && git init -q && git add . && git commit -q -m init

# Run setup.sh in Claude Code mode with all defaults
printf '2\nTestApp\npnpm\nsrc\n\n\n\n\n\n\n3000\n\n\n\n\n\n\n' | bash "$TMP/setup.sh"

# Verify
grep '^HARNESS_HOST="claude-code"$' "$TMP/.claude/hooks/harness.config.sh"
[ ! -f "$TMP/conductor.json" ] && echo "ok: no conductor.json"

# Conductor helpers should silently no-op even with full args
cd "$TMP" && ./bin/conductor-status update phase=planning workspace=test repo=test
[ ! -f "$TMP/.context/conductor-status.json" ] && echo "ok: no .context/conductor-status.json written"

cd / && rm -rf "$TMP"
```

Expected: `ok: no conductor.json` and `ok: no .context/conductor-status.json written` both print.

- [ ] **Step 3: Confirm the acceptance criteria from the spec**

From `docs/superpowers/specs/2026-04-22-multi-harness-support-design.md`:

1. Fresh clone with `$HOME/conductor` absent → default to `claude-code`, no `conductor.json`, `/harness-health` green. Verified by Step 2 above.
2. Fresh clone with Conductor present → defaults to `conductor`, generates `conductor.json`. Verified by `setup-conductor-json.test.sh`.
3. Existing install without `HARNESS_HOST` → behaves as today. Verified by the "unset HARNESS_HOST defaults to conductor" case in `helper-self-gate.test.sh`.
4. All existing `bin/tests/*.test.sh` pass. Verified in Step 1.
