#!/usr/bin/env bash
# PreToolUse hook for Bash — blocks dangerous commands
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
# shellcheck source=harness.config.sh
source "$REPO_ROOT/.claude/hooks/harness.config.sh" 2>/dev/null || true

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Get current branch
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "unknown")

block() {
  echo '{"decision": "block", "reason": "'"$1"'"}' >&2
  exit 2
}

# 1. Block git commit/push on main/master
if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  if echo "$COMMAND" | grep -qE '^\s*git\s+(commit|push)'; then
    block "Cannot commit or push on $BRANCH — use a feature branch"
  fi
fi

# 2. Block --no-verify
if echo "$COMMAND" | grep -qE '\-\-no-verify'; then
  block "--no-verify is not allowed — hooks must not be skipped"
fi

# 3. Block destructive sed -i on source files
if echo "$COMMAND" | grep -qE "sed\s+-i.*\s+(${HARNESS_SRC_DIRS})/"; then
  block "sed -i on source files is not allowed — use the Edit tool instead"
fi

# 4. Block rm -rf on source directories
if echo "$COMMAND" | grep -qE "rm\s+-rf\s+(${HARNESS_SRC_DIRS})/"; then
  block "rm -rf on source directories is not allowed"
fi

# 5. Block redirect overwrites to source files (allow /tmp, /dev/null, .claude/logs)
if echo "$COMMAND" | grep -qE ">\s+(${HARNESS_SRC_DIRS})/"; then
  block "Redirect to source files is not allowed — use the Write tool instead"
fi

exit 0
