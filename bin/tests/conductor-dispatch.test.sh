#!/usr/bin/env bash
# Tests for bin/conductor-dispatch. Uses a PATH-shim to capture what `open`
# would have been called with instead of actually opening a URL.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BIN="$REPO_ROOT/bin/conductor-dispatch"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Create a fake `open` that records its arg to a file.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/open" <<'EOF'
#!/usr/bin/env bash
echo "$1" > "$OPEN_CAPTURE"
EOF
chmod +x "$TMP/bin/open"

# Create a fake plan to dispatch.
cat > "$TMP/plan.md" <<'EOF'
# P0.1 — Test plan

This is the plan body.
EOF

# ── Test: --print mode emits the conductor:// URL on stdout ──
out=$(CONDUCTOR_REPO_NAME=myrepo "$BIN" "$TMP/plan.md" --print)
echo "$out" | grep -q '^conductor://async?' || fail "--print emits URL" "got: $out"
echo "$out" | grep -q 'repo=myrepo' || fail "--print includes repo" "got: $out"
echo "$out" | grep -q 'plan=' || fail "--print includes plan=" "got: $out"
pass "--print emits conductor:// URL"

# ── Test: the plan= value decodes back to the plan body ──
b64=$(echo "$out" | sed -E 's|^.*plan=([^&]+).*|\1|')
decoded=$(echo "$b64" | base64 -d)
echo "$decoded" | grep -q "This is the plan body." || fail "plan= decodes to body" "decoded: $decoded"
pass "plan= decodes to body"

# ── Test: --open mode invokes `open` with the URL ──
OPEN_CAPTURE="$TMP/captured.txt"
PATH="$TMP/bin:$PATH" CONDUCTOR_REPO_NAME=myrepo OPEN_CAPTURE="$OPEN_CAPTURE" "$BIN" "$TMP/plan.md" --open >/dev/null
[ -f "$OPEN_CAPTURE" ] || fail "--open invokes open" "no captured URL"
captured=$(cat "$OPEN_CAPTURE")
echo "$captured" | grep -q '^conductor://async?' || fail "--open passes conductor URL" "got: $captured"
pass "--open invokes open"

# ── Test: default mode (no flag) opens + prints ──
: > "$OPEN_CAPTURE"
out=$(PATH="$TMP/bin:$PATH" CONDUCTOR_REPO_NAME=myrepo OPEN_CAPTURE="$OPEN_CAPTURE" "$BIN" "$TMP/plan.md")
[ -s "$OPEN_CAPTURE" ] || fail "default opens" "open not called"
echo "$out" | grep -q '^conductor://async?' || fail "default prints URL" "got: $out"
pass "default mode opens and prints"

# ── Test: missing file exits non-zero ──
set +e
"$BIN" "$TMP/does-not-exist.md" --print 2>/dev/null; rc=$?
set -e
[ "$rc" -ne 0 ] || fail "missing plan exits non-zero" "rc=$rc"
pass "missing plan exits non-zero"

echo ""
echo "ALL PASSED"
