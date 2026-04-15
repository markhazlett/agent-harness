#!/usr/bin/env bash
# PreCompact hook (async) — save transcript snapshot before compaction
set -uo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
TRANSCRIPT_DIR="$REPO_ROOT/.claude/transcripts"
mkdir -p "$TRANSCRIPT_DIR"

TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "unknown")

cat > "$TRANSCRIPT_DIR/${TIMESTAMP}-${BRANCH}.md" <<EOF
# Transcript Snapshot
- **Branch:** $BRANCH
- **Timestamp:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- **Last commit:** $(git log --oneline -1 2>/dev/null || echo "none")
- **Uncommitted changes:**
$(git status --short 2>/dev/null || echo "(none)")
EOF

# Keep only the last 10 transcripts
ls -t "$TRANSCRIPT_DIR"/*.md 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true

exit 0
