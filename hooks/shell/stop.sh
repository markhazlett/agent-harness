#!/usr/bin/env bash
# Stop hook — run tests, typecheck, write handoff, notify
set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
# shellcheck source=config.sh
source "$REPO_ROOT/.claude/hooks/config.sh" 2>/dev/null || true

INPUT=$(cat)

# Prevent recursion if stop hook re-triggers itself
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

cd "$REPO_ROOT"

# Get changed files
CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null || echo "")
STAGED_FILES=$(git diff --name-only --cached 2>/dev/null || echo "")
ALL_CHANGED="$CHANGED_FILES"$'\n'"$STAGED_FILES"

RESULTS_FILE="/tmp/${HARNESS_APP_NAME// /-}-test-results"

# Run tests if source files changed (match configured src dirs)
SRC_PATTERN="(${HARNESS_SRC_DIRS})/"
if echo "$ALL_CHANGED" | grep -qE "$SRC_PATTERN"; then
  echo "Running tests for changed source files..." >&2
  if eval "$HARNESS_TEST_CMD" 2>&1 | tee "$RESULTS_FILE"; then
    echo "Tests passed." >&2
  else
    echo "Tests failed — please fix before finishing." >&2
    exit 2
  fi
fi

# Run typecheck if configured and source files changed
if [ -n "$HARNESS_TYPECHECK_CMD" ] && echo "$ALL_CHANGED" | grep -qE "$SRC_PATTERN"; then
  echo "Running typecheck..." >&2
  TYPECHECK_RESULTS="/tmp/${HARNESS_APP_NAME// /-}-typecheck-results"
  if eval "$HARNESS_TYPECHECK_CMD" 2>&1 | tee "$TYPECHECK_RESULTS"; then
    echo "Typecheck passed." >&2
  else
    echo "Typecheck failed — please fix before finishing." >&2
    exit 2
  fi
fi

# Write handoff notes
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "unknown")
LAST_COMMIT=$(git log --oneline -1 2>/dev/null || echo "none")
mkdir -p "$REPO_ROOT/.claude/handoff"
cat > "$REPO_ROOT/.claude/handoff/latest.md" <<EOF
# Session Handoff
- **Branch:** $BRANCH
- **Last commit:** $LAST_COMMIT
- **Changed files:**
$(git diff --name-only HEAD~1 2>/dev/null | sed 's/^/  - /' || echo "  - (none)")
- **Timestamp:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

# macOS notification (no-op on other platforms)
if command -v osascript &>/dev/null; then
  osascript -e "display notification \"Session complete\" with title \"${HARNESS_APP_NAME} — Claude Code\"" 2>/dev/null || true
fi

exit 0
