# Expanded Red Flags — /write-skill

The core list lives in `SKILL.md`. This file is the expanded version with examples — read it when the SKILL.md bullet is too terse to act on.

## Description red flags

**Workflow summary in description.** Description tells *when* to fire, not *what* it does.

```yaml
# ❌ "dispatches subagent per task with code review between tasks"
#    Model follows the summary and does ONE review; the body specifies TWO.
description: Use when executing plans - dispatches subagent per task with code review between tasks

# ✅ Triggers only.
description: Use when executing implementation plans with independent tasks in the current session
```

Real harm: Anthropic's testing confirmed that when descriptions summarize the workflow, Claude follows the description instead of reading the body. A description saying "code review between tasks" caused Claude to do ONE review when the skill's flowchart clearly showed TWO. The body becomes vestigial.

**First-person description.** Skills are injected into the system prompt; first-person reads wrong.

```yaml
# ❌
description: I can help with async tests when they're flaky
# ✅
description: Use when tests have race conditions, timing dependencies, or pass/fail inconsistently
```

**Description mentions implementation details that aren't always true.** "Use when tests use setTimeout/sleep and are flaky" pins the trigger to one technology when the skill is really about race conditions.

## Body red flags

**Imagined rationalizations.** Rows that don't link to a `docs/skill-baselines/` source. The model recognizes its own *phrasing*, not paraphrases of its phrasing. If you wrote "Argues the change is small," the model doesn't recognize itself; if you wrote "Honestly, it's literally one line of code," it stops mid-sentence.

**Body word count > 700.** Heavy reference belongs in siblings. Frequently-loaded skills (process, in `using-superpowers`-style chains) target < 200 words; rigid discipline skills aim for < 500–700.

**Multi-language examples.** Pick the language the harness's audience uses most (TypeScript/Python in this harness) and go deep. You're good at porting; don't outsource quality to the agent that loads the skill.

**`@`-loading siblings in the body.** `@graphviz-conventions.dot` force-loads context whether needed or not. Use `**REQUIRED SUB-FILE:** Read foo.md` so the agent loads on demand.

**Code inside flowcharts.** Flowcharts are for non-obvious decision branches and process loops where the agent might stop too early. Code goes in markdown blocks. Linear instructions go in numbered lists. Reference material goes in tables.

**Flowcharts as decoration.** A flowchart with one diamond and two boxes is a sentence. Write the sentence.

**Generic flowchart labels.** `step1`, `helper2`, `pattern3` carry no semantic weight. The labels are the documentation.

## Frontmatter red flags

**Missing `<update-check>` block.** Every skill, no exceptions — even util skills. The block runs `bin/harness-update-check` and surfaces upgrade prompts to users on older copies.

**Missing override pointer under H1.** Rigid skills must have:

```markdown
> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._
```

Without this, the skill claims authority over the user. The user is principal (§42).

**`tier` or `kind` omitted (and not `util`).** `bin/test-frontmatter` will fail. `tier: rigid` without `kind` will fail.

**Folder name ≠ frontmatter `name`.** Harness loads skills by folder; mismatch breaks `/<name>` invocation. Validator catches this.

## Process red flags

**Batch-authoring multiple skills before testing any.** Anti-pattern from superpowers' "STOP: Before Moving to Next Skill" — deploying untested skills is deploying untested code. Author one, baseline it, ship its draft PR, *then* start the next.

**"I'll test if problems emerge."** Problems emerging = a user paid the cost. Test BEFORE.

**"Loading the skill during RED."** Defeats the purpose. The whole RED is "what does the model do *without* the skill telling it what to do?"

**Single-pressure pass declared bulletproof.** Real failures stack pressures. Get to 3+ stacked pressures before claiming compliance.

**Skipping the GREEN re-test.** Without it, you don't know whether the counter fires. The rationalization table is unverified.
