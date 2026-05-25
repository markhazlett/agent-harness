#!/usr/bin/env bash
# Regression test for the self-overwrite footgun in bin/harness-update.
#
# When --apply updates bin/harness-update itself, `cp` truncates the file
# in-place. Bash, which is reading the script by FD, sees garbage at its
# next read offset and exits 1 *after* the apply has already printed
# "Applied N change(s)" — a transient error that confused users about
# whether the upgrade succeeded.
#
# Fix: at the start of --apply, copy ourselves to a tempfile and re-exec
# from there. The on-disk bin/harness-update is then free to be replaced
# without affecting the running process.
#
# This test stages a target whose bin/harness-update will be overwritten
# by --apply, invokes the *target's* copy (so the running script is the
# one being replaced), and asserts a clean exit 0.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
UPDATE_SRC="$REPO_ROOT/bin/harness-update"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; [ -n "${2:-}" ] && echo "  $2"; exit 1; }

WORK=$(mktemp -d -t harness-self-overwrite.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

# ─── Stage upstream with a modified bin/harness-update ─────────────────────
# The modification just needs to make the file's sha256 differ from the
# target's copy so --plan classifies it as update_safe. We prepend a comment
# line; the script's behavior is unchanged.
UPSTREAM="$WORK/source"
mkdir -p "$UPSTREAM/bin" "$UPSTREAM/.claude/hooks" \
         "$UPSTREAM/skills" "$UPSTREAM/agents" "$UPSTREAM/prompts"
{
  head -1 "$UPDATE_SRC"
  echo "# upstream marker for self-overwrite regression test"
  tail -n +2 "$UPDATE_SRC"
} > "$UPSTREAM/bin/harness-update"
chmod +x "$UPSTREAM/bin/harness-update"

echo "0.99.0" > "$UPSTREAM/VERSION"

(cd "$UPSTREAM" \
  && git init -q \
  && git add . \
  && git -c user.email=t@t -c user.name=t commit -q -m init)

# ─── Stage a target with the current bin/harness-update ────────────────────
TARGET="$WORK/target"
mkdir -p "$TARGET/bin"
cp "$UPDATE_SRC" "$TARGET/bin/harness-update"
chmod +x "$TARGET/bin/harness-update"
echo "0.0.1" > "$TARGET/VERSION"

(cd "$TARGET" \
  && git init -q \
  && git add . \
  && git -c user.email=t@t -c user.name=t commit -q -m init)

STATE="$WORK/state"
mkdir -p "$STATE"

# Seed the manifest so bin/harness-update is classified as update_safe rather
# than as a no-manifest conflict. Record the *target's* current hash as both
# upstream_hash and local_hash (the state "user untouched since install").
TARGET_HASH=$(shasum -a 256 "$TARGET/bin/harness-update" | awk '{print $1}')
VERSION_HASH=$(shasum -a 256 "$TARGET/VERSION" | awk '{print $1}')
cat > "$STATE/installed-manifest.json" <<MANIFEST
{
  "version_when_installed": "0.0.1",
  "installed_at": "2026-01-01T00:00:00Z",
  "files": {
    "bin/harness-update": {
      "upstream_hash": "${TARGET_HASH}",
      "local_hash": "${TARGET_HASH}"
    },
    "VERSION": {
      "upstream_hash": "${VERSION_HASH}",
      "local_hash": "${VERSION_HASH}"
    }
  }
}
MANIFEST

# ─── Build the plan ────────────────────────────────────────────────────────
PLAN_FILE="$WORK/plan.json"
(cd "$TARGET" \
  && HARNESS_STATE_DIR="$STATE" \
     HARNESS_SOURCE_DIR="$UPSTREAM" \
     "$TARGET/bin/harness-update" --plan > "$PLAN_FILE")

# Sanity: the plan must include bin/harness-update under update_safe.
jq -e '.actions.update_safe | map(select(.path == "bin/harness-update")) | length == 1' \
  "$PLAN_FILE" >/dev/null \
  || fail "test setup: plan does not list bin/harness-update under update_safe" \
          "$(jq -c '.actions' "$PLAN_FILE")"

echo '{"conflicts":{}}' > "$WORK/resolve.json"

# ─── --apply: run the target's bin/harness-update (which will overwrite itself)
# Crucially, we run "$TARGET/bin/harness-update" — not "$UPDATE_SRC" — so the
# script being executed is the same file --apply will rewrite. Capture stdout,
# stderr, and exit code without `set -e` killing the test on the bug.
set +e
APPLY_OUT=$(cd "$TARGET" \
  && HARNESS_STATE_DIR="$STATE" \
     HARNESS_SOURCE_DIR="$UPSTREAM" \
     "$TARGET/bin/harness-update" --apply \
       --from "$PLAN_FILE" \
       --resolve "$WORK/resolve.json" 2>&1)
APPLY_RC=$?
set -e

[ "$APPLY_RC" -eq 0 ] \
  || fail "--apply exited non-zero when overwriting itself (rc=$APPLY_RC)" \
          "output: $APPLY_OUT"
pass "--apply exits 0 when overwriting bin/harness-update mid-run"

# bin/harness-update should now be the upstream version.
NEW_HASH=$(shasum -a 256 "$TARGET/bin/harness-update" | awk '{print $1}')
UPSTREAM_HASH=$(shasum -a 256 "$UPSTREAM/bin/harness-update" | awk '{print $1}')
[ "$NEW_HASH" = "$UPSTREAM_HASH" ] \
  || fail "bin/harness-update was not replaced by the upstream copy" \
          "local=$NEW_HASH upstream=$UPSTREAM_HASH"
pass "bin/harness-update on disk matches the upstream copy after --apply"

# No leftover tempfiles in /tmp from the re-exec (loose check — we just look
# for our own reexec naming prefix among recently-created entries).
leftover=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'harness-update-reexec.*' -mmin -1 2>/dev/null | head -5)
if [ -n "$leftover" ]; then
  fail "re-exec tempfile(s) leaked into TMPDIR" "$leftover"
fi
pass "re-exec tempfile cleaned up"

echo ""
echo "ALL PASS"
