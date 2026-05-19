#!/usr/bin/env bash
# ConfigChange hook (async) — log settings/skill changes for auditing
set -uo pipefail

INPUT=$(cat)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
LOG_DIR="$REPO_ROOT/.claude/logs"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
CHANGE_TYPE=$(echo "$INPUT" | jq -r '.type // "unknown"')
DETAILS=$(echo "$INPUT" | jq -c '.' 2>/dev/null || echo '{}')

echo "{\"timestamp\":\"$TIMESTAMP\",\"change_type\":\"$CHANGE_TYPE\",\"details\":$DETAILS}" >> "$LOG_DIR/config-changes.jsonl"

exit 0
