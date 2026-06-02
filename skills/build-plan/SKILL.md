---
name: build-plan
description: Use when the user says "/build", hands off a sprint-plan document path, or asks to execute a written plan end-to-end. Branches, implements, tests, verifies in browser, commits incrementally, and prepares the PR. Auto-fires /lg-* skills when plan steps involve LangGraph/LangChain agent work.
user-invocable: true
tier: flexible
kind: implementation
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Run `/harness-update` to pull it in." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Build

Execute a sprint plan from `docs/plans/` autonomously. Takes a plan document, reads it, implements each step, tests continuously, verifies in the browser, commits incrementally, and ships.

<input_document> #$ARGUMENTS </input_document>

## Phase 1: Read and Prepare

### 1. Read the plan completely

Load the sprint plan document. The input can be either:
- **A single-file plan** (e.g., `sprint-plans/P0.1-feat-some-feature.md`) — execute it directly
- **A sub-plan within a folder** (e.g., `sprint-plans/my-workstream/G1-first-task.md`) — also read the folder's `00-*.md` entry point for architectural context
- **A folder entry point** (e.g., `sprint-plans/my-workstream/00-architecture-overview.md`) — read the dependency graph, then propose which sub-plan(s) to execute

Understand:
- **Goal** — which weekly goals doc this serves
- **Priority items** — which P0/P1/P2 items this addresses
- **Dependencies** — any plans that must be completed first
- **Key Decisions** — architectural choices already made (don't re-decide these)
- **File Footprint** — creates/modifies/reads (this is the contract)
- **Implementation Steps** — the ordered work
- **Test Plan** — unit tests AND E2E browser verification steps
- **Done Criteria** — the checklist that defines "finished"

### 2. Check dependencies

If the plan has a `Depends on` field pointing to another plan, verify that work is already on `main`. If not, stop and tell the user.

### 3. Load context from goals

Read the weekly goals file (referenced in the plan's `Goal` field) to understand the North Star and success criteria.

### 4. Set up the branch

```bash
git checkout main && git pull
git checkout -b <branch-name>
```

Branch naming: use the plan's type and slug (`feat/my-feature`, `fix/my-bug`).

If already on a feature branch, ask: "Continue on `<branch>`, or create a new one?"

### 5. Create task list

Break the plan's Implementation Steps into tasks. Include:
- Implementation tasks (one per step)
- Test tasks from the Test Plan
- A final E2E browser verification task

### 6. Ask clarifying questions (if any)

If anything in the plan is ambiguous or contradicts what you see in the codebase, ask **now**. Not mid-implementation.

### 7. Initialize the status manifest

**Conductor status precondition (applies to all status updates below):** If `bin/conductor-status` is not executable, skip every status-update step in this skill silently. Check with `[ -x bin/conductor-status ]` at Phase 1 start.

Write the initial status file so sibling workspaces can see this work starting (skip if the precondition at Phase 1 was not met):

```bash
bin/conductor-status update \
  workspace="$(basename "$PWD")" \
  repo="$(basename "$(dirname "$(pwd)")")" \
  plan="<the-plan-path-you-read>" \
  branch="$(git symbolic-ref --short HEAD)" \
  phase=implementing \
  dev_server_port="${CONDUCTOR_PORT:-${HARNESS_DEV_PORT:-3000}}"
```

Also write the Done Criteria array. Parse each `- [ ] ...` line out of the plan's "Done Criteria" section and build a JSON array of `{item, status}` objects, then pass it as a single value:

```bash
# Example: plan has these criteria
#   - [ ] Unit tests passing
#   - [ ] E2E browser verification passing
criteria_json=$(jq -nc '[
  {"item":"Unit tests passing","status":"pending"},
  {"item":"E2E browser verification passing","status":"pending"}
]')
bin/conductor-status update done_criteria="$criteria_json"
```

One update call, one JSON string value. As criteria pass during Phases 3 and 4, re-serialize with the updated statuses and call `update done_criteria="$criteria_json"` again.

### 8. Mirror Done Criteria to Conductor Todos (best effort)

If the Conductor API exposes a Todos endpoint (check `https://docs.conductor.build/` for current API reference), POST each Done Criteria item as a todo so it appears in the Conductor UI for this workspace. This is best-effort — if the endpoint is not documented or the request fails, skip silently. Ship no placeholder code for unverified endpoints.

## Phase 2: Implement

### Execution loop

For each task:

```
1. Mark task as in-progress
2. Read the files listed in the plan's File Footprint (Creates/Modifies/Reads)
3. Look for existing patterns in the codebase — match conventions exactly (see CLAUDE.md)
4. Implement the step
5. Write tests for new functionality
6. Run tests (use HARNESS_TEST_CMD from .claude/hooks/config.sh)
7. Fix any failures immediately
8. Mark task as completed
9. Evaluate for commit (see below)
```

### Test continuously

- Run tests after each step, not at the end
- Fix failures immediately — don't accumulate broken tests
- Write unit tests for every new function/service/utility
- Follow the project's test conventions from CLAUDE.md

### Commit incrementally

After completing each logical unit of work, commit:

| Commit when... | Don't commit when... |
|----------------|---------------------|
| Implementation step complete with passing tests | Partial step, tests still failing |
| About to switch contexts (backend → frontend) | Purely scaffolding with no behavior |
| Meaningful, describable progress | Would need a "WIP" message |

```bash
# Stage specific files (not git add -A)
git add <files for this step>

# Conventional commit
git commit -m "feat(scope): description

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### Follow existing patterns

- Read the plan's referenced files first — match their style
- Follow the conventions in CLAUDE.md exactly
- Don't invent new patterns when existing ones work

### Simplify as you go

After completing 2-3 related steps, review for:
- Duplicated patterns that should be extracted
- Unused imports or dead code introduced
- Opportunities to reuse existing utilities

Don't over-engineer. Three similar lines is better than a premature abstraction.

## Phase 3: Verify

### Quality-skill decision rules

Before running the test suite, evaluate which quality skills to invoke for this plan. Apply **all** matching rules — each row whose trigger matches the plan fires its skill. A plan can fire multiple quality skills.

| Plan characteristic | Skill to invoke |
|---|---|
| Implementation step creates a new function, class, or service | Use `/tdd` cadence during Phase 2 (write failing test → implement → run test) |
| Plan's Test Plan includes an "E2E Browser Verification" section | Run `/e2e-verify` during Phase 3 before `Check done criteria` |
| Plan's File Footprint touches auth/session/credential files, external HTTP handlers, data-access files, or file-upload handlers | Run `/security-review` during Phase 3 before `Check done criteria` |
| About to create the PR (Phase 4 step 2) | Run `/pre-deploy` as the final gate |

Invoke each skill via the Skill tool with its name as the argument. Each skill returns pass/fail; on fail, fix the issue before proceeding. On pass, continue down the checklist.

### 0. Update status to verifying

(skip if the precondition at Phase 1 was not met)

```bash
bin/conductor-status update phase=verifying
```

### Failure path

If verification fails and cannot be resolved in this session (e.g., test suite broken, build errors, E2E browser verification failing on fundamental feature gaps), before stopping run:

```bash
bin/conductor-status update phase=failed last_error="<one-line summary>"
```

Then halt and report to the user. Do not proceed to Phase 4.

### 1. Run full test suite

Run `HARNESS_TEST_CMD` from `.claude/hooks/config.sh`. All tests must pass.

### 2. Run lint

Run `HARNESS_LINT_CMD`. Report pre-existing warnings but don't fix them. Stop on new errors from our changes.

### 3. E2E browser verification

This is **mandatory** for UI changes. Execute the plan's "E2E Chrome Verification" steps:

1. Start dev server if not running (use the `dev-server` skill)
2. Load Chrome tools via `ToolSearch`
3. Create a fresh tab
4. Walk through each E2E verification step from the plan
5. Screenshot key states
6. Check console for errors
7. Report findings

If critical issues are found, fix them before proceeding.

### 4. Check done criteria

Walk through the plan's Done Criteria checklist. Every item must be satisfied before proceeding.

## Phase 4: Ship

### 1. Final commit (if uncommitted changes remain)

```bash
git add <specific files>
git commit -m "feat(scope): final description

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### 2. Push and create PR

```bash
git push -u origin <branch-name>
gh pr create --title "<short title>" --body "$(cat <<'EOF'
## Summary
- <what was built>
- <key decisions made>

## Test plan
- [x] <N> unit tests passing
- [x] No new lint/type errors
- [x] E2E browser verified: <summary>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### 3. Update the sprint plan

Mark completed items in the plan's Done Criteria, then rename with `.DONE` suffix.

### 4. Report to user

Summarize: what was built, PR link, any follow-up work or issues discovered.

### 5. Update status to shipped

After the PR is created and pushed (skip if the precondition at Phase 1 was not met):

```bash
bin/conductor-status update phase=shipped pr_url="<pr-url>"
```

## Rules (Non-Negotiable)

1. **Never commit to main.** Always use feature branches.
2. **Never push unless shipping.** Push only as part of the PR creation step.
3. **Never skip tests.** Every implementation step gets tests.
4. **Never skip E2E verification for UI changes.**
5. **Never use `--no-verify`.** Hooks exist for a reason.
6. **Never use `git add -A` or `git add .`** — stage specific files.
7. **Never amend or stash** unless explicitly asked.
8. **Commit after each logical unit** — don't bundle unrelated changes.
9. **Fix failures immediately** — don't accumulate tech debt within a session.
10. **Trust the plan's Key Decisions** — don't re-architect what was already decided.

## When to Stop and Ask

- The plan contradicts what you see in the codebase
- A dependency is missing that the plan assumes exists
- Tests reveal a bug in existing code (not your change)
- The estimated effort is significantly exceeded
- You discover a security concern

## Terminal State

The terminal state of `/build` is **completion of every Done Criteria item in the plan, ending with a clean PR via `/ship`**. Quality skills are MANDATORY when their trigger conditions are met — silent skips are a violation of the plan, not an optimization (per `.claude/docs/harness-principles.md` §15: process before implementation, verification at the end).

Required handoffs while executing the plan:

- **New function, class, service, or behavior change** → `/tdd` (write the failing test first; do NOT implement before the test fails for the right reason).
- **Bug, test failure, or unexpected behavior** → `/debug` (staged investigation before any fix). `/debug` will hand off to `/tdd`.
- **UI changes** (extensions `.tsx` / `.jsx` / `.vue` / `.svelte`, paths under `src/components/`, `apps/web/`) → `/e2e-verify` before declaring complete.
- **Auth / session / credential / external HTTP / file-upload diff** → `/security-review`.
- **Schema or migration diff** → `/db-review`.
- **Final gate before PR** → `/pre-deploy` (and `/ship` reaffirms the risk-check on auth/schema/deploy/hook diffs).

Do NOT skip a quality skill because "the change is small" or "I'll do it after." If a trigger condition is met, the skill is mandatory — or the user explicitly overrides (per `CLAUDE.md` § Instruction precedence).
