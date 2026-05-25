#!/usr/bin/env bash
# bin/tests/deep-review-scan-full-codebase.test.sh — tests for the
# --full-codebase mode of deep-review-scan. Each test builds an isolated
# git repo under a tempdir and asserts the emitted JSON manifest.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
SCAN="$repo_root/bin/deep-review-scan"
test -x "$SCAN" || { echo "FAIL: $SCAN not executable"; exit 1; }

tmp=
cleanup() { [ -n "${tmp:-}" ] && rm -rf "$tmp"; return 0; }
trap cleanup EXIT

setup_repo() {
  cleanup
  tmp=$(mktemp -d)
  cd "$tmp"
  git init -q
  git config user.email "test@test"
  git config user.name "test"
}

# Test 1: no manifests anywhere → falls back to top-level dir chunks
setup_repo
mkdir -p src/api src/ui scripts
echo "a" > src/api/a.ts
echo "b" > src/ui/b.tsx
echo "c" > scripts/c.sh
echo "root" > README.md
git add . && git commit -q -m "base"

out=$("$SCAN" --full-codebase 2>&1) || { echo "FAIL test 1: scan exited nonzero"; echo "$out"; exit 1; }
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
assert m['mode'] == 'full-codebase', f'expected mode=full-codebase, got {m.get(\"mode\")!r}'
names = sorted(c['name'] for c in m['chunks'])
assert 'src' in names, f'expected src chunk, got {names}'
assert 'scripts' in names, f'expected scripts chunk, got {names}'
" || { echo "FAIL test 1"; echo "$out"; exit 1; }
echo "  test 1 OK (top-level fallback)"

# Test 2: package.json at subdir → that subdir is a chunk root
setup_repo
mkdir -p packages/web/src packages/cli/src
echo '{}' > packages/web/package.json
echo '{}' > packages/cli/package.json
echo "a" > packages/web/src/a.ts
echo "b" > packages/cli/src/b.ts
git add . && git commit -q -m "base"

out=$("$SCAN" --full-codebase 2>&1) || { echo "FAIL test 2: scan exited nonzero"; echo "$out"; exit 1; }
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
names = sorted(c['name'] for c in m['chunks'])
assert 'packages/web' in names, f'expected packages/web chunk, got {names}'
assert 'packages/cli' in names, f'expected packages/cli chunk, got {names}'
web = [c for c in m['chunks'] if c['name'] == 'packages/web'][0]
assert any(f.endswith('packages/web/src/a.ts') for f in web['files']), f'expected a.ts in web chunk, got {web[\"files\"]}'
assert not any('packages/cli' in f for f in web['files']), f'web chunk leaked cli files: {web[\"files\"]}'
" || { echo "FAIL test 2"; echo "$out"; exit 1; }
echo "  test 2 OK (package.json subdir = chunk)"

# Test 3: mixed-ecosystem (package.json + pyproject.toml)
setup_repo
mkdir -p web/src service
echo '{}' > web/package.json
echo "[project]" > service/pyproject.toml
echo "a" > web/src/a.ts
echo "b" > service/main.py
git add . && git commit -q -m "base"

out=$("$SCAN" --full-codebase 2>&1) || { echo "FAIL test 3"; echo "$out"; exit 1; }
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
names = sorted(c['name'] for c in m['chunks'])
assert 'web' in names and 'service' in names, f'expected web + service, got {names}'
" || { echo "FAIL test 3"; echo "$out"; exit 1; }
echo "  test 3 OK (mixed-ecosystem)"

# Test 4: .gitignored files do not appear in any chunk
setup_repo
mkdir -p src node_modules
echo "node_modules/" > .gitignore
echo "a" > src/a.ts
echo "bad" > node_modules/bad.js
git add .gitignore src/a.ts && git commit -q -m "base"

out=$("$SCAN" --full-codebase 2>&1) || { echo "FAIL test 4"; echo "$out"; exit 1; }
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
all_files = [f for c in m['chunks'] for f in c['files']]
assert not any('node_modules' in f for f in all_files), f'gitignored file leaked: {all_files}'
" || { echo "FAIL test 4"; echo "$out"; exit 1; }
echo "  test 4 OK (.gitignore respected)"

# Test 5: totals object present + sums
setup_repo
mkdir -p src
echo -e "a\nb\nc" > src/a.ts
echo -e "d\ne" > src/b.ts
git add . && git commit -q -m "base"

out=$("$SCAN" --full-codebase 2>&1) || { echo "FAIL test 5"; echo "$out"; exit 1; }
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
t = m.get('totals')
assert t is not None, 'totals missing'
assert t['files'] == 2, f'expected 2 files, got {t.get(\"files\")}'
assert t['chunks'] >= 1, f'expected at least 1 chunk, got {t.get(\"chunks\")}'
" || { echo "FAIL test 5"; echo "$out"; exit 1; }
echo "  test 5 OK (totals)"

# Test 6: per-chunk gate detection — a11y fires only on chunks with frontend files
setup_repo
mkdir -p ui/src api/src
echo '{}' > ui/package.json
echo '{}' > api/package.json
echo "export const X = () => <div/>;" > ui/src/x.tsx
echo "export const y = 1;" > api/src/y.ts
git add . && git commit -q -m "base"

out=$("$SCAN" --full-codebase 2>&1) || { echo "FAIL test 6"; echo "$out"; exit 1; }
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
ui = [c for c in m['chunks'] if c['name'] == 'ui'][0]
api = [c for c in m['chunks'] if c['name'] == 'api'][0]
assert ui['gates']['a11y'] is True, f'expected ui a11y=true, got {ui[\"gates\"]}'
assert api['gates']['a11y'] is False, f'expected api a11y=false, got {api[\"gates\"]}'
" || { echo "FAIL test 6"; echo "$out"; exit 1; }
echo "  test 6 OK (per-chunk a11y gate)"

# Test 7: back-compat — calling without --full-codebase still emits diff manifest
setup_repo
mkdir -p src
echo "a" > src/a.ts
git add . && git commit -q -m "base"
git checkout -q -b feature
echo "b" >> src/a.ts
git add . && git commit -q -m "feature"

out=$("$SCAN" 2>&1) || { echo "FAIL test 7"; echo "$out"; exit 1; }
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
assert 'diff' in m, 'diff field missing from default scan'
assert m.get('mode', 'diff') == 'diff', f'unexpected mode in default scan: {m.get(\"mode\")!r}'
" || { echo "FAIL test 7"; echo "$out"; exit 1; }
echo "  test 7 OK (back-compat)"

echo "PASS: bin/deep-review-scan --full-codebase"
