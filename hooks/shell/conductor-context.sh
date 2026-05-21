#!/usr/bin/env bash
# SessionStart hook — injects sibling Conductor workspace state into context.
# Silently no-ops outside a ~/conductor/workspaces/<repo>/<workspace>/ tree.
set -euo pipefail

HOOK_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$HOOK_DIR/../.." && pwd)
# shellcheck source=config.sh
source "$HOOK_DIR/config.sh" 2>/dev/null || true

ROOT="${CONDUCTOR_WORKSPACES_ROOT:-$HOME/conductor/workspaces}"

# Resolve: is the current directory under the workspaces root?
case "$PWD/" in
  "$ROOT"/*/*) ;;
  *) exit 0 ;;  # not in Conductor workspace tree — silent no-op
esac

STATUS_BIN="$REPO_ROOT/bin/conductor-status"
[ -x "$STATUS_BIN" ] || exit 0  # helper not installed yet — no-op

"$STATUS_BIN" list --exclude-self 2>/dev/null || true
