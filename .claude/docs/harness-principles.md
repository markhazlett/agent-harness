# Principles for Building LLM Harnesses

Notes extracted from operating *inside* a Claude Code + superpowers-style
harness. The vantage point matters: these describe forces that act on the
agent from the inside, not just guesses from the outside. Where a principle
is specific to a security harness (vs. a general agent harness), it's
tagged **[SECURITY]**.

The framing throughout: a harness is a **behavioral control system for a
smart but inconsistent agent**. Every principle below is a lever that
compresses variance — making the agent more reliably good without making
it dumber.

---

## Part I — The Mental Model

### 1. Harnesses fight predictable failure modes, not unpredictable mistakes

LLM agents fail in patterned ways: shortcut-taking, claiming success without
verification, skipping steps under time pressure, rationalizing away discipline,
hallucinating files/symbols that don't exist, drifting from prior preferences,
narrating instead of acting, or acting instead of investigating. A great harness
names each failure mode and builds a specific counter for it. A mediocre
harness writes one giant system prompt and hopes.

**Apply this:** Before adding rules, list the *concrete failure modes* you've
seen the agent make in your domain. Build the harness as a set of named
counters, each traceable to a specific failure. If a rule doesn't map to an
observed failure, it's clutter.

### 2. Forcing functions beat guidance

The harness everywhere prefers structures the agent *can't easily skip* over
text the agent *might read*. Examples:

- The `Skill` tool injects content; you can't fake "I read it" the way you can
  pretend to have considered a system-prompt section.
- `TodoWrite` makes progress visible to the user — visible state is enforced
  state.
- Plan mode is a separate mode of the harness, not a polite request to plan.
- The "1% rule" in `using-superpowers`: "if there is even a 1% chance a skill
  might apply… you ABSOLUTELY MUST invoke." This is asymmetric — false
  positives are cheap, false negatives expensive.

**Apply this:** Where you have a behavior you really need, ask "what's the
forcing function?" Tooling > prompting. A required tool call > a stern
sentence.

### 3. The agent will rationalize. Pre-empt the rationalizations.

The most clever pattern in superpowers is the **Rationalization Table**.
Every rigid skill (TDD, verification-before-completion, systematic-debugging)
contains a two-column table:

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "TDD is dogmatic, being pragmatic" | TDD IS pragmatic. |

These tables are *built from real baseline behavior* (see Part III, §11).
They're not guessed — they're harvested. Reading one feels like the harness
already met the version of me that's about to cheat and left a note.

**Apply this:** Run an unsupervised baseline. Capture the agent's verbatim
excuses. Each excuse becomes a row. Don't paraphrase — the *exact* phrasing
of the rationalization is what triggers recognition.

### 4. "Violating the letter is violating the spirit"

Several skills include this exact line. It's there because LLMs are very good
at "I'm following the spirit, not the ritual" arguments. The harness explicitly
forbids that move. Rigid skills tell you they're rigid: TDD is rigid;
brainstorming has a `<HARD-GATE>`; verification-before-completion has an
"Iron Law."

**Apply this:** Distinguish rigid skills from flexible ones explicitly. Rigid
skills should *say so* and refuse adaptation. Flexible skills should signal
that judgment is welcome.

---

## Part II — Architectural Principles

### 5. Composable layered context, not one monolithic prompt

The effective system prompt at any moment is composed from:

1. The base CLI system prompt (identity, environment, tone).
2. A `<system-reminder>` listing currently available skills.
3. A `<system-reminder>` listing deferred tools (and how to fetch their schemas).
4. Project context (CLAUDE.md contents, current date, user email).
5. MCP server instructions.
6. The currently-loaded skill body (when a Skill tool call returns).
7. User-level memory entries (`MEMORY.md` index, loaded entries).

This separation matters because each layer has different volatility and
authority. CLAUDE.md is repo-stable; skills are versioned; MEMORY is
user-personal; system reminders are per-turn.

**Apply this:** Don't pile everything into one prompt. Identify volatility
tiers (per-turn / per-conversation / per-repo / per-user) and assemble the
prompt at runtime. Each tier becomes independently editable, cacheable, and
reasonable.

### 6. Three-tier instruction hierarchy with user supremacy

`using-superpowers` is explicit:

```
1. User explicit (CLAUDE.md, GEMINI.md, AGENTS.md, direct requests) — highest
2. Superpowers skills — override default system behavior
3. Default system prompt — lowest
```

This solves the most common harness failure: the system fights the user.
"If CLAUDE.md says don't use TDD and the skill says always TDD, follow the
user." Without this, harnesses become annoying. With this, they're suggestions
that the user can override deliberately.

**Apply this:** Make the precedence chain explicit and *publish it inside the
harness itself*. Then make sure your highest-tier mechanism (a CLAUDE.md
analog) is easy for users to write.

### 7. Skills are loadable files, not memorized rules

The `Skill` tool *injects content into context on demand*. Three consequences:

- **Discoverability via frontmatter.** Each skill has `name` + `description`.
  The description is *only triggers* — never a workflow summary. (See
  `writing-skills` SKILL.md for why: when descriptions summarize the workflow,
  the agent follows the summary instead of reading the body.)
- **Versionability.** Skills are files in a plugin cache, versioned. The agent
  always reads current.
- **Honesty.** "I remember this skill" is a red flag in the harness — skills
  evolve, read the current version. You can't fake a Skill tool call the way
  you can fake "I'm following best practices."

**Apply this:** Don't bake your harness's behavior knowledge into the system
prompt. Make it a file system the agent has to load from. The act of loading
is the act of complying.

### 8. Tool descriptions teach behavior

The Bash tool description doesn't just explain what Bash does — it teaches:
"avoid `cat`/`head`/`tail`, use Read"; "never `cd <current-directory>` before
git"; "don't use long leading sleep commands"; "use the Monitor tool for
polling." The Read tool description teaches: "do NOT re-read a file you just
edited — Edit/Write would have errored." `ScheduleWakeup` teaches the
prompt-cache TTL ("don't pick 300s. It's the worst-of-both…").

These are *behavioral patches injected into tool documentation*. The agent
sees them every time it considers using the tool, which is exactly when the
guidance is relevant.

**Apply this:** Tool docs are prompt real estate. Put behavior near the tool
that triggers it. A rule about cache windows belongs in the scheduling tool's
docs, not in some general "best practices" section the agent has long since
forgotten.

---

## Part III — Skill Design Principles

### 9. Each skill has an Iron Law

Rigid skills (TDD, verification-before-completion, systematic-debugging,
brainstorming) all begin with one stark rule, often called "The Iron Law":

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

Capital letters, single sentence, near the top. This gives the rest of the
skill an anchor — every red flag, every rationalization-table row points back
to this one rule. There's no question what the skill is *for*.

**Apply this:** Each skill should have one sentence the agent could repeat
under stress. If a skill has five core principles, the agent will remember
zero. Pick one.

### 10. Frontmatter description = triggers, not summary

From `writing-skills`:

> Testing revealed that when a description summarizes the skill's workflow,
> Claude may follow the description instead of reading the full skill content.
> A description saying "code review between tasks" caused Claude to do ONE
> review, even though the skill's flowchart clearly showed TWO reviews.

This is a deep observation: **the description is bait, not summary**. Its job
is to make the agent load the body. If the description itself contains a
shortcut, the body becomes vestigial.

```yaml
# ❌ Summarizes workflow — agent follows description, skips body
description: Use when executing plans - dispatches subagent per task with code review between tasks

# ✅ Triggering conditions only
description: Use when executing implementation plans with independent tasks in the current session
```

**Apply this:** Audit your skill descriptions. If they describe *what the
skill does*, rewrite to describe *when to use it*. The body is what does
the work.

### 11. Skills are TDD'd

`writing-skills` asserts: "Writing skills IS Test-Driven Development applied
to process documentation." The cycle:

- **RED** — Run a pressure scenario with a *subagent* without the skill.
  Document exact rationalizations verbatim.
- **GREEN** — Write the minimal skill that addresses those specific
  rationalizations.
- **REFACTOR** — Find new rationalizations under pressure, plug them.

Pressure stacking matters: time pressure + sunk cost + exhaustion + authority.
Real-world failures occur under combined pressure, not single pressure.

**Apply this:** Don't write skills from your imagination. Run a subagent that
should follow the rule, watch it cheat, write the rule against the actual
cheating. This is the difference between a harness that feels prescient and
one that feels naive.

### 12. One excellent example beats five mediocre ones

`writing-skills` is explicit about not implementing the same example in five
languages. One complete, runnable, real example with comments explaining *why*.
The agent is good at porting; multi-language examples dilute quality and
multiply maintenance.

**Apply this:** Resist the urge to "cover all stacks." Pick the language
your harness's audience uses most and go deep there.

### 13. Token efficiency is critical for frequently-loaded skills

`writing-skills` targets:
- getting-started skills: <150 words each
- frequently-loaded skills: <200 words total
- other skills: <500 words

Frequently-loaded skills cost tokens *every conversation*. The harness pushes
heavy reference into separate files (`anthropic-best-practices.md`,
`graphviz-conventions.dot`, `testing-skills-with-subagents.md`) loaded only
when the agent dives in.

**Apply this:** Measure with `wc -w`. Move reference into separate files.
Cross-reference with `**REQUIRED SUB-SKILL:** Use foo:bar` rather than
`@`-loading (which force-loads context whether needed or not).

### 14. Decision points get small flowcharts; everything else gets prose

`writing-skills` restricts flowcharts to:

- Non-obvious decision points
- Process loops where you might stop too early
- "When to use A vs B" decisions

Reference material → tables. Linear instructions → numbered lists. Code →
markdown blocks. **Never** code inside flowcharts. The graphviz `dot`
notation in skills is purposeful: doublecircle for terminal/required states,
diamond for decisions, box for actions. Style is semantic.

**Apply this:** Don't put ASCII diagrams everywhere. Use them only where
the agent could plausibly stop too early or take the wrong branch.

### 15. Process skills run before implementation skills

When multiple skills could apply, the harness sets order:

1. Process skills first (brainstorming, debugging) — *how* to approach.
2. Implementation skills second (frontend-design, mcp-builder) — *what* to do.

"Let's build X" → brainstorming first. "Fix this bug" → debugging first.
This is structurally important: implementation skills assume a designed/
investigated context. Skipping the process skill makes implementation
guess.

**Apply this:** When you write a new skill, declare its priority class. If
two skills compete, the harness needs a deterministic order.

### 16. Hard gates with terminal states

`brainstorming` ends with a **HARD-GATE**: "Do NOT invoke any implementation
skill, write any code, scaffold any project, or take any implementation action
until you have presented a design and the user has approved it." It also
declares its terminal state: "The terminal state is invoking writing-plans.
Do NOT invoke frontend-design, mcp-builder, or any other implementation
skill."

This pattern matters because skills can otherwise daisy-chain in unintended
ways. The agent might brainstorm → call frontend-design → start coding,
skipping the plan/approve step. The terminal-state declaration shuts that
down.

**Apply this:** When a skill needs to hand off to a specific next skill,
*name* the next skill and *forbid* the alternatives.

---

## Part IV — Memory System Principles

### 17. Typed memory, not freeform notes

The `auto memory` system distinguishes four types: **user**, **feedback**,
**project**, **reference**. Each type has different rules for when to write
and how to use. This typing prevents the most common memory failure: a junk
drawer where everything goes in and nothing comes out useful.

| Type | Stable across? | When to use |
|------|----------------|-------------|
| user | Whole user lifetime | Tailor explanations to expertise |
| feedback | Cross-conversation | Avoid repeating corrections |
| project | Project lifetime, decays fast | Inform suggestions about ongoing context |
| reference | Pointers to external systems | Know where to look |

**Apply this:** Memory typing forces honesty about persistence. "This is a
user fact" vs. "this is a project fact" vs. "this expires next month" should
be a structural decision, not a tag.

### 18. Save *why* and *how to apply*, not just the rule

Feedback and project memories use a structure:

```
{rule or fact}
**Why:** {reason — past incident, deadline, stakeholder ask}
**How to apply:** {when this guidance kicks in}
```

The "why" is what enables judgment in edge cases. A rule without a reason
either gets followed mechanically (failing on nuance) or ignored when the
agent thinks it doesn't apply (failing on principle). The reason lets the
agent decide.

**Apply this:** Refuse to save memories that are pure rules. Force a "why"
field even if it's short. If the user can't articulate why, the memory
probably isn't worth saving.

### 19. Save confirmations as well as corrections

> Record from failure AND success: if you only save corrections, you will
> avoid past mistakes but drift away from approaches the user has already
> validated, and may grow overly cautious.

This is non-obvious. Most memory systems train on negative signal only — fix
my mistakes. But the agent will then over-correct, becoming hesitant, asking
more questions, choosing safer-but-worse approaches. Saving "yes, that
unusual choice was right, here's why" is the counter.

**Apply this:** Build a habit (in the harness, not the user) of noticing
quiet validations: "yeah that worked," accepting an unusual choice without
pushback, "perfect, keep doing that." Save the validated judgment, not just
the correction.

### 20. Explicit anti-list of what NOT to save

The memory section enumerates anti-categories:

- Code patterns / conventions / file paths (read the project)
- Git history (use git log)
- Debugging fix recipes (the fix is in the code)
- CLAUDE.md content
- Ephemeral task state

> These exclusions apply *even when the user explicitly asks to save*. If
> they ask to save a PR list or activity summary, ask what was *surprising*
> or *non-obvious* about it — that is the part worth keeping.

The anti-list does as much work as the inclusion criteria. Without it,
memory accumulates noise that crowds out signal.

**Apply this:** For any persistence layer (memory, plans, todos), publish
both an inclusion criterion and an exclusion criterion. Make the agent
defend a save against the exclusion list.

### 21. Index file vs content files

`MEMORY.md` is an index. Each entry is one line under ~150 chars:
`- [Title](file.md) — one-line hook`. Memory bodies live in their own files.

Why: the index is *always loaded* into context (truncated after 200 lines).
Bodies are loaded *on demand*. This makes memory cheap to scan and expensive
only when used.

**Apply this:** Distinguish always-loaded scan-layer from on-demand
content-layer. The scan layer must stay tiny. The content layer can be
generous.

### 22. Verify before recommending from memory

> A memory that names a specific function, file, or flag is a claim that it
> existed *when the memory was written*. It may have been renamed, removed,
> or never merged. Before recommending it: grep, check the file exists.
> "The memory says X exists" is not the same as "X exists now."

Memory rot is a real failure mode. A harness that recommends from memory
without verification is worse than one without memory — false confidence is
costlier than no confidence.

**Apply this:** Memory items naming concrete identifiers (paths, functions,
flags) carry an implicit verification cost. Make verification an explicit
step in the memory recall flow, not an afterthought.

### 23. Memory ≠ plans ≠ todos

The auto-memory section ends with a clarification: plans persist
in-conversation alignment with the user; todos persist in-conversation
progress; memory persists *across* conversations. Three different layers,
three different lifetimes, no overlap.

**Apply this:** Be explicit about the lifetime of each persistence
mechanism. If your harness has only one (e.g., only memory), you'll
contaminate it with ephemeral state.

---

## Part V — Tool Design Principles

### 24. Tools as forcing functions for behavior

Several harness tools exist primarily to *shape behavior*, not to provide
raw capability:

- `TodoWrite` — visible progress; you can mentally track tasks but the user
  can't see that.
- `EnterPlanMode` / `ExitPlanMode` — separate write-prevented mode for
  planning.
- `Skill` — content injection that can't be faked.
- `EnterWorktree` / `ExitWorktree` — filesystem isolation for parallel work.
- `ScheduleWakeup` — explicit pacing for /loop, with prompt-cache awareness
  embedded in the description.
- `Monitor` — replaces sleep-loops with event streaming.

Each could be implemented as "agent, please do X." Implementing as a tool
both makes the behavior more reliable (it's enforced by the runtime) and
makes it observable to the user.

**Apply this:** When a behavior matters and the agent reliably skips it,
upgrade it from prose to tool.

### 25. Tools include "do not use this for" guidance

The Bash description forbids `cat`/`head`/`tail`/`sed`/`echo` for tasks where
dedicated tools exist. The Agent tool says "If the target is already known,
use the direct tool: Read for a known path, grep via Bash for a specific
symbol. Reserve this tool for open-ended questions." Read says "Do NOT
re-read a file you just edited."

Anti-guidance reduces tool misuse much more than positive guidance does.
Telling the agent what *not* to do is almost always cheaper than enumerating
correct uses.

**Apply this:** Every tool doc should include a "skip / don't use for"
section. Concrete cases > abstract principles.

### 26. Parallelism is explicit and rewarded

The system prompt explicitly says: "If you intend to call multiple tools and
there are no dependencies between them, make all independent tool calls in
parallel." The Agent tool: "When you launch multiple agents for independent
work, send them in a single message with multiple tool uses so they run
concurrently."

LLMs default to sequential because that's how their token stream feels.
Parallelism is a behavior that requires explicit prompting and tool support
(multiple tool_use blocks per assistant message).

**Apply this:** If your tool calls are independent, you need (a) protocol
support for parallel calls, and (b) explicit prompting to use it. Without
both, you'll get serialization.

### 27. Subagents come with clear caveats

The Agent tool description includes:

> Trust but verify: an agent's summary describes what it intended to do,
> not necessarily what it did. When an agent writes or edits code, check the
> actual changes before reporting the work as done.

> Never delegate understanding. Don't write "based on your findings, fix the
> bug" or "based on the research, implement it." Those phrases push synthesis
> onto the agent instead of doing it yourself.

These two together prevent the most common subagent failures: blindly trusting
summaries, and using subagents as a substitute for thinking. The harness
treats subagents as *workers*, not *delegates of judgment*.

**Apply this:** Subagent tooling should explicitly remind the parent agent
to verify outputs. And it should discourage prompts of the form "based on
your research, implement it" — those mean the parent isn't carrying the
synthesis.

### 28. Long-running processes get observability primitives

The harness has `run_in_background` on Bash and Agent, plus `Monitor` for
streaming output, plus `ScheduleWakeup` for self-pacing. Together these
prevent the worst pattern: a sleep loop that burns prompt cache and tokens
to do nothing.

The `ScheduleWakeup` doc embeds the actual cost reasoning:

> The Anthropic prompt cache has a 5-minute TTL. Sleeping past 300 seconds
> means the next wake-up reads your full conversation context uncached.
> **Don't pick 300s.** It's the worst-of-both.

**Apply this:** Long-running operations need first-class support: background
launch, event streaming, scheduled resume. And the cost reasoning behind
those choices should be in the tool docs where the agent will see it.

---

## Part VI — Multi-Stage Workflow Principles

### 29. Brainstorm → Plan → Execute → Verify

Each phase is a separate skill, with explicit handoff. The harness refuses
to skip phases:

- **brainstorming** has a `<HARD-GATE>` against implementation until design
  is approved. Terminal state: invoke writing-plans.
- **writing-plans** produces a checkbox-syntax markdown file. Terminal
  state: handoff to executing-plans or subagent-driven-development.
- **executing-plans** / **subagent-driven-development** runs tasks, with
  review checkpoints between.
- **verification-before-completion** runs at the end of each task.

Each phase persists an artifact: a spec doc, a plan doc, a series of
commits, a verification log. The user can inspect any artifact between
phases.

**Apply this:** Don't try to do design + planning + implementation + review
in one prompt. Stage them, with named artifacts at each transition. The
artifacts are the reviewability of the system.

### 30. "Bite-sized tasks" that are mechanically executable

`writing-plans` is explicit:

> Each step is one action (2-5 minutes):
> - "Write the failing test" - step
> - "Run it to make sure it fails" - step
> - "Implement the minimal code to make the test pass" - step
> - "Run the tests and make sure they pass" - step
> - "Commit" - step

And: "No Placeholders." No "TBD," "implement later," "add appropriate error
handling." Every step contains the actual content an engineer needs.

**Apply this:** A plan with placeholders is a plan that won't execute. The
test for plan quality is "could this be handed to a junior engineer who
has never seen the codebase?" If no, it's not done.

### 31. Self-review with fresh eyes, not self-validation

Both `brainstorming` and `writing-plans` include a **Spec Self-Review** /
**Self-Review** step run by the same agent that wrote the doc. Specific
checks:

- Placeholder scan
- Internal consistency
- Scope check
- Type/name consistency across tasks
- Ambiguity check

These are mechanical — not a vague "look it over." They catch the specific
failure modes of the agent that wrote the doc.

**Apply this:** Self-review steps must be checklist-based, not vibe-based.
"Skim the doc once" is not self-review.

### 32. User review gates between phases

Even after self-review, brainstorming asks the user to review the spec
*before* writing the plan. Plan handoff offers the user a choice between
inline and subagent-driven execution. These aren't decorative — they're
forced consent boundaries.

**Apply this:** Where the agent is about to invest significant compute on
the user's behalf, insert a confirmation gate. The cost of a delayed
"continue" is much less than the cost of unwinding wrong work.

### 33. Verification is its own skill

`verification-before-completion` exists because *claiming success without
running the verification command* is the most common LLM failure on coding
tasks. The skill includes:

- Iron Law: "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE"
- "Common Failures" table mapping claim → required-evidence → not-sufficient
- Red flags including: using "should/probably/seems to," expressing
  satisfaction, trusting agent reports
- Rationalization table

The skill applies "to exact phrases AND paraphrases AND implications of
success."

**Apply this:** Build verification as a discrete, named gate. Make it
trigger on *any* language implying completion, not just on explicit "done"
claims. Pre-empt the rationalizations ("just this once," "tired and want
work over").

### 34. Debugging is staged, not improvised

`systematic-debugging` defines four phases that *must* run in order:

1. Root cause investigation (read errors, reproduce, check changes, gather
   evidence at component boundaries)
2. Pattern analysis (find working examples, identify differences)
3. Hypothesis and minimal testing (one variable at a time)
4. Implementation (failing test, single fix, verify)

After 3 failed fixes: stop and question the architecture. This counts
attempts and forces escalation.

**Apply this:** Debugging is the failure mode where agents are most likely
to thrash. Phase-staging + an explicit attempt counter + an architectural
escalation rule are the structural counters. Random fixes are the
unstructured failure case.

---

## Part VII — Subagent and Context Management

### 35. Subagent prompts must be self-contained

The Agent tool description warns: "the agent has not seen this conversation,
doesn't know what you've tried, doesn't understand why this task matters…
Brief the agent like a smart colleague who just walked into the room." Then:
"Terse command-style prompts produce shallow, generic work."

This forces the parent agent to *articulate* the context, which is itself
useful — it surfaces gaps in the parent's own understanding.

**Apply this:** Subagent dispatch should require a context-rich prompt by
convention. If the prompt is one line, the parent didn't carry the
synthesis (see §27).

### 36. Subagent isolation prevents context contamination

Subagents run with their own context window, often with restricted tool
access (Explore is read-only; statusline-setup gets only Read+Edit). They
return one summary message. The parent's context stays clean.

This is critical for long sessions: a single search task can consume 50k
tokens of file contents that the parent doesn't need. Delegating to an
Explore subagent shrinks that to a few hundred tokens of summary.

**Apply this:** Where the work involves heavy reads with thin synthesis
(searching a codebase, reading docs), prefer subagent dispatch over
in-conversation exploration. The summarization is the value.

### 37. Worktree isolation for parallel implementation

`using-git-worktrees` exists for the case where two implementation tracks
shouldn't share a working tree. The Agent tool's `isolation: "worktree"`
parameter makes this trivial. Cleanup is automatic if no changes were
made.

**Apply this:** Filesystem isolation matters for parallel coding agents.
Without it, two agents will fight over `package.json`. With it, they get
deterministic separate worlds.

### 38. Don't sleep-poll; use event streams

The Bash doc forbids "Long leading sleep commands" and routes polling
through `Monitor`. The reasoning: sleep loops burn prompt cache and tokens
without doing useful work. Event streaming notifies on actual change.

**Apply this:** Any "wait for X" pattern in the harness should be backed
by a notification primitive, not a sleep. Document the cost reasoning
where the agent will encounter it.

---

## Part VIII — System Reminders and Re-injection

### 39. Critical context is re-injected, not "remembered"

The `<system-reminder>` blocks at session start re-state:

- Skill list (full names with descriptions, refreshed per session)
- Deferred tools available via ToolSearch
- MCP server instructions
- CLAUDE.md contents (project + workspace)
- Auto Mode flag (if active)
- Today's date

Each of these is a thing the agent could have "remembered" but would
unreliably. Re-injection guarantees presence.

The system prompt explicitly notes: "Tags contain information from the
system. They bear no direct relation to the specific tool results or user
messages in which they appear." This prevents the agent from confusing
re-injected context with conversational content.

**Apply this:** Identify the context that *must* be present every turn.
Re-inject it, don't trust the agent to retain it across compaction. Mark
it clearly as system context, not user/tool content.

### 40. Auto Mode and Plan Mode as harness states

The harness has *modes*, not just *behaviors*. Auto Mode tells the agent
"execute immediately, prefer action over planning, expect course corrections."
Plan Mode prevents writes. The mode is part of the system reminder, so the
agent always knows which mode it's in.

**Apply this:** If your harness has distinct phases of user intent (explore
vs. execute, plan vs. ship), make them explicit modes. Mode-shifting changes
behavior coherently across all skills, rather than each skill having to
re-learn what's appropriate.

### 41. Deferred tools to bound the schema budget

The deferred tools list (CronCreate, AskUserQuestion, ToolSearch, etc.)
shows tool *names* without schemas. The agent calls `ToolSearch` to fetch
the schema only for tools it intends to use. This keeps the always-loaded
tool budget small while still advertising availability.

**Apply this:** Schema is expensive. If you have 50+ tools, advertise the
list and lazy-load the schemas. The agent learns "this tool exists" without
paying for "here are all its parameters."

---

## Part IX — User Instruction Supremacy

### 42. The user can override anything

`using-superpowers` says explicitly:

> If CLAUDE.md says "don't use TDD" and a skill says "always use TDD,"
> follow the user's instructions. The user is in control.

The system prompt notes: "If you see a `<command-name>` tag in the current
conversation turn, the skill has ALREADY been loaded — follow the
instructions directly." Skills are advisors. The user is principal.

**Apply this:** Make user-supremacy a stated invariant. A user who feels
fought by the harness will turn it off. A user who feels supported by it
will write more CLAUDE.md.

### 43. Asking the user is expensive — investigate first

> Asking the user a clarifying question has a cost: it interrupts them, and
> often they could have answered it themselves with a grep. Before asking,
> spend up to a minute on read-only investigation so your question is
> specific. "I found tunnels X and Y in the config — which one?" beats
> "what tunnel?"

This converts vague questions into specific questions. The user almost
always prefers the latter. It also tends to eliminate the question entirely
when investigation reveals the answer.

**Apply this:** Build a habit (and an occasional explicit reminder) of
investigation-before-clarification. The cheapest interruption is the one
that didn't happen.

### 44. Match response weight to task weight

> A simple question gets a direct answer, not headers and sections.

The system prompt repeatedly de-emphasizes ceremony: short responses by
default, no preamble, no end-of-turn summary beyond one or two sentences,
no narration of internal deliberation, no emojis unless asked.

**Apply this:** Define a default response style and enforce it. Otherwise
the agent will pad responses to feel productive — markdown headers,
bulleted summaries, "great question!" intros. All of this is friction the
user has to scan past.

### 45. Visible state, invisible reasoning

The system prompt distinguishes:

> Don't narrate your internal deliberation. User-facing text should be
> relevant communication to the user, not a running commentary on your
> thought process.

But also:

> Before your first tool call, state in one sentence what you're about to
> do. While working, give short updates at key moments: when you find
> something, when you change direction, or when you hit a blocker.

So: announce *transitions*, not *thoughts*. The user needs to know "what's
happening now" without watching the agent think.

**Apply this:** Train the agent to announce action edges, not deliberation
interiors. "Going to read the config" — yes. "Hmm, let me think about
whether to read the config…" — no.

---

## Part X — Security-Harness-Specific Principles **[SECURITY]**

These principles apply to security tooling more than to general agents.
They're flagged so general-purpose harness builders can skip them.

### 46. **[SECURITY]** Pluggable matchers, generic core

A security tool should split detection *engine* from detection *content*.
The engine ships open and auditable; org-specific or sensitive matchers
live in a separate plugin package outside the public tree. A clean plugin
contract — a typed interface in core, a runtime registry the tool routes
through — is the seam.

This keeps the OSS surface generic while allowing org-specific detections
to live separately. It also means the OSS distribution can be audited
without leaking proprietary detection logic.

**Apply this:** A security tool should have a clean separation between
detection *engine* (generic) and detection *content* (potentially
sensitive). Plugin contracts are the seam.

### 47. **[SECURITY]** Generic AI prompts, no org context

The shipped AI prompt template should be intentionally generic. Don't add
organization-specific context inline; route it through user-controlled
config (a per-project info file, a `promptAppend` field, an env-supplied
context string).

Org-specific context flowing through user-controlled config files (rather
than the shipped prompt) prevents two failure modes: (a) leaking
org-specific phrasing into a public artifact, (b) the prompt drifting to
match one org's needs and breaking others.

**Apply this:** Prompts in shipped security tools should be stripped of
org-specific assumptions. Provide a documented escape hatch (a per-project
context file, a `promptAppend` config) for users to inject their own
context.

### 48. **[SECURITY]** Triage and revalidate as separate stages

Production security pipelines split detection into named stages — scan,
enrich, triage, revalidate — distinct from the initial scan. Detection
produces noise; triage filters; revalidate confirms. Three or four stages,
three or four confidence levels.

This addresses the central security-tooling failure: false positives. A
single-stage detector is unusable in any large codebase. A staged pipeline
lets each stage be tuned for its role (scanner: high recall; triage: high
precision filter; revalidate: verify with deeper check).

**Apply this:** Multi-stage detection. Don't conflate "find" with "judge"
with "confirm." Each stage gets its own metrics.

### 49. **[SECURITY]** Sandbox execution for untrusted analysis

Any tool that executes against arbitrary user code (security scanners,
package analyzers, build tools) should ship with a sandbox executor — a
remote sandbox service or a local container. Real-world maintenance shows
this matters in practice (e.g., bug fixes around path resolution under
sandboxing only show up because the sandbox is in active use).

For any tool that executes against arbitrary user code, sandboxing is the
difference between a useful tool and a vulnerability vector. Build it in.

**Apply this:** If your tool's job is to look at potentially malicious
inputs, sandbox the analysis. Don't rely on user trust. Don't rely on
the LLM to refuse — the LLM can be confused.

### 50. **[SECURITY]** Quota and rate-limit handling as first-class concerns

Security scanning tends to fan out heavily (every file, every commit,
every PR). Quota awareness has to be built in, not bolted on. Treat
out-of-quota states as a first-class scenario the tool handles
gracefully, not an exception that crashes the run.

**Apply this:** Build a quota/rate-limit story before you scale fan-out.
Graceful degradation > silent failure > crash > silent garbage results.

### 51. **[SECURITY]** Provenance and supply chain awareness

A security tool that doesn't have its own supply chain hygiene is a
contradiction. Sign your releases. Pin your build env. Generate
provenance metadata for the artifacts.

**Apply this:** Sign your releases. Pin your build env. Provenance the
artifacts. The defaults you ship signal the threat model you take
seriously.

### 52. **[SECURITY]** Authorization context for dual-use tools

The base system prompt for many AI assistants has language like:

> Assist with authorized security testing, defensive security, CTF
> challenges, and educational contexts. Refuse requests for destructive
> techniques, DoS attacks, mass targeting, supply chain compromise, or
> detection evasion for malicious purposes. Dual-use security tools
> require clear authorization context.

Security tools live on a dual-use line. The harness can't enforce "is
this authorized" technically, but it *can* require the user to state
context. The dual-use rule moves the responsibility — the user who
claims a CTF context owns that claim.

**Apply this:** Where the tool is dual-use, require declared context.
A scanner being run against `prod-customer-db` should ask "is this
authorized?" once, even if the answer is yes — the asking is the
audit trail.

### 53. **[SECURITY]** Detection prompts are intentionally generic

Detection / triage prompts should be written generically. They're the
prompts that see potentially sensitive findings — generic = portable,
auditable, reviewable. Specific = brittle, opinionated, leakable.

**Apply this:** When a prompt sees sensitive content, write it as if
the prompt itself might be public someday (because it might be —
through telemetry, through a leaked log, through a third-party
integration).

### 54. **[SECURITY]** Defense in depth at component boundaries

`systematic-debugging` includes a multi-layer instrumentation pattern
that doubles as a security-architecture lesson:

```
For EACH component boundary:
  - Log what data enters component
  - Log what data exits component
  - Verify environment/config propagation
  - Check state at each layer
```

For security tools, this is also where you put authentication checks,
input validation, and authorization gates. Boundaries are the security
seams, the same as they are the debugging seams.

**Apply this:** The same component-boundary discipline that makes a
system debuggable also makes it auditable. Build for both at once.

---

## Part XI — Anti-Patterns

The harness implicitly forbids each of these. Calling them out makes them
easier to see in your own builds.

### 55. The kitchen-sink system prompt

Cramming behavior into one giant system prompt makes the prompt
unreviewable, uncacheable, and unteachable. The harness's tiered approach
(base prompt + skills + memory + reminders) exists precisely to avoid this.

### 56. Behavior-by-vibe ("be helpful, be concise")

Vague directives ("be careful," "use good judgment," "follow best
practices") get ignored under pressure. Specific directives with iron laws
and rationalization tables don't.

### 57. Memory as a junk drawer

Untyped, unverified, unstructured memory becomes worse than no memory —
the agent uses stale facts confidently. Type, structure, anti-list, verify.

### 58. Tools as raw capability without guidance

Shipping a tool with just a parameter schema misses the prompt-engineering
opportunity. Tool docs are the highest-leverage prompt real estate
because they're loaded exactly when relevant.

### 59. Implicit phase boundaries

"Maybe plan, maybe code, maybe verify" produces agents that skip phases.
Explicit phases with named artifacts and hard gates produce agents that
actually plan, code, and verify.

### 60. Subagents as judgment delegates

"Based on your findings, fix the bug" is the harness's named anti-pattern.
Subagents are workers, not delegates of synthesis. The parent must hold the
mental model.

### 61. Verification as an afterthought

If verification is a sentence in the system prompt rather than a named
skill triggered by completion language, it will be skipped. Build it as
its own gate.

### 62. **[SECURITY]** Leaky prompts in shipped tools

Org-specific phrasing, internal codenames, customer references in shipped
prompts — all of these are accidents waiting to happen. Generic prompts +
documented escape hatches.

### 63. **[SECURITY]** No sandbox for untrusted input

A security scanner without a sandbox isn't a security tool — it's a
liability. Sandbox by default; surface the sandbox boundary in the API.

---

## Part XII — A Practical Checklist for Building Your Own Harness

Use this as a starting point. Each item maps to one or more sections above.

### Foundations
- [ ] Tier your context: per-turn, per-conversation, per-repo, per-user
- [ ] Document instruction precedence (user > harness > defaults)
- [ ] Provide a user-controlled override file (CLAUDE.md analog)
- [ ] Use context window as primary execution state store; minimize auxiliary state (§65)
- [ ] Route between workflows with deterministic code; reserve LLM calls for in-branch reasoning (§64)

### Skill system
- [ ] Skills are loadable files with frontmatter (`name`, `description`)
- [ ] Descriptions are *triggers only*, never workflow summaries
- [ ] Each rigid skill has a single Iron Law
- [ ] Each rigid skill has a Rationalization Table built from baseline runs
- [ ] Each rigid skill has a Red Flags list
- [ ] Skills declare process vs. implementation priority
- [ ] Skills with handoffs declare terminal states explicitly

### Memory
- [ ] Typed memory (user / feedback / project / reference)
- [ ] Why + How-to-apply structure required for non-fact memories
- [ ] Anti-list of what NOT to save, enforced even on user request
- [ ] Index file separate from content files
- [ ] Verify-before-recommend rule for memories naming concrete identifiers
- [ ] Save validations as well as corrections

### Tools
- [ ] Forcing-function tools for behaviors you can't trust prose to enforce
  (TodoWrite, Plan mode, Skill loader, Worktrees)
- [ ] "Don't use this for" guidance in every tool description
- [ ] Cost reasoning (cache windows, rate limits) embedded in tool docs
- [ ] First-class background execution + event streaming
- [ ] Explicit parallel-call protocol with prompt support

### Workflow
- [ ] Brainstorm → Plan → Execute → Verify staging
- [ ] Hard gates between phases
- [ ] Self-review checklists (mechanical, not vibe-based)
- [ ] User review gates between phases
- [ ] Verification as its own named skill with completion-language triggers
- [ ] Debugging with phases + attempt counter + architectural escalation

### Subagents
- [ ] Self-contained prompts required by convention
- [ ] "Trust but verify" baked into the subagent tool description
- [ ] Read-only / restricted-tool variants for search work
- [ ] Worktree isolation available

### System reminders
- [ ] Critical context re-injected per turn (skills, tools, modes, dates)
- [ ] Reminder tags clearly distinguished from user/tool content
- [ ] Mode flags surfaced (auto / plan / etc.)
- [ ] Lazy schemas for tools beyond a budget threshold

### **[SECURITY]** Security-tool specifics
- [ ] Generic detection core, plugin-based org content
- [ ] Generic AI prompts with documented escape hatches
- [ ] Multi-stage pipeline (scan → triage → revalidate)
- [ ] Sandbox executor for untrusted analysis
- [ ] Quota / rate-limit handling baked in
- [ ] Provenance and supply-chain hygiene
- [ ] Dual-use authorization context required
- [ ] Component-boundary instrumentation (debugging + audit)

---

## Part XIII — Field Research: Principles from External Harnesses

Principles in this section are drawn from published engineering material outside this harness. Each is cited to a primary source and evaluated against the quality bar in the preamble.

### 64. Deterministic Routing, LLM Reasoning

**Use deterministic code to route between agent states; reserve LLM calls for reasoning within bounded decision points, not for choosing which workflow to run.**

**Why it works.** LLMs are expensive and inconsistent routers: they sometimes pick the wrong branch, hallucinate options, or loop. Deterministic code for routing is fast, testable, and auditable — every branching decision is explicit code, not a token prediction. The LLM adds value *within* a branch (deciding what to say, how to handle an error, what tool to call) not *between* branches (which workflow to enter). The practical form is: classify the input first with a narrow LLM call, then route to a series of smaller, focused sub-prompts with fewer instructions and fewer available tools. The failure mode is over-prescribing branches before the workflow is understood — use LLM routing for genuinely novel situations and harden to code when a branch is well-understood.

**Observed in.**
- [humanlayer/12-factor-agents, Factor 8 "Own Your Control Flow" (GitHub, 2025)](https://github.com/humanlayer/12-factor-agents): "If you know what the workflow is, use actual control flow — classify the input, then feed it to a series of smaller, more-focused prompts with fewer instructions and fewer actions to choose from." Factor 8 describes three anti-patterns: (a) memory-based pausing with full restart, (b) restricting agents to only low-risk tasks, (c) unrestricted high-stakes access with no oversight.

**How it could apply here.** The harness currently relies on LLM trigger-matching in skill frontmatter descriptions to decide which skill to invoke. For well-understood trigger patterns (e.g., `/ship` always means run the shipping pipeline), a deterministic dispatch table would be faster and more reliable than LLM inference. LLM-based skill matching should be reserved for ambiguous or novel invocations where the trigger is genuinely unclear.

**Confidence.** High

---

### 65. Context Window as the Primary Execution State Store

**Treat the context window as the canonical record of agent execution state; infer what step you're on and what's waiting from the accumulated event history, rather than maintaining a parallel state system.**

**Why it works.** A separate state database introduces a classic consistency failure mode: the agent's model of what happened diverges from what's stored. When execution state — current step, wait conditions, retry counts — is inferred from the event history already in context, you get one source of truth that is trivially serializable, fully auditable, and naturally supports resumption from any checkpoint. Thread forking (running two branches from the same history) falls out for free. The cost appears at context overflow: very long sessions exhaust the window, at which point you need external storage for items that cannot fit (credentials, session IDs). Minimize auxiliary state to exactly that set.

**Observed in.**
- [humanlayer/12-factor-agents, Factor 5 "Unify Execution State and Business State" (GitHub, 2025)](https://github.com/humanlayer/12-factor-agents): "Execution state (current step, waiting status, etc.) is just metadata about what has happened so far." Advocates using the context window as the primary state store, with auxiliary state minimized to items that cannot feasibly enter context; enables resumption from any checkpoint and thread forking as natural side effects.

**How it could apply here.** The harness uses `MEMORY.md` for cross-conversation state and `TodoWrite` for in-conversation progress, which is consistent with this principle. A future long-running agent extension — one whose task spans multiple context windows — should apply this pattern at the session boundary: serialize the event thread, not a separate state table, as the resumption artifact.

**Confidence.** High

---

## Closing Thought

The thing that makes a great harness feel magical is not any single rule.
It's that **every common failure mode has a named counter, and every
counter is structurally enforced**, not hopefully prompted. A great harness
is built like defensive code: it assumes the agent will make mistakes and
catches each specific kind of mistake at the relevant boundary.

If you're building your own harness, the question isn't "what should the
agent do?" — that's documentation. The question is "what does the agent
actually do wrong, and what's the smallest forcing function that prevents
that specific failure?" Build the harness as a sequence of answers to that
second question. The result will feel magical for the same reason the
best harnesses do: it's not smarter, it's *less prone to specific
stupidity*.

---

## Sources Mined

Each entry records a harness that has been researched at least once. Re-mining is only warranted if a materially new primary source has appeared since the last entry date.

- **12-Factor Agents** (Dex Horthy / HumanLayer) (first mined: 2026-05-15): Twelve engineering principles for production LLM applications, derived from interviewing 100+ founders and engineers. Primary source: [github.com/humanlayer/12-factor-agents](https://github.com/humanlayer/12-factor-agents). Contributed §64 (Deterministic Routing) and §65 (Context as State Store).
- **Cognition "Don't Build Multi-Agents"** (first mined: 2026-05-15): Researched; primary source (cognition.ai/blog) returned HTTP 403 and was not fetchable. Secondary sources describe context-compression and single-agent principles consistent with existing §5 and §36. No principle added this run; retry when primary source becomes accessible.
- **Anthropic "Building Effective Agents" and "Effective Harnesses for Long-Running Agents"** (first mined: 2026-05-15): Researched; both anthropic.com/research and anthropic.com/engineering URLs returned HTTP 403. No principle added this run; retry when primary source becomes accessible.
