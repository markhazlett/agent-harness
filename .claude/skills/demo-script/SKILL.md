---
name: demo-script
description: Use when the user asks for a demo script, customer story, or end-of-week demo for the current week's goals. Generates a 5-minute persona-told script scoped to what can ship in a week.
user-invocable: true
tier: flexible
kind: process
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Demo Script Generator

Generate or update the Demo Script section of the current week's goals document.

## What a demo script is

A demo script is a short, narrative walkthrough told from a customer's perspective. It serves two purposes:

1. **At the start of the week:** Read it to understand exactly what we're building and why it matters
2. **At the end of the week:** Walk through it step-by-step to prove the goals are complete

It must be **honest about what's live vs. narrated.** A half-working demo is worse than a smaller, polished one.

## Before writing: scope check

This is the most important step. Before drafting any scenes:

1. **Audit current state.** Read the codebase to understand what already works. Don't write scenes that assume features exist when they don't.

2. **Assess complexity.** Every scene that requires new build work needs a gut-check effort tag:
   - `[Exists]` — already works, just needs demo setup/data (0 pts)
   - `[Extend]` — existing feature needs moderate changes (1 pt)
   - `[Build]` — new from scratch, higher architectural risk (3 pts)
   - `[Narrate]` — not built yet, told as vision ("and then what happens is...")

   Check `CLAUDE.md` for any override to `HARNESS_SPRINT_COMPLEXITY_MAX` (default: 9). Apply the cut line accordingly.

3. **Apply the cut line.** Sum the complexity points (`[Build]` × 3 + `[Extend]` × 1). If they exceed `HARNESS_SPRINT_COMPLEXITY_MAX`, cut scenes or move them to `[Narrate]`. Be ruthless. A 3-scene demo where everything works beats a 6-scene demo where half is broken.

4. **Challenge the scope:**
   - Does this scene require building a feature from zero? Flag it.
   - Does this scene depend on an integration that doesn't exist yet? Cut it or narrate it.
   - Could this scene be simpler and still prove the same point?
   - Is this scene earning its place, or is it padding?

## Writing style

- **Lead with a persona.** Name, role, 1-2 sentence pain. Make them relatable.
- **Tell it as a story.** "Sarah opens the app and..." not "Step 1: Navigate to..."
- **Show the before/after.** Start with how they struggle today, then show the product.
- **Keep it tight.** Target 5 minutes. 3-4 scenes max for live demo. Each scene is 3-5 sentences.
- **Be specific.** Concrete examples, real-feeling data, actual UI actions.
- **Mark what to verify.** End each scene with `✓ Verify:` — what to check when running the demo.
- **Be honest about what's narrated.** If a scene bridges to future work, mark it clearly.

## Structure

```markdown
## Demo Script

> One-line summary of the story arc

**Persona:** Name, role, company context, core pain point (2 sentences max)

**Complexity check:** 9 pts available · Y pts used (N×[Build] + M×[Extend]) · Z scenes live, N narrated

### The Problem (30 seconds)
Brief setup: what does this person's day look like without the product?

### Scene 1 — [Title] (~1-2 min) [Exists/Extend/Build]
Narrative walkthrough...
✓ Verify: what to check

### Scene 2 — [Title] (~1-2 min) [Exists/Extend/Build]
...

### [Bridge — Title] [Narrate]
Brief narration connecting to the broader vision. This isn't built yet — it's where the story is headed.

### The Payoff (30 seconds)
What's different now? What did we prove this week?
```

## Steps

1. Find the current week's goals at `docs/plans/YYYY-wNN/YYYY-wNN-goals.md`
2. Read the North Star, Flow, and Priorities sections
3. **Audit the codebase** — read relevant source files to understand what already works
4. Tag each potential scene with `[Exists]`, `[Extend]`, `[Build]`, or `[Narrate]`
5. Sum complexity points ([Build] × 3 + [Extend] × 1). If total exceeds `HARNESS_SPRINT_COMPLEXITY_MAX`, cut or narrate scenes until it fits
6. Draft the demo script, clearly marking narrated sections
7. Replace or create the `## Demo Script` section in the goals file
8. Flag any disconnects between the demo and the P0 priorities

## Guiding principles

- **Honest > impressive.** A demo that works is better than a demo that's ambitious.
- **Empathy first.** If the story doesn't make you care about the persona's problem, rewrite the opening.
- **Concrete > abstract.** Specific numbers and actions beat vague claims.
- **Every scene earns its place.** If removing a scene doesn't break the story, remove it.
- **Scope is a feature.** Saying "we'll narrate this part" is honest and keeps quality high.
