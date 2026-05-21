#!/usr/bin/env bash
# PostToolUseFailure hook (async) — logs failures for diagnostics
set -uo pipefail

INPUT=$(cat)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
LOG_DIR="$REPO_ROOT/.claude/logs"
mkdir -p "$LOG_DIR"

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
ERROR=$(echo "$INPUT" | jq -r '.error // "unknown error"')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "{\"timestamp\":\"$TIMESTAMP\",\"tool\":\"$TOOL_NAME\",\"input\":$TOOL_INPUT,\"error\":\"$ERROR\"}" >> "$LOG_DIR/failures.jsonl"

exit 0
