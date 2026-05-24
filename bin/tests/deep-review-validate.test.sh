#!/usr/bin/env bash
# bin/tests/deep-review-validate.test.sh — smoke test for deep-review-validate.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
VAL="$repo_root/bin/deep-review-validate"
test -x "$VAL" || { echo "FAIL: $VAL not executable"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# A complete report — should pass
cat > "$tmp/good.md" <<'EOF'
# Deep Review — sample
**Date:** 2026-05-24

## Verdict Matrix
| # | Dimension      | Verdict |
|---|----------------|---------|
| 1 | security       | PASS    |
| 2 | db             | N/A     |
| 3 | langgraph      | N/A     |
| 4 | structural     | PASS    |
| 5 | performance    | PASS    |
| 6 | concurrency    | PASS    |
| 7 | types          | PASS    |
| 8 | error-handling | PASS    |
| 9 | observability  | PASS    |
| 10 | tests         | PASS    |
| 11 | api-drift     | PASS    |
| 12 | deps          | PASS    |
| 13 | a11y          | N/A     |
| 14 | dead-code     | PASS    |
| 15 | docs          | PASS    |

## N/A dimensions
- db — no migrations touched
- langgraph — no LG paths
- a11y — no frontend files
EOF

"$VAL" "$tmp/good.md" >/dev/null \
  || { echo "FAIL: validator rejected a complete report"; exit 1; }

# A report missing a dimension — should fail
cat > "$tmp/bad.md" <<'EOF'
# Deep Review — bad
## Verdict Matrix
| 1 | security | PASS |
EOF

"$VAL" "$tmp/bad.md" >/dev/null 2>&1 \
  && { echo "FAIL: validator accepted a report missing dimensions"; exit 1; }

# N/A without justification — should fail
cat > "$tmp/no-just.md" <<'EOF'
# Deep Review — no justifications
## Verdict Matrix
| 1 | security | N/A |
| 2 | db | N/A |
EOF

"$VAL" "$tmp/no-just.md" >/dev/null 2>&1 \
  && { echo "FAIL: validator accepted N/A without justification"; exit 1; }

# A report with a BLOCKING finding lacking **Evidence:** — should fail
cat > "$tmp/no-evidence.md" <<'EOF'
# Deep Review — no evidence

## Verdict Matrix
| 1 | security | FAIL |
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

## BLOCKING (1)
### 1. [security] api/foo.ts:42 — missing auth check
**Impact:** anyone can read the route
**Suggested fix:** add middleware

## N/A dimensions
- db — no migrations touched
- langgraph — no LG paths
- a11y — no frontend files
EOF

"$VAL" "$tmp/no-evidence.md" >/dev/null 2>&1 \
  && { echo "FAIL: validator accepted BLOCKING finding without **Evidence:**"; exit 1; }

# A report with a BLOCKING finding that DOES have **Evidence:** — should pass
cat > "$tmp/with-evidence.md" <<'EOF'
# Deep Review — with evidence

## Verdict Matrix
| 1 | security | FAIL |
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

## BLOCKING (1)
### 1. [security] api/foo.ts:42 — missing auth check
**Evidence:** `if (req.headers.token) { ... }` is never checked
**Impact:** anyone can read the route
**Suggested fix:** add middleware

## N/A dimensions
- db — no migrations touched
- langgraph — no LG paths
- a11y — no frontend files
EOF

"$VAL" "$tmp/with-evidence.md" >/dev/null \
  || { echo "FAIL: validator rejected BLOCKING finding WITH **Evidence:**"; exit 1; }

# A report with a HIGH finding lacking **Evidence:** — should fail
cat > "$tmp/high-no-evidence.md" <<'EOF'
# Deep Review — high no evidence

## Verdict Matrix
| 1 | security | PASS |
| 2 | db | N/A |
| 3 | langgraph | N/A |
| 4 | structural | WARN |
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

## HIGH (1)
### 1. [structural] auth/session.ts:142 — file too big
**Impact:** harder to maintain

## N/A dimensions
- db — no migrations touched
- langgraph — no LG paths
- a11y — no frontend files
EOF

"$VAL" "$tmp/high-no-evidence.md" >/dev/null 2>&1 \
  && { echo "FAIL: validator accepted HIGH finding without **Evidence:**"; exit 1; }

echo "PASS: bin/deep-review-validate smoke test"
