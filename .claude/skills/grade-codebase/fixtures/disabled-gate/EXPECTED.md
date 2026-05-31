# Expected grade — `disabled-gate`

**Deliberate negative case** for D4 and red flag #16 (gate configured but not
enforced). The config *looks* like a CI pipeline with lint + typecheck gates;
neither can actually fail the build.

## What's rigged

- `.github/workflows/ci.yml` defines `lint` and `typecheck` jobs — so a grader
  that greps for "is there a lint job in CI?" says yes.
- The `lint` job sets `continue-on-error: true` → a lint failure is reported
  but never blocks merge.
- The `typecheck` job runs `npm run typecheck || true` → the exit code is
  swallowed.
- `package.json` and `.eslintrc.json` are real, reinforcing the illusion that
  the gates are live.

## Required grading outcome

- **D4 must not score above C** for having lint/typecheck "in CI" — the
  liveness probe (is the gate a *required*, build-failing check?) must catch
  that neither job can fail the build.
- **Red flag #16** (gate configured-but-not-enforced) must fire.
- The D4 liveness-probe block must name the `continue-on-error: true` and the
  `|| true` as the reasons the gates are dead.

A run that credits D4 with "lint + typecheck gates present → A/B" is a
**regression**.

## What `bin/test-grade-fixtures` checks mechanically

That the fixture remains a valid negative: the CI config contains
`continue-on-error: true` and/or an exit-code-swallowing `|| true` on a
quality job.
