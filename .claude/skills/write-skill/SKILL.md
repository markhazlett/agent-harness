---
name: write-skill
description: Use when authoring a new skill, editing an existing skill, upgrading a flexible skill to rigid, or the user says "/write-skill", "create a skill", "new skill for X", or "make this a skill". Fires before any new `SKILL.md` is committed.
user-invocable: true
tier: rigid
kind: process
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Write Skill

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

**Writing a skill IS test-driven development applied to process documentation.** If you didn't watch a subagent fail without the skill, you don't know what the skill is for. Merges superpowers' `writing-skills` with `.claude/docs/harness-principles.md` and `.claude/skills/CONVENTIONS.md`. **Violating the letter is violating the spirit.**

## The Iron Law

```
NO RIGID SKILL SHIPS WITHOUT (1) A NAMED FAILURE MODE FROM A SUBAGENT
BASELINE, (2) A RATIONALIZATION TABLE QUOTING VERBATIM EXCUSES, (3) A
TRIGGERS-ONLY DESCRIPTION, AND (4) A DECLARED TERMINAL STATE.
```

Flexible and util skills are exempt from (1) and (2), but **never** from (3). Wrote the body before baselining? Delete the rationalization table. Don't keep imagined rows "as reference." (§3, §11.)

## The cycle

1. **Decide.** Is this a skill at all? Most candidates belong in `CLAUDE.md` or a hook. See `checklist.md`.
2. **RED.** Run `/skill-baseline --skill <name> --scenario <slug>` against a subagent without the target skill loaded. Capture verbatim transcript and excuses.
3. **GREEN.** Copy `_template-rigid/TEMPLATE.md` (rigid) or write minimal frontmatter+body (flexible/util). Counter the *specific* baseline rationalizations. Verbatim excuses → `rationalizations.md`. Re-run *with* the skill; subagent should cite the section that prevented the failure.
4. **REFACTOR.** New rationalization under stacked pressure (time + authority + sunk cost + exhaustion)? Add a row. Iterate until compliance holds.
5. **Ship.** Bump `VERSION` (minor for new skill, patch for edits), commit, push, open a **draft** PR.

Full structure template + word budgets: `skill-md-template.md`. Full checklist: `checklist.md`.

## Red Flags — STOP and Start Over

- Description summarizes workflow instead of triggers (model follows the summary, skips the body).
- Rationalization rows from imagination — no `docs/skill-baselines/` source link.
- Body > 700 words with content that belongs in a sibling.
- Multi-language examples. One excellent example beats five mediocre ones.
- `@`-loading a sibling (force-loads context) — use `**REQUIRED SUB-FILE:** Read foo.md`.
- Missing `<update-check>` block, missing override pointer, frontmatter omits `tier` or `kind`.
- "I'll baseline it later." "Just a small edit, no baseline needed."

**All of these mean: stop. Move the work back into RED.** Expanded list: `red-flags.md`.

## Common Rationalizations

**REQUIRED SUB-FILE:** Read `rationalizations.md` if you find yourself making excuses. The verbatim-excuse-to-reality table is seeded from superpowers' writing-skills baseline and flagged for re-baseline in this harness.

## Self-Review Checklist

Before committing:

- [ ] Folder name == frontmatter `name`. `bin/test-frontmatter` passes.
- [ ] Description starts with `Use when`, lists concrete triggers, contains **zero** workflow summary.
- [ ] `<update-check>` block present immediately after frontmatter.
- [ ] If rigid: Iron Law, Red Flags, `rationalizations.md`, Self-Review Checklist, Terminal State all present. Every rationalization row traces to a file under `docs/skill-baselines/`.
- [ ] Body word count: `wc -w SKILL.md` < 500 (target) / < 700 (hard ceiling). Overflow → siblings.
- [ ] One excellent example, not five mediocre ones.
- [ ] `VERSION` bumped.

Cannot check all boxes? You skipped this skill. Restart from the top.

## What this skill does NOT cover

Hooks (`.claude/hooks/` — enforcement, different contract), commands (`.claude/commands/` — thin wrappers), memory entries (`docs/learnings/` — see `CLAUDE.md § Learnings`), and documentation-only edits (no baseline; still bump VERSION patch if user-visible).

## Terminal State

Terminal state is **a draft PR to `agent-harness` containing the new/edited skill, baseline transcripts under `docs/skill-baselines/`, and a `VERSION` bump**. Do NOT invoke `/ship` — the draft is on purpose. Do NOT use the new skill on real work until the user reviews the rationalization table and the PR merges.
