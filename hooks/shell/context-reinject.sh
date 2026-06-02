#!/usr/bin/env bash
# SessionStart hook (resume|compact) — lighter context re-injection
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

echo "=== Context (resumed) ==="
echo ""

# 1. Current branch
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
echo "Branch: $BRANCH"

# 2. Last commit
echo "Last commit: $(git log --oneline -1 2>/dev/null || echo '(none)')"
echo ""

# 3. Handoff notes
HANDOFF="$REPO_ROOT/.claude/handoff/latest.md"
if [ -f "$HANDOFF" ]; then
  echo "=== Handoff Notes ==="
  cat "$HANDOFF"
  echo ""
fi
