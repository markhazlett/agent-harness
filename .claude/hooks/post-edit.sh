#!/usr/bin/env bash
# PostToolUse hook (async) for Edit|Write|MultiEdit — auto-format and lint
set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
# shellcheck source=harness.config.sh
source "$REPO_ROOT/.claude/hooks/harness.config.sh" 2>/dev/null || true

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Only process configured extensions
EXT_PATTERN="\\.(${HARNESS_FORMATTABLE_EXTS})$"
if ! echo "$FILE_PATH" | grep -qE "$EXT_PATTERN"; then
  exit 0
fi

cd "$REPO_ROOT"

# Auto-generate and push DB migration when schema file changes
if [ -n "$HARNESS_DB_SCHEMA_PATH" ] && [ -n "$HARNESS_DB_GENERATE_CMD" ]; then
  NORMALIZED_PATH="${FILE_PATH#$REPO_ROOT/}"
  if [[ "$NORMALIZED_PATH" == "$HARNESS_DB_SCHEMA_PATH" ]]; then
    eval "$HARNESS_DB_GENERATE_CMD" 2>/dev/null || true
    if [ -n "$HARNESS_DB_PUSH_CMD" ]; then
      eval "$HARNESS_DB_PUSH_CMD" 2>/dev/null || true
    fi
  fi
fi

# Auto-format with Prettier (if available)
if command -v npx &>/dev/null; then
  npx prettier --write "$FILE_PATH" 2>/dev/null || true
fi

# Lint with ESLint (warnings only, non-blocking)
if echo "$FILE_PATH" | grep -qE "\\.(ts|tsx|js|jsx)$"; then
  if command -v npx &>/dev/null; then
    npx eslint "$FILE_PATH" 2>&1 || true
  fi
fi

exit 0
