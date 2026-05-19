#!/usr/bin/env bash
# Cross-host install verification. Runs setup.sh for each of the three
# HARNESS_HOST values into separate tempdirs and asserts that each
# produces a healthy install structure with the right file layout, host
# config, and a valid bash config.
#
# This catches regressions where a setup.sh change for one host
# accidentally breaks another. Complements the per-host tests
# (setup-claude-code.test.sh, setup-conductor-json.test.sh,
# setup-pi.test.sh) which exercise host-specific behaviors in depth.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SETUP="$REPO_ROOT/setup.sh"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

# Stage a minimal harness checkout in a tempdir so setup.sh has the source
# trees it copies from. Returns the path via STAGE_DIR.
stage_harness() {
  local target="$1"
  cp "$SETUP" "$target/"

  mkdir -p "$target/skills/example-skill"
  cat > "$target/skills/example-skill/SKILL.md" <<'SKILL'
---
name: example-skill
description: example skill for cross-host install tests
---

Body.
SKILL

  mkdir -p "$target/prompts"
  echo "Example prompt body." > "$target/prompts/example.md"

  mkdir -p "$target/agents"
  cat > "$target/agents/example.md" <<'AGENT'
---
model: sonnet
---

Example agent body.
AGENT

  mkdir -p "$target/hooks/shell"
  cat > "$target/hooks/shell/example.sh" <<'HOOK'
#!/usr/bin/env bash
# example shell hook
echo "example"
HOOK
  chmod +x "$target/hooks/shell/example.sh"

  mkdir -p "$target/hooks/pi/example/__tests__"
  cat > "$target/hooks/pi/example/index.ts" <<'EXT'
export default function (pi: unknown): void {
  void pi;
}
EXT
  cat > "$target/hooks/pi/package.json" <<'PKG'
{
  "name": "@agent-harness/pi-extensions",
  "version": "0.0.0",
  "private": true
}
PKG

  echo "# Template" > "$target/AGENTS.md.template"

  cd "$target" && git init -q && git add . && git commit -q -m init && cd - >/dev/null
}

# Run setup.sh in a fresh tempdir for a given host choice (1=Conductor,
# 2=Claude Code only, 3=Pi). Returns the install dir path.
run_setup() {
  local host_choice="$1"
  local stage
  stage=$(mktemp -d)
  stage_harness "$stage"

  # Drive the wizard:
  #   1. Host: $host_choice
  #   2. App name: TestApp
  #   3. Pkg mgr: pnpm
  #   4. Src dirs: src
  #   5-10. test/typecheck/lint/format/build/dev (Enter defaults)
  #   11. dev port: 3000 (Enter)
  #   12. lockfile (Enter)
  #   13-16. DB schema/generate/push/migrations (blank)
  #   17. required env (blank)
  #   18. LangGraph opt-in (Enter)
  #
  # Conductor mode adds a "Generate conductor.json?" prompt.
  # AGENTS.md/CLAUDE.md copy prompt fires when no instructions file exists.
  # CRITICAL: cd into the stage dir before running setup.sh so its
  # `git rev-parse --show-toplevel` resolves to the staged checkout, not
  # to the agent-harness repo running this test.
  if [ "$host_choice" = "1" ]; then
    # Conductor mode: extra Y for conductor.json prompt + Y for instructions
    (cd "$stage" && printf '%s\nTestApp\npnpm\nsrc\n\n\n\n\n\n\n3000\n\n\n\n\n\n\n\nY\nY\n' \
      "$host_choice" | bash ./setup.sh) >"$stage/setup.log" 2>&1 \
      || { echo "setup.sh (host=$host_choice) failed — log:"; cat "$stage/setup.log"; exit 1; }
  else
    # Claude Code (2) or Pi (3): no conductor.json prompt
    (cd "$stage" && printf '%s\nTestApp\npnpm\nsrc\n\n\n\n\n\n\n3000\n\n\n\n\n\n\n\nY\n' \
      "$host_choice" | bash ./setup.sh) >"$stage/setup.log" 2>&1 \
      || { echo "setup.sh (host=$host_choice) failed — log:"; cat "$stage/setup.log"; exit 1; }
  fi
  echo "$stage"
}

# ─── conductor ───────────────────────────────────────────────────────
DIR_CONDUCTOR=$(run_setup 1)
trap "rm -rf '$DIR_CONDUCTOR'" EXIT

grep -q '^HARNESS_HOST="conductor"$' "$DIR_CONDUCTOR/.claude/hooks/config.sh" \
  || fail "conductor: HARNESS_HOST=conductor" "$(cat "$DIR_CONDUCTOR/.claude/hooks/config.sh")"
pass "conductor: HARNESS_HOST=conductor in config.sh"

[ -f "$DIR_CONDUCTOR/conductor.json" ] \
  || fail "conductor: conductor.json created" "missing"
pass "conductor: conductor.json created"

[ -f "$DIR_CONDUCTOR/CLAUDE.md" ] \
  || fail "conductor: CLAUDE.md created from template" "missing"
pass "conductor: CLAUDE.md created from template"

bash -n "$DIR_CONDUCTOR/.claude/hooks/config.sh" \
  || fail "conductor: config.sh is valid bash" "bash -n failed"
pass "conductor: config.sh is valid bash"

# ─── claude-code ─────────────────────────────────────────────────────
DIR_CC=$(run_setup 2)
trap "rm -rf '$DIR_CONDUCTOR' '$DIR_CC'" EXIT

grep -q '^HARNESS_HOST="claude-code"$' "$DIR_CC/.claude/hooks/config.sh" \
  || fail "claude-code: HARNESS_HOST=claude-code" "$(cat "$DIR_CC/.claude/hooks/config.sh")"
pass "claude-code: HARNESS_HOST=claude-code in config.sh"

[ ! -f "$DIR_CC/conductor.json" ] \
  || fail "claude-code: no conductor.json" "file exists"
pass "claude-code: no conductor.json"

[ -f "$DIR_CC/CLAUDE.md" ] \
  || fail "claude-code: CLAUDE.md created from template" "missing"
pass "claude-code: CLAUDE.md created from template"

bash -n "$DIR_CC/.claude/hooks/config.sh" \
  || fail "claude-code: config.sh is valid bash" "bash -n failed"
pass "claude-code: config.sh is valid bash"

# ─── pi ──────────────────────────────────────────────────────────────
DIR_PI=$(run_setup 3)
trap "rm -rf '$DIR_CONDUCTOR' '$DIR_CC' '$DIR_PI'" EXIT

grep -q '^HARNESS_HOST="pi"$' "$DIR_PI/.pi/hooks/config.sh" \
  || fail "pi: HARNESS_HOST=pi" "$(cat "$DIR_PI/.pi/hooks/config.sh")"
pass "pi: HARNESS_HOST=pi in config.sh"

[ -d "$DIR_PI/.pi/skills" ] && [ -d "$DIR_PI/.pi/prompts" ] && \
  [ -d "$DIR_PI/.pi/agents" ] && [ -d "$DIR_PI/.pi/extensions" ] \
  || fail "pi: .pi/ tree populated" "missing one of skills/prompts/agents/extensions"
pass "pi: .pi/ tree populated"

[ -f "$DIR_PI/.pi/settings.json" ] \
  || fail "pi: .pi/settings.json exists" "missing"
pass "pi: .pi/settings.json exists"

if command -v jq >/dev/null 2>&1; then
  jq -e '.skills and .prompts and .extensions' "$DIR_PI/.pi/settings.json" >/dev/null \
    || fail "pi: settings.json has required keys" "$(cat "$DIR_PI/.pi/settings.json")"
  pass "pi: settings.json has skills/prompts/extensions keys"
fi

[ ! -f "$DIR_PI/conductor.json" ] \
  || fail "pi: no conductor.json" "file exists"
pass "pi: no conductor.json"

[ ! -f "$DIR_PI/CLAUDE.md" ] \
  || fail "pi: no CLAUDE.md" "file exists"
pass "pi: no CLAUDE.md"

[ -f "$DIR_PI/AGENTS.md" ] \
  || fail "pi: AGENTS.md created from template" "missing"
pass "pi: AGENTS.md created from template"

bash -n "$DIR_PI/.pi/hooks/config.sh" \
  || fail "pi: .pi/hooks/config.sh is valid bash" "bash -n failed"
pass "pi: .pi/hooks/config.sh is valid bash"

echo ""
echo "ALL THREE HOSTS PASSED"
