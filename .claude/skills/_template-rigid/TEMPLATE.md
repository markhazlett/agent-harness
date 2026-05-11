---
name: {{skill-name}}
description: Use when {{trigger phrase or condition}}
user-invocable: true
tier: rigid
kind: verification
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Run `/harness-update` to pull it in." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# {{Skill Title}}

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

{{One-paragraph description of what this skill gates and when it fires.}}

## The Iron Law

```
{{ALL-CAPS SINGLE-SENTENCE LAW}}
```

{{3-5 lines of "no exceptions" guidance. Be concrete about what "no exceptions" means in this context — name the specific shortcuts the law forbids.}}

## Cycle / Steps

{{The actual workflow. Use a numbered list, a Red-Green-Refactor diagram, or a pipeline of named gates — whichever matches the skill. Keep each step short. Sub-steps belong in sibling files if they bloat the body.}}

## Red Flags — STOP and Start Over

{{6-12 short bullets. Each is a thought or action that means: stop, restart this skill from the top. Examples: "code before test", "approving when one test failed", "saying 'just this once'". For long lists, link to a sibling `red-flags.md`.}}

**All of these mean: stop. Restart the skill from the top.**

## Common Rationalizations

**REQUIRED SUB-FILE:** Read `rationalizations.md` if you find yourself making excuses.

The full Rationalization Table — verbatim excuses paired with their reality counters — lives in `rationalizations.md`. Each row was harvested from a real subagent baseline under pressure. If you catch yourself thinking any phrase from column 1, stop and read column 2 before continuing.

## Self-Review Checklist

Before claiming this skill complete, verify each item:

- [ ] {{4-8 mechanical checkboxes specific to this skill}}
- [ ] {{Each item must be verifiable by re-reading the diff or output, not vibes}}
- [ ] {{Final item: re-state the Iron Law in one sentence}}

Cannot check all boxes? You skipped the skill. Start over.

## What this skill does NOT cover

{{Short scope-bound. Helps anti-rigidity — names what to bypass to. Examples: "/tdd does not cover throwaway prototypes — those are exempt with explicit user permission." Useful so the user can see when the skill is the wrong tool.}}
