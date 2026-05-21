#!/usr/bin/env bash
# Tests that setup.sh generates a valid conductor.json
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SETUP="$REPO_ROOT/setup.sh"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; exit 1; }

# ── Setup: create a temp repo mirroring what setup.sh expects ──
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cp "$SETUP" "$TEST_DIR/"
mkdir -p "$TEST_DIR/.claude/hooks"
echo "placeholder" > "$TEST_DIR/.claude/hooks/config.sh"
touch "$TEST_DIR/.env.example"
cd "$TEST_DIR" && git init -q && git add . && git commit -q -m init

# Drive the wizard with canned answers:
#   Host choice: 1 (Conductor)
#   App name: TestApp
#   Package manager: pnpm
#   Source dirs: src
#   test/typecheck/lint/format/build/dev cmds: all Enter (defaults)
#   dev port: 3000 (Enter)
#   lockfile: Enter
#   DB schema/generate/push/migrations: all Enter (blank)
#   required env: Enter (blank)
#   LangGraph opt-in: Enter (defaults to N — disabled)
#   Generate conductor.json: Y
printf '1\nTestApp\npnpm\nsrc\n\n\n\n\n\n\n3000\n\n\n\n\n\n\n\nY\n' | bash "$TEST_DIR/setup.sh"

# ── Test: conductor.json was created ──
[[ -f "$TEST_DIR/conductor.json" ]] || fail "conductor.json created" "file not found"
pass "conductor.json created"

# Test: config.sh contains HARNESS_HOST="conductor"
grep -q '^HARNESS_HOST="conductor"$' "$TEST_DIR/.claude/hooks/config.sh" \
  || fail "HARNESS_HOST=conductor in config" "config: $(cat "$TEST_DIR/.claude/hooks/config.sh")"
pass "HARNESS_HOST=conductor in config.sh"

# ── Test: conductor.json is valid JSON ──
jq . "$TEST_DIR/conductor.json" >/dev/null 2>&1 || fail "conductor.json is valid JSON" "jq parse failed"
pass "conductor.json is valid JSON"

# ── Test: scripts.setup includes pnpm install ──
setup_val=$(jq -r '.scripts.setup' "$TEST_DIR/conductor.json")
echo "$setup_val" | grep -q "pnpm install" || fail "setup includes pnpm install" "got: $setup_val"
pass "setup script includes pnpm install"

# ── Test: scripts.setup includes .env copy (since .env.example exists) ──
echo "$setup_val" | grep -q "cp .env.example .env" || fail "setup includes .env copy" "got: $setup_val"
pass "setup script includes .env copy"

# ── Test: scripts.run is the dev command and binds to workspace port ──
run_val=$(jq -r '.scripts.run' "$TEST_DIR/conductor.json")
echo "$run_val" | grep -q "pnpm run dev" || fail "run is dev cmd" "got: $run_val"
pass "run script is pnpm run dev"
echo "$run_val" | grep -q 'PORT=${CONDUCTOR_PORT:-3000}' || fail "run binds to \${CONDUCTOR_PORT:-3000}" "got: $run_val"
pass "run script binds to \${CONDUCTOR_PORT:-3000}"

# ── Test: run script exports CONDUCTOR_PORT to the dev server at runtime ──
# Stub the dev command: record PORT into a file, exit 0.
run_stub_dir=$(mktemp -d)
run_stub_log="$run_stub_dir/pnpm.log"
cat > "$run_stub_dir/pnpm" <<STUB
#!/usr/bin/env bash
echo "PORT=\$PORT args=\$*" >> "$run_stub_log"
STUB
chmod +x "$run_stub_dir/pnpm"
PATH="$run_stub_dir:$PATH" CONDUCTOR_PORT=3042 bash -c "$run_val" >/dev/null 2>&1 || true
grep -q 'PORT=3042 args=run dev' "$run_stub_log" || fail "run passes CONDUCTOR_PORT to dev cmd" "stub log: $(cat "$run_stub_log" 2>/dev/null)"
pass "run script passes CONDUCTOR_PORT to dev cmd"
rm -rf "$run_stub_dir"

# ── Test: scripts.archive is present and non-empty ──
archive_val=$(jq -r '.scripts.archive' "$TEST_DIR/conductor.json")
[[ -n "$archive_val" ]] || fail "archive script is non-empty" "got empty"
pass "archive script is non-empty"

# ── Test: archive uses portable lsof/kill pattern (not xargs -r) ──
echo "$archive_val" | grep -q 'lsof -ti:${CONDUCTOR_PORT:-3000}' || fail "archive uses \${CONDUCTOR_PORT:-3000}" "got: $archive_val"
pass "archive uses \${CONDUCTOR_PORT:-3000} for per-workspace port"
echo "$archive_val" | grep -qv "xargs -r" || fail "archive does not contain xargs -r" "got: $archive_val"
pass "archive does not contain xargs -r"

# ── Test: archive script expands CONDUCTOR_PORT at runtime ──
# Simulate what Conductor would run: set CONDUCTOR_PORT to 3042 and check that
# the archive script targets that port (via a stubbed lsof that logs its args).
stub_dir=$(mktemp -d)
stub_log="$stub_dir/lsof.log"
cat > "$stub_dir/lsof" <<STUB
#!/usr/bin/env bash
echo "lsof-called-with: \$*" >> "$stub_log"
STUB
chmod +x "$stub_dir/lsof"
PATH="$stub_dir:$PATH" CONDUCTOR_PORT=3042 bash -c "$archive_val" >/dev/null 2>&1 || true
grep -q 'lsof-called-with: -ti:3042' "$stub_log" || fail "archive expands CONDUCTOR_PORT at runtime" "stub log: $(cat "$stub_log" 2>/dev/null)"
pass "archive expands CONDUCTOR_PORT at runtime"
rm -rf "$stub_dir"

echo ""
echo "ALL PASSED"
