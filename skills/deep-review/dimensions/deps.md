# Dimension: Dependency Hygiene

## Charter

Audit this branch diff for **new or changed dependencies**: justification, maintenance status, license, supply-chain risk, and bloat. Look at `package.json`, `pnpm-lock.yaml`, `package-lock.json`, `Cargo.toml`, `Cargo.lock`, `requirements*.txt`, `pyproject.toml`, `go.mod`, `go.sum`, `Gemfile`/`Gemfile.lock`.

## Anchoring (read before flagging)

Before flagging any finding, consult two sources the orchestrator provides:

1. **`conventions`** (verbatim from the repo's CLAUDE.md `## Conventions` section, possibly empty) — if non-empty, treat it as authoritative for what this codebase considers good. A finding that contradicts a stated convention is HIGH conviction; a finding that proposes a different pattern is LOW conviction.
2. **`exemplars`** (up to 3 sibling files of each changed file) — read at least one before flagging a structural / pattern issue. If the exemplars show a pattern your finding contradicts, raise conviction. If the exemplars show the codebase doesn't use the pattern you'd recommend, drop your finding to NIT or skip it. Do not propose patterns from training data when the codebase has a demonstrated alternative.

## What you flag

1. **New runtime dependency without justification.** A package added to `dependencies` (not `devDependencies`) with no comment in the PR / commit / CHANGELOG explaining why. Flag MED.
2. **Abandonware.** Last-publish date > 18 months ago, no maintainers responding to issues, archived repo. Verify via the registry. Flag HIGH if it's a runtime dep, MED for devDeps.
3. **Pre-release / unstable version.** `^0.x.x` or `alpha`/`beta`/`rc` tags pinned in production. Flag MED.
4. **License risk.** GPL-family / AGPL / SSPL where the project is non-GPL. Verify license field in registry. Flag HIGH.
5. **Supply-chain duplicate.** New dep brings in a transitive that's already at a different major version. Bloat + potential bug surface. Flag LOW.
6. **Suspicious newcomer.** Brand-new package (< 30 days old) with no organizational provenance. Flag HIGH (harness security principle §51 — supply chain).
7. **Replacing a stdlib feature.** New dep that wraps something the language stdlib already does (e.g., `is-array`). Flag MED.

## Severity rubric

- **CRITICAL** — known-malicious package.
- **HIGH** — abandonware in production, license risk, brand-new unknown package.
- **MED** — unjustified add, pre-release in prod, stdlib-replacing dep.
- **LOW** — version duplicates, minor bloat.
- **NIT** — sub-major version pin style differences.

## Anti-overlap

- You do NOT flag security CVEs in deps (`security` may own this; verify if there's overlap).
- You do NOT flag bundle-size performance impact (`performance` owns runtime perf).
- You do NOT flag missing types for new deps (`types` owns type safety).

## FP calibration (MED profile)

Calibrate to 0.5+ for triage to keep (MED profile drops below 0.50 in stage 3). Maintenance-status claims need verification — quote the registry page or the last-publish date.

## Examples

**TRUE positive:** `package.json` added `legacy-shim-xyz@^0.3.1`. Registry shows last publish 2023-08, 4 open issues, archived repo. Conviction 0.85.

**FALSE positive:** `package.json` added `react@^18.3.1`. Maintenance is active, license MIT, in use widely. Conviction 0.05 — drop.
