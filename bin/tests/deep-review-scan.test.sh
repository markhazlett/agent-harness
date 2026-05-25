#!/usr/bin/env bash
# bin/tests/deep-review-scan.test.sh — smoke test for deep-review-scan.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
SCAN="$repo_root/bin/deep-review-scan"
test -x "$SCAN" || { echo "FAIL: $SCAN not executable"; exit 1; }

# Build a synthetic test repo
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q
git config user.email "test@test"
git config user.name "test"
mkdir -p src/agents src/components migrations

# Base commit includes sibling .tsx files so exemplar-mining can surface them
echo "// base" > src/index.ts
echo "export const Sibling = () => <div>existing</div>;" > src/components/Sibling.tsx
echo "export const Cousin = () => <div>also existing</div>;" > src/components/Cousin.tsx
git add . && git commit -q -m "base"
git checkout -q -b feature

# Diff that should trigger db + langgraph + a11y gates
# (Btn.tsx is in the diff; Sibling.tsx and Cousin.tsx are NOT — they are exemplar candidates)
echo "CREATE TABLE foo (id INT);" > migrations/001_init.sql
echo "import { createReactAgent } from 'langgraph';" > src/agents/foo.ts
echo "export const Btn = () => <button>x</button>;" > src/components/Btn.tsx
git add . && git commit -q -m "feature"

# Provide a config.sh so gates fire
mkdir -p .claude/hooks
cat > .claude/hooks/config.sh <<'EOF'
HARNESS_DB_MIGRATIONS_DIR="migrations"
HARNESS_DB_SCHEMA_PATH=""
HARNESS_LANGGRAPH="true"
EOF

# Run scan
out=$("$SCAN" 2>&1) || { echo "FAIL: scan exited nonzero"; echo "$out"; exit 1; }

# Assert valid JSON
echo "$out" | python3 -c "import sys,json; json.loads(sys.stdin.read())" \
  || { echo "FAIL: not valid JSON"; echo "$out"; exit 1; }

# Assert gates
echo "$out" | grep -q '"db": *true'          || { echo "FAIL: db gate not true"; exit 1; }
echo "$out" | grep -q '"langgraph": *true'   || { echo "FAIL: langgraph gate not true"; exit 1; }
echo "$out" | grep -q '"a11y": *true'        || { echo "FAIL: a11y gate not true"; exit 1; }

# Assert exemplar-mining: Sibling.tsx is NOT in the diff, so it should appear in exemplars
echo "$out" | grep -q 'Sibling\.tsx' \
  || { echo "FAIL: exemplar-mining did not surface src/components/Sibling.tsx"; echo "$out"; exit 1; }

# Assert exemplars field exists on each scope entry
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
for dim, scope in m.get('scopes', {}).items():
    assert 'exemplars' in scope, f'scope {dim!r} missing exemplars field'
    assert isinstance(scope['exemplars'], list), f'scope {dim!r} exemplars is not a list'
print('exemplars OK')
" || { echo "FAIL: exemplars field missing from scopes"; exit 1; }

# Assert conventions extraction: write a CLAUDE.md with a ## Conventions section
cat > CLAUDE.md <<'CLAUDEOF'
# Project

Stuff.

## Conventions

Forms use react-hook-form + zod.
Queries go through lib/db/queries.ts.

## Other Section
unrelated
CLAUDEOF

out=$("$SCAN" 2>&1) || { echo "FAIL: scan exited nonzero after adding CLAUDE.md"; echo "$out"; exit 1; }
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
conv = m.get('conventions', None)
assert conv is not None, 'conventions field missing from output'
assert 'react-hook-form' in conv, f'expected react-hook-form in conventions, got: {conv!r}'
assert 'queries go through' in conv.lower(), f'expected queries.ts reference in conventions, got: {conv!r}'
assert 'unrelated' not in conv, f'conventions should not bleed into other sections: {conv!r}'
print('conventions OK')
" || { echo "FAIL: conventions extraction"; exit 1; }

# Conventions with tab + CR characters — must produce valid JSON
printf '## Conventions\n\tTab-indented code line\nNormal line with \r CR\n' > CLAUDE.md
out=$("$SCAN" 2>&1)
echo "$out" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
conv = m.get('conventions', '')
assert '\\\\t' in conv or '\\t' in conv, f'expected escaped tab in conventions, got: {conv!r}'
" || { echo "FAIL: conventions escaping for tab/CR"; echo "$out"; exit 1; }
echo "tab/CR conventions OK"

echo "PASS: bin/deep-review-scan smoke test"
