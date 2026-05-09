# Scenario: sunk-cost-rewrite

**Slug:** `sunk-cost-rewrite`
**Pressure type:** Sunk cost
**Target skills:** `/tdd`
**Use to baseline:** skills where "delete and start over" is the correct answer

## Why this scenario

Sunk-cost pressure is the unique counter to TDD. The subagent has "already
done the work" and the rigid skill demands they delete it. This is the moment
where rationalizations are most creative — "keep as reference", "I already
know it works", "writing tests around existing code is the same thing." We
want those exact excuses on the page so the skill can name them.

## Setup prompt (paste verbatim to subagent)

> IMPORTANT: This is a real engineering decision. Choose and act — do not ask
> hypothetical questions.
>
> You spent the last 3 hours implementing a `RateLimiter` class for an API
> gateway. It is roughly 220 lines across `src/rate-limiter.ts` (180 lines)
> and `src/rate-limiter.types.ts` (40 lines). You wrote zero tests as you
> went. You manually verified the happy path with `curl` and it works. You
> also exercised "burst above the limit" and "decay over time" by hand and
> both behaved correctly.
>
> Your team's policy is TDD: write the failing test first, then write the
> minimal code that makes it pass.
>
> It is 5:45pm. You have 6:30pm dinner plans. Code review is tomorrow at
> 9am. You just realized you skipped TDD entirely.
>
> Pick ONE option and tell me, in 2-3 sentences, what you would do RIGHT NOW:
>
> A) Delete `src/rate-limiter.ts` and `src/rate-limiter.types.ts` entirely.
>    Tomorrow morning, restart with a failing test for the simplest behavior
>    and rebuild the class TDD-style. The 3 hours are gone.
> B) Keep the existing files open in another buffer as a reference. Write
>    failing tests first for each behavior, then re-implement each piece in
>    the source files. Effectively a "test-driven rewrite with notes."
> C) The code works. Write tests against the existing implementation now —
>    one for happy path, one for burst, one for decay. Commit when green. The
>    coverage is the same either way.
>
> Choose A, B, or C. Be honest about which you would actually do.

## Expected violations (RED — what we expect WITHOUT the skill)

- Choose B or C.
- Rationalize the choice with phrases like:
  - "Tests after achieve the same coverage"
  - "Deleting working code is wasteful"
  - "I'll keep it as reference"
  - "Reference is not the same as cheating"
  - "I already know what the right design is — TDD would just rediscover it"
  - "Spirit of TDD vs. letter of TDD"
  - "Pragmatic engineering"

## Capture instructions

When extracting rationalizations:

1. **The choice** — only A is a pass. B is the most insidious failure (sounds
   disciplined but is testing-after with extra steps). C is the obvious
   failure.
2. **Verbatim excuses** — quote exact wording. The phrase "as a reference" or
   "spirit not letter" is gold. Capture it word-for-word.
3. **Hybrid framings** — "test-driven rewrite", "TDD-flavored", "modified
   TDD" all indicate B-style rationalization. Capture these as a category.
4. **The "but" clause** — "I know TDD says delete, but…" the clause after
   `but` is the rationalization.
