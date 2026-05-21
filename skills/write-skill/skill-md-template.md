# SKILL.md Structure Template (Harness)

Annotated reference for every skill in this harness. The skeleton differs by `tier`; this file covers all three.

## Universal: frontmatter + update-check

Every skill (`rigid` | `flexible` | `util`) starts with:

```markdown
---
name: <skill-name>                 # MUST match folder name
description: Use when <triggers>   # triggers only, never a workflow summary
user-invocable: true | false
tier: rigid | flexible | util
kind: process | implementation | verification    # omit only when tier: util
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# <Skill Title>
```

### Description rules

- Start with `Use when`.
- Lists concrete triggers: user phrases, slash commands, situational symptoms.
- Third-person (the description is injected into the system prompt).
- **Never** summarizes the workflow. Anthropic-confirmed failure mode: when descriptions summarize the workflow, the model follows the summary and skips the body.
- Max 1024 chars total frontmatter.

Examples:

```yaml
# ❌ "Aggregates lint, tests, security, db, and e2e checks into a single go/no-go verdict."
#    (workflow / feature list)
description: Use when the user says "/pre-deploy", "ready to ship", or before pushing to production.

# ❌ "Writes failing tests, runs them, implements, refactors."
#    (workflow summary)
description: Use when implementing any feature or bugfix, before writing implementation code.
```

## Rigid skill body

```markdown
> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

<one-paragraph opener — what failure mode, what discipline, what artifacts>

## The Iron Law

```
<ALL-CAPS SINGLE-SENTENCE LAW>
```

<3–5 lines naming specific shortcuts the law forbids>

## <Cycle / Steps>

<numbered list, 4–8 steps, short>

## Red Flags — STOP and Start Over

- <bullet>
- ...

**All of these mean: stop. <Action — delete code / restart cycle / move back to RED>.**

## Common Rationalizations

**REQUIRED SUB-FILE:** Read `rationalizations.md` if you find yourself making excuses.

## Self-Review Checklist

- [ ] <4–8 mechanical checkboxes verifiable by re-reading the diff/output>

Cannot check all boxes? You skipped the skill. Start over.

## What this skill does NOT cover

<short scope-bound; names legitimate exemptions>

## Terminal State

<name the next allowed action; forbid alternatives>
```

### Sibling files for rigid skills

- `rationalizations.md` — verbatim-excuse-to-reality table, every row linked to a `docs/skill-baselines/` source.
- `red-flags.md` — expanded list when inline outgrows ~12 bullets.
- `<topic>.md` — heavy reference (e.g., `mock-patterns.md` for `/tdd`).

Cross-reference siblings with `**REQUIRED SUB-FILE:** Read foo.md` — never `@foo.md` (force-loads context).

## Flexible skill body

Shorter; no Iron Law, no rationalization table. Often:

```markdown
<one-paragraph opener>

## When this fires
<triggers + scope>

## Workflow
<numbered steps with judgment latitude>

## When NOT to use
<scope-bound>
```

Body length: aim < 500 words; can stretch to 800–1000 for complex orchestrators (`/build-plan`, `/deep-plan`).

## Util skill body

Often a single section:

```markdown
<one-line description>

## Steps
<3–6 short steps, often a single command>
```

Body length: aim < 200 words.

## Token budgets

| Skill class | Target | Ceiling |
|-------------|--------|---------|
| getting-started workflows | <150 words | 200 |
| frequently-loaded (process priority) | <200 words | 400 |
| rigid discipline skills | <500 words | 700 |
| flexible orchestrators | <500 words | 1000 |
| util commands | <200 words | 400 |

Measure with `wc -w SKILL.md`. Overflow → siblings.

## Anti-patterns (do not ship)

- **Multi-language examples.** One excellent example beats five mediocre ones.
- **Narrative storytelling.** "In session 2025-10-03, we found..." — too specific, not reusable.
- **Code inside flowcharts.** Flowcharts are for non-obvious decision branches; code goes in markdown blocks.
- **Generic flowchart labels** (`step1`, `helper2`). Labels are the documentation.
- **`@`-loading siblings.** Force-loads context. Use `**REQUIRED SUB-FILE:**`.
- **Imagined rationalizations.** Rows without a `docs/skill-baselines/` source.
- **Description summarizes workflow.** Triggers only.

## Naming

- Folder name = frontmatter `name`. Letters, numbers, hyphens only.
- Verb-first or gerund: `write-skill`, `ship`, `debug`, `e2e-verify`, `lg-design`.
- Avoid `-helper`, `-utils`, `-tools` suffixes — they describe shape, not action.

## Cross-references to other skills

```markdown
**REQUIRED SUB-SKILL:** Use `/tdd` before implementing the fix.
**REQUIRED BACKGROUND:** You MUST understand `/skill-baseline` before this skill.
```

Never use bare paths (`see skills/tdd/SKILL.md`) or `@`-syntax. The slash-command form is the load instruction.
