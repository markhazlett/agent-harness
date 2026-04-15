#!/usr/bin/env bash
# SessionStart hook (startup) — injects context into Claude's session
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
# shellcheck source=harness.config.sh
source "$REPO_ROOT/.claude/hooks/harness.config.sh" 2>/dev/null || true

echo "=== Session Context ==="
echo ""

# 1. Current branch
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
echo "Branch: $BRANCH"
if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  echo "WARNING: You are on $BRANCH — switch to a feature branch before making changes"
fi
echo ""

# 2. Last 5 commits
echo "Recent commits:"
git log --oneline -5 2>/dev/null || echo "(no commits)"
echo ""

# 3. Uncommitted changes
CHANGES=$(git status --short 2>/dev/null)
if [ -n "$CHANGES" ]; then
  echo "Uncommitted changes:"
  echo "$CHANGES"
  echo ""
fi

# 4. Handoff notes
HANDOFF="$REPO_ROOT/.claude/handoff/latest.md"
if [ -f "$HANDOFF" ]; then
  echo "=== Handoff Notes ==="
  cat "$HANDOFF"
  echo ""
fi

# 5. Last test results
LAST_RESULTS="/tmp/${HARNESS_APP_NAME// /-}-test-results"
if [ -f "$LAST_RESULTS" ]; then
  echo "=== Last Test Results ==="
  tail -20 "$LAST_RESULTS"
  echo ""
fi
