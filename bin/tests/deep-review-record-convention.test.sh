#!/usr/bin/env bash
# bin/tests/deep-review-record-convention.test.sh — smoke test for the
# CLAUDE.md ## Conventions append/create logic.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$REPO_ROOT/bin/deep-review-record-convention"
test -x "$SCRIPT" || { echo "FAIL: $SCRIPT not executable"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Make $tmp a git repo so the script's `git rev-parse --show-toplevel` finds it.
( cd "$tmp" && git init -q && git config user.email t@t.t && git config user.name t )

run() {
  ( cd "$tmp" && "$SCRIPT" "$@" )
}

# ── Case 1: no CLAUDE.md yet — script creates it with the entry ──────────────
rm -f "$tmp/CLAUDE.md"
run --domain "logging style" --pattern "structured JSON via pino" --why "everything else is grep-only" >/dev/null
grep -q '^## Conventions' "$tmp/CLAUDE.md" \
  || { echo "FAIL case 1: missing '## Conventions' header"; cat "$tmp/CLAUDE.md"; exit 1; }
grep -q 'logging style.*structured JSON via pino.*grep-only' "$tmp/CLAUDE.md" \
  || { echo "FAIL case 1: entry not present"; cat "$tmp/CLAUDE.md"; exit 1; }

# ── Case 2: CLAUDE.md exists, no Conventions section — script appends one ────
cat > "$tmp/CLAUDE.md" <<'EOF'
# project — notes

## Overview

Some text.
EOF
run --domain "test framework" --pattern "vitest" --why "jest is being phased out" >/dev/null
grep -q '^## Conventions' "$tmp/CLAUDE.md" \
  || { echo "FAIL case 2: section not appended"; cat "$tmp/CLAUDE.md"; exit 1; }
grep -q 'test framework.*vitest' "$tmp/CLAUDE.md" \
  || { echo "FAIL case 2: entry missing"; exit 1; }
grep -q '## Overview' "$tmp/CLAUDE.md" \
  || { echo "FAIL case 2: existing section was clobbered"; exit 1; }

# ── Case 3: CLAUDE.md with existing ## Conventions — script appends inside ──
cat > "$tmp/CLAUDE.md" <<'EOF'
# project — notes

## Conventions

- **first rule**: do X. existing.

## Next section

content.
EOF
run --domain "api style" --pattern "REST" --why "we don't have GraphQL infra" >/dev/null

# The entry should land BEFORE the next ## (Next section), not after.
nx_line=$(grep -n '^## Next section' "$tmp/CLAUDE.md" | head -1 | cut -d: -f1)
api_line=$(grep -n 'api style.*REST' "$tmp/CLAUDE.md" | head -1 | cut -d: -f1)
[ -n "$nx_line" ] && [ -n "$api_line" ] && [ "$api_line" -lt "$nx_line" ] \
  || { echo "FAIL case 3: entry inserted in wrong position ($api_line vs $nx_line)"; cat "$tmp/CLAUDE.md"; exit 1; }
# Existing entry must survive.
grep -q 'first rule' "$tmp/CLAUDE.md" \
  || { echo "FAIL case 3: existing entry lost"; exit 1; }

# ── Case 4: ## Coding conventions (with trailing parenthetical) ──────────────
cat > "$tmp/CLAUDE.md" <<'EOF'
# project

## Coding conventions (working on this harness)

1. **Surgical changes.** First rule.
2. **Simplicity first.** Second rule.

## Other section

content
EOF
run --domain "shell quoting" --pattern "always quote variables" --why "set -u catches half of it" >/dev/null
grep -q 'shell quoting.*always quote variables' "$tmp/CLAUDE.md" \
  || { echo "FAIL case 4: entry not added to Coding conventions section"; cat "$tmp/CLAUDE.md"; exit 1; }
oc_line=$(grep -n '^## Other section' "$tmp/CLAUDE.md" | head -1 | cut -d: -f1)
sq_line=$(grep -n 'shell quoting' "$tmp/CLAUDE.md" | head -1 | cut -d: -f1)
[ "$sq_line" -lt "$oc_line" ] \
  || { echo "FAIL case 4: entry placed after the Coding section ended"; exit 1; }

# ── Case 5: ## Patterns variant ──────────────────────────────────────────────
cat > "$tmp/CLAUDE.md" <<'EOF'
# project

## Patterns

- existing

EOF
run --domain "concurrency" --pattern "actor model" --why "explicit message boundaries" >/dev/null
grep -q 'concurrency.*actor model' "$tmp/CLAUDE.md" \
  || { echo "FAIL case 5: Patterns variant not handled"; cat "$tmp/CLAUDE.md"; exit 1; }

# ── Case 6: missing required args ────────────────────────────────────────────
if run --domain X --pattern Y 2>/dev/null; then
  echo "FAIL case 6: missing --why should have exited non-zero"
  exit 1
fi

# ── Case 7: evidence field appears in output ────────────────────────────────
rm -f "$tmp/CLAUDE.md"
run --domain "retries" --pattern "exponential backoff" --why "network is the failure mode" \
    --evidence "src/queue.ts:42, src/http.ts:88" >/dev/null
grep -q 'src/queue.ts:42, src/http.ts:88' "$tmp/CLAUDE.md" \
  || { echo "FAIL case 7: --evidence not surfaced in entry"; cat "$tmp/CLAUDE.md"; exit 1; }

echo "PASS: bin/deep-review-record-convention smoke test (7 cases)"
