#!/usr/bin/env bash
# Tests setup.sh in Pi mode: HARNESS_HOST=pi is written, .pi/ tree is
# populated with skills/prompts/agents/extensions, .pi/settings.json is
# valid JSON, and AGENTS.md is created from the template.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SETUP="$REPO_ROOT/setup.sh"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Stage the harness source files the way a real install does.
cp "$SETUP" "$TEST_DIR/"
mkdir -p "$TEST_DIR/skills/example-skill"
echo "---
name: example
description: example skill
---" > "$TEST_DIR/skills/example-skill/SKILL.md"

mkdir -p "$TEST_DIR/prompts"
echo "Example prompt." > "$TEST_DIR/prompts/example.md"

mkdir -p "$TEST_DIR/agents"
echo "---
model: sonnet
---
Example agent." > "$TEST_DIR/agents/example.md"

# Stage a minimal hooks/pi tree with one extension to copy.
mkdir -p "$TEST_DIR/hooks/pi/example/__tests__"
echo "export default function(pi) {}" > "$TEST_DIR/hooks/pi/example/index.ts"
echo '{"name": "@agent-harness/pi-extensions", "version": "0.0.0", "private": true}' \
  > "$TEST_DIR/hooks/pi/package.json"

# Stage a minimal .claude/docs template (setup.sh references it for the
# AGENTS.md/CLAUDE.md template-copy step).
mkdir -p "$TEST_DIR/.claude/docs"
echo "# Template" > "$TEST_DIR/.claude/docs/claude-md-template.md"

cd "$TEST_DIR" && git init -q && git add . && git commit -q -m init

# Drive the wizard. Choice [3] = Pi.
# (Same prompt sequence as setup-claude-code.test.sh, just first answer is 3.
# No conductor.json prompt, no CLAUDE.md/AGENTS.md prompt if file is missing
# we answer Y at the end.)
printf '3\nTestApp\npnpm\nsrc\n\n\n\n\n\n\n3000\n\n\n\n\n\n\n\nY\n' \
  | bash "$TEST_DIR/setup.sh" >/tmp/setup-pi-out.log 2>&1 \
  || { echo "setup.sh failed — log:"; cat /tmp/setup-pi-out.log; exit 1; }

# Test: HARNESS_HOST=pi in generated config
grep -q '^HARNESS_HOST="pi"$' "$TEST_DIR/.pi/hooks/config.sh" \
  || fail "HARNESS_HOST=pi in config" "config: $(cat "$TEST_DIR/.pi/hooks/config.sh")"
pass "HARNESS_HOST=pi in config.sh"

# Test: .pi/skills/ populated
[[ -d "$TEST_DIR/.pi/skills/example-skill" ]] \
  || fail ".pi/skills/example-skill/ created" ".pi/skills contents: $(ls "$TEST_DIR/.pi/skills" 2>&1)"
pass ".pi/skills populated with example skill"

# Test: .pi/prompts/ populated
[[ -f "$TEST_DIR/.pi/prompts/example.md" ]] \
  || fail ".pi/prompts/example.md exists" "missing"
pass ".pi/prompts populated"

# Test: .pi/agents/ populated
[[ -f "$TEST_DIR/.pi/agents/example.md" ]] \
  || fail ".pi/agents/example.md exists" "missing"
pass ".pi/agents populated"

# Test: .pi/extensions/ has the Pi extension copied
[[ -f "$TEST_DIR/.pi/extensions/example/index.ts" ]] \
  || fail ".pi/extensions/example/index.ts exists" "missing"
pass ".pi/extensions populated"

# Test: .pi/settings.json is valid JSON with expected top-level keys
[[ -f "$TEST_DIR/.pi/settings.json" ]] \
  || fail ".pi/settings.json exists" "missing"

if command -v jq >/dev/null 2>&1; then
  jq -e '.skills and .prompts and .extensions' "$TEST_DIR/.pi/settings.json" >/dev/null \
    || fail ".pi/settings.json has skills/prompts/extensions keys" "$(cat "$TEST_DIR/.pi/settings.json")"
  pass ".pi/settings.json is valid JSON with required keys"
else
  pass ".pi/settings.json exists (jq not available; structure not deep-checked)"
fi

# Test: no conductor.json in Pi mode
[[ ! -f "$TEST_DIR/conductor.json" ]] \
  || fail "no conductor.json in Pi mode" "file exists"
pass "no conductor.json in Pi mode"

# Test: no CLAUDE.md was created (Pi uses AGENTS.md instead)
[[ ! -f "$TEST_DIR/CLAUDE.md" ]] \
  || fail "no CLAUDE.md in Pi mode" "file exists"
pass "no CLAUDE.md in Pi mode"

# Test: AGENTS.md was created from template (we answered Y to the copy prompt)
[[ -f "$TEST_DIR/AGENTS.md" ]] \
  || fail "AGENTS.md created from template" "missing"
pass "AGENTS.md created from template"

# Test: config.sh is valid bash
bash -n "$TEST_DIR/.pi/hooks/config.sh" \
  || fail "generated .pi/hooks/config.sh is valid bash" "bash -n failed"
pass "generated config is valid bash"

echo ""
echo "ALL PASSED"
