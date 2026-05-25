#!/usr/bin/env bash
# PostToolUseFailure hook (async) — logs failures for diagnostics.
#
# Builds each JSONL line via jq (so embedded quotes/newlines in error strings
# can't corrupt the file) and serializes concurrent writes with flock when
# available — POSIX guarantees O_APPEND atomicity only up to PIPE_BUF (512
# bytes on macOS), and tool_input can easily exceed that for Bash commands.
set -uo pipefail

INPUT=$(cat)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
LOG_DIR="$REPO_ROOT/.claude/logs"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/failures.jsonl"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build the line with jq so embedded quotes / control chars / newlines in the
# tool_input or error are correctly escaped — the old string-concat approach
# produced invalid JSONL whenever an error string contained a literal '"'.
LINE=$(jq -nc \
  --arg ts "$TIMESTAMP" \
  --argjson in "$INPUT" \
  '{timestamp:$ts, tool:($in.tool_name // "unknown"), input:($in.tool_input // {}), error:($in.error // "unknown error")}' \
  2>/dev/null) || exit 0  # jq failure shouldn't surface to the user

if command -v flock >/dev/null 2>&1; then
  ( flock -x 200; printf '%s\n' "$LINE" >&200 ) 200>>"$LOG_FILE"
else
  printf '%s\n' "$LINE" >> "$LOG_FILE"
fi

exit 0
