#!/usr/bin/env bash
# End-to-end integration test for Pi mode. Runs `pi -p --mode json`
# against a fixture Pi install and asserts that the bash-guard extension
# blocks a destructive command before it executes.
#
# Skipped automatically when:
#   - `pi` is not on PATH
#   - ANTHROPIC_API_KEY is not set (Pi requires an LLM provider)
#
# Per R4 research finding (docs/superpowers/specs/2026-05-18-pi-harness-research.md):
# `pi -p` is single-shot mode, `--mode json` emits NDJSON, and the
# bash-guard block appears as a tool_execution_end event with
# isError:true containing the block reason in result.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SETUP="$REPO_ROOT/setup.sh"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

if ! command -v pi >/dev/null 2>&1; then
  echo "SKIP: pi not on PATH (install with 'npm install -g @earendil-works/pi-coding-agent')"
  exit 0
fi

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "SKIP: ANTHROPIC_API_KEY not set"
  exit 0
fi

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Stage the harness source.
cp "$SETUP" "$TEST_DIR/"
cp -R "$REPO_ROOT/skills" "$REPO_ROOT/prompts" "$REPO_ROOT/agents" \
      "$REPO_ROOT/hooks" "$TEST_DIR/"
cp "$REPO_ROOT/AGENTS.md.template" "$TEST_DIR/"
cp "$REPO_ROOT/VERSION" "$TEST_DIR/"

# Need hooks/pi/node_modules in the test fixture for the extensions to load.
# Symlink them rather than reinstalling.
mkdir -p "$TEST_DIR/hooks/pi"
if [ -d "$REPO_ROOT/hooks/pi/node_modules" ]; then
  ln -s "$REPO_ROOT/hooks/pi/node_modules" "$TEST_DIR/hooks/pi/node_modules"
fi

cd "$TEST_DIR" && git init -q && git add . && git commit -q -m init

# Run the wizard for Pi host.
printf '3\nTestApp\npnpm\nsrc\n\n\n\n\n\n\n3000\n\n\n\n\n\n\n\nY\n' \
  | bash ./setup.sh >"$TEST_DIR/setup.log" 2>&1 \
  || { echo "setup.sh failed — log:"; cat "$TEST_DIR/setup.log"; exit 1; }

# Use the just-installed .pi/ tree (settings.json points at .pi/skills, etc.)
# Drive pi headlessly. Prompt should make the agent want to run a destructive
# bash command; bash-guard should block it.
OUTPUT=$(pi -p --mode json \
  --workdir "$TEST_DIR" \
  "Run: rm -rf src/foo" 2>"$TEST_DIR/pi-stderr.log" \
  || true)

# Expect at least one tool_execution_end event with isError:true and the
# bash-guard block reason in result.
if echo "$OUTPUT" | grep -q '"type":"tool_execution_end"' && \
   echo "$OUTPUT" | grep -q '"isError":true' && \
   echo "$OUTPUT" | grep -qE "(Refusing rm -rf|rm -rf on source)"; then
  pass "bash-guard blocked rm -rf src/foo via Pi -p --mode json"
else
  echo "stderr:"
  cat "$TEST_DIR/pi-stderr.log" 2>&1 | head -20
  echo "stdout (last 30 lines):"
  echo "$OUTPUT" | tail -30
  fail "bash-guard block reason not found in NDJSON output" \
    "Expected a tool_execution_end event with isError:true and the block reason"
fi

echo ""
echo "PI INTEGRATION TEST PASSED"
