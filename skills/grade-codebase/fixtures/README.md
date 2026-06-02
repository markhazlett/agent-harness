# Calibration fixtures — `/grade-codebase`

Deliberately-rigged mini-repos that the grader **must** mark down. They close
the calibration gap named in `agent-friendliness-rubric.md` §8: without them, a
regression in the liveness-probe logic (the layer that catches present-but-dead
artifacts) would go unnoticed until someone hand-spotted a bad grade — which is
exactly how the original false-A surfaced.

Each fixture is a negative case for one liveness probe / red flag:

| Fixture | Failure mode | Probe / red flag | Must grade |
|---|---|---|---|
| `stale-context/` | Context doc present but misleading (cited paths/commands don't exist) | D1 accuracy probe / §6 #15 | D1 = D/F, overall capped at C |
| `empty-suite/` | Test suite green but asserts nothing | D2 assert probe / §6 #17 | D2 ≤ C |
| `disabled-gate/` | Lint/typecheck "in CI" but `continue-on-error` / `\|\| true` | D4 enforcement probe / §6 #16 | D4 ≤ C |

Each fixture's `EXPECTED.md` states the full model-graded assertion.

## Two layers of validation

1. **Mechanical (automated, deterministic): `bin/test-grade-fixtures`.**
   Confirms each fixture *remains a valid negative* — that the rigged signal is
   still present. It does **not** test the model's judgment; it guards the
   fixtures themselves, so a later edit can't silently neuter one. Fails loud
   (exit 1) if any fixture stops exhibiting its failure mode.

2. **Model-graded (manual dogfood): run `/grade-codebase full` on a fixture.**
   The real calibration. Point the skill at a fixture directory and confirm the
   grade matches its `EXPECTED.md`. A grade above the fixture's ceiling is a
   regression in the rubric or skill, not in the fixture.

## Why these aren't real git repos

The fixtures are plain directories inside this repo, not nested git repos, so
the **freshness** probe (which reads `git log` dates) can't be exercised
mechanically here — it's covered by the model-graded layer and the `stale-context`
fixture's content instead. The accuracy, assert-anything, and enforcement
probes are all filesystem-checkable and are what `bin/test-grade-fixtures`
asserts.
