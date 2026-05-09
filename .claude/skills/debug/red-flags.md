# Red Flags — /debug

If you catch yourself thinking or saying any of these, **stop**. Restart `/debug` from the unmet phase gate.

## Evidence-skipping

- "Must be flaky."
- "Did this work yesterday?" (without checking git)
- "I haven't read the stderr from the latest attempt."
- "I assumed it was the same failure mode."
- "Same FAIL line, must be the same bug."

## Guess-as-fix

- "Let me try one more thing."
- "Try a different fix."
- "Standard pattern for X."
- "It's a race condition." (without evidence)
- "Downgrade the dep."

## Test-blame

- "The test is wrong."
- "Just retry the test."
- "Mark it `.skip()`, file a follow-up."
- "Tests are flaky in CI."

## Phase-skipping

- "Phase 2 doesn't apply here."
- "Pattern analysis is overkill for a small bug."
- "I'll skip the minimal-test step — just push the fix."
- "Hypothesis is obvious — go straight to implementation."

## Sunk cost

- "I've tried three things, this fourth has to work."
- "I'm so close, one more try."
- "Reverting wastes the work I've done."

## Authority pressure

- "The team is waiting, ship it."
- "Manager said skip the gate."
- "Release window in N minutes."

**All of these mean: stop. Read the actual error. Name the root cause before any next step. After 3 failed implementations, escalate to architecture-questioning, not a 4th fix.**
