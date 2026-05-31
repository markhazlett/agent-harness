#!/usr/bin/env bash
# bin/tests/deep-review-validate.test.sh — smoke test for deep-review-validate.
#
# Covers the code-review (binary blocking / non-blocking) contract:
#   - All 15 dimensions named in the matrix
#   - Every N/A dim has a justification under "## N/A dimensions"
#   - Every "### " under "## Before merge (N)" is paired with
#     **issue (blocking):** + **suggestion:** within 25 lines
#   - Verdict line is one of: Ship it | Address blocking items first | Substantial concerns
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
VAL="$repo_root/bin/deep-review-validate"
test -x "$VAL" || { echo "FAIL: $VAL not executable"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

matrix='## Verdict Matrix
| # | Dimension | Verdict |
|---|-----------|---------|
| 1 | security | PASS |
| 2 | db | N/A |
| 3 | langgraph | N/A |
| 4 | structural | PASS |
| 5 | performance | PASS |
| 6 | concurrency | PASS |
| 7 | types | PASS |
| 8 | error-handling | PASS |
| 9 | observability | PASS |
| 10 | tests | PASS |
| 11 | api-drift | PASS |
| 12 | deps | PASS |
| 13 | a11y | N/A |
| 14 | dead-code | PASS |
| 15 | docs | PASS |

## N/A dimensions
- db — no migrations touched
- langgraph — no LG paths
- a11y — no frontend files'

# 1. A complete report (no blocking) — should pass
cat > "$tmp/good.md" <<EOF
# Deep Review — sample
**Date:** 2026-05-24

**Verdict:** Ship it

$matrix
EOF

"$VAL" "$tmp/good.md" >/dev/null \
  || { echo "FAIL: validator rejected a complete report"; exit 1; }

# 2. A report missing a dimension — should fail
cat > "$tmp/bad.md" <<'EOF'
# Deep Review — bad
**Verdict:** Ship it
## Verdict Matrix
| 1 | security | PASS |
EOF

"$VAL" "$tmp/bad.md" >/dev/null 2>&1 \
  && { echo "FAIL: validator accepted a report missing dimensions"; exit 1; }

# 3. N/A without justification — should fail
cat > "$tmp/no-just.md" <<'EOF'
# Deep Review — no justifications
**Verdict:** Ship it
## Verdict Matrix
| 1 | security | N/A |
| 2 | db | N/A |
EOF

"$VAL" "$tmp/no-just.md" >/dev/null 2>&1 \
  && { echo "FAIL: validator accepted N/A without justification"; exit 1; }

# 4. A "Before merge" item missing **suggestion:** — should fail
cat > "$tmp/no-suggestion.md" <<EOF
# Deep Review — no suggestion
**Date:** 2026-05-24

**Verdict:** Address blocking items first

## Before merge (1)

### \`api/foo.ts:42\` — missing auth check
**issue (blocking):** the route has no middleware
(no paired suggestion within 25 lines)

$matrix
EOF

"$VAL" "$tmp/no-suggestion.md" >/dev/null 2>&1 \
  && { echo "FAIL: validator accepted blocking item missing **suggestion:**"; exit 1; }

# 5. A "Before merge" item with paired issue (blocking) + suggestion — should pass
cat > "$tmp/with-suggestion.md" <<EOF
# Deep Review — paired blocking
**Date:** 2026-05-24

**Verdict:** Address blocking items first

## Before merge (1)

### \`api/foo.ts:42\` — missing auth check
**issue (blocking):** the route has no middleware; \`if (req.headers.token)\` is never checked, so the handler answers unauthenticated callers.
**suggestion:** add the existing \`requireAuth\` middleware to the route registration in \`api/index.ts\`.

$matrix
EOF

"$VAL" "$tmp/with-suggestion.md" >/dev/null \
  || { echo "FAIL: validator rejected blocking item WITH paired issue+suggestion"; exit 1; }

# 6. A complete report missing the **Verdict:** line — should fail
cat > "$tmp/missing-verdict.md" <<EOF
# Deep Review — no verdict line

$matrix
EOF

"$VAL" "$tmp/missing-verdict.md" >/dev/null 2>&1 \
  && { echo "FAIL: validator accepted a report missing the **Verdict:** line"; exit 1; }

# 7. A report with a bogus Verdict phrase — should fail
cat > "$tmp/bogus-verdict.md" <<EOF
# Deep Review — bogus verdict
**Verdict:** Looks fine to me

$matrix
EOF

"$VAL" "$tmp/bogus-verdict.md" >/dev/null 2>&1 \
  && { echo "FAIL: validator accepted a non-approved Verdict phrase"; exit 1; }

echo "PASS: bin/deep-review-validate smoke test"
