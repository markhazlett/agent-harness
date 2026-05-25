#!/usr/bin/env bash
# bin/tests/deep-review-fixture.test.sh — smoke test for bin/deep-review-fixture.
#
# Verifies the fixture script:
#   1. Creates a self-contained git repo at --out
#   2. Produces three commits: init (main) + feat + chore (FIXED-IN-COMMIT)
#   3. Plants the documented findings (key files present, sentinel content)
#   4. Activates the db gate when deep-review-scan is run against it
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
FIXTURE="$repo_root/bin/deep-review-fixture"
SCAN="$repo_root/bin/deep-review-scan"
test -x "$FIXTURE" || { echo "FAIL: $FIXTURE not executable"; exit 1; }
test -x "$SCAN"    || { echo "FAIL: $SCAN not executable"; exit 1; }

OUT=$(mktemp -d -t dr-fixture-test.XXXXXX)
trap 'rm -rf "$OUT"' EXIT

# 1. fixture script runs and creates a git repo at OUT
"$FIXTURE" --out "$OUT" >/dev/null
test -d "$OUT/.git" || { echo "FAIL: $OUT/.git not created"; exit 1; }

cd "$OUT"

# 2. three commits: init on main, feat + chore on feature
git checkout -q feature
commits=$(git --no-pager log --oneline main..feature | wc -l | tr -d ' ')
[ "$commits" = "2" ] || { echo "FAIL: expected 2 commits on feature (got $commits)"; exit 1; }

# main branch only has the init commit
main_commits=$(git --no-pager log --oneline main | wc -l | tr -d ' ')
[ "$main_commits" = "1" ] || { echo "FAIL: expected 1 commit on main (got $main_commits)"; exit 1; }

# 3. planted findings present at tip of feature
test -f db/migrations/0001_drop_legacy_email.sql || { echo "FAIL: migration file missing"; exit 1; }
grep -q "DROP COLUMN email_legacy" db/migrations/0001_drop_legacy_email.sql \
  || { echo "FAIL: planted DROP COLUMN finding missing"; exit 1; }
grep -q "sk_live_" src/config.ts \
  || { echo "FAIL: planted hardcoded-key finding missing"; exit 1; }
grep -q "// ignore — caller will retry" src/charge.ts \
  || { echo "FAIL: planted empty-catch finding missing"; exit 1; }
grep -q "PRICING_TIER_CENTS = 2999" src/config.ts \
  || { echo "FAIL: planted magic-value finding missing"; exit 1; }

# legacy-shim-xyz should be present in the parent commit (HEAD~1) but
# absent from tip — this is the FIXED-IN-COMMIT setup.
parent_pkg=$(git show HEAD~1:package.json)
echo "$parent_pkg" | grep -q "legacy-shim-xyz" \
  || { echo "FAIL: legacy-shim-xyz missing from parent commit (FIXED-IN-COMMIT setup broken)"; exit 1; }
tip_pkg=$(cat package.json)
echo "$tip_pkg" | grep -q "legacy-shim-xyz" \
  && { echo "FAIL: legacy-shim-xyz still present at tip (FIXED-IN-COMMIT setup broken)"; exit 1; }

# 4. deep-review-scan against this fixture activates the db gate
scan_json=$("$SCAN" main)
echo "$scan_json" | grep -q '"db": true' \
  || { echo "FAIL: db gate did not fire (config.sh not picked up?)"; echo "scan output:"; echo "$scan_json"; exit 1; }
echo "$scan_json" | grep -q 'db/migrations/0001_drop_legacy_email.sql' \
  || { echo "FAIL: migration file not in scan diff"; exit 1; }

echo "PASS: bin/deep-review-fixture smoke test"
