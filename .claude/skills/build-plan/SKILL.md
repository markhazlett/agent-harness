---
name: build
description: Execute a sprint plan end-to-end — branch, implement, test, verify in browser, commit incrementally, and prepare for PR. Pass it a sprint plan document path.
user-invocable: true
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
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

Write the initial status file so sibling workspaces can see this work starting:

```bash
bin/conductor-status update \
  workspace="$(basename "$PWD")" \
  repo="$(basename "$(dirname "$(pwd)")")" \
  plan="<the-plan-path-you-read>" \
  branch="$(git symbolic-ref --short HEAD)" \
  phase=implementing
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

Conductor has a native "Todos" feature that gates merge-readiness. The public docs don't document a scriptable interface at time of writing (2026-04-19); the OpenAPI spec at `https://docs.conductor.build/openapi.json` may expose one.

During implementation, read the OpenAPI spec. If it contains a Todos endpoint, add a shell call here that POSTs each Done Criterion as a todo. If it doesn't, skip this step entirely — the status file and sibling rollup are sufficient.

No placeholder code ships in the skill file. This note exists so a future iteration knows where to add the integration when the API stabilizes.

## Phase 2: Implement

### Execution loop

For each task:

```
1. Mark task as in-progress
2. Read the files listed in the plan's File Footprint (Creates/Modifies/Reads)
3. Look for existing patterns in the codebase — match conventions exactly (see CLAUDE.md)
4. Implement the step
5. Write tests for new functionality
6. Run tests (use HARNESS_TEST_CMD from .claude/hooks/harness.config.sh)
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

Before running the test suite, evaluate which quality skills to invoke for this plan. Apply these rules in order:

| Plan characteristic | Skill to invoke |
|---|---|
| Implementation step creates a new function, class, or service | Use `/tdd` cadence during Phase 2 (write failing test → implement → run test) |
| Plan's Test Plan includes an "E2E Browser Verification" section | Run `/e2e-verify` during Phase 3 before `Check done criteria` |
| Plan's File Footprint touches auth/session/credential files, external HTTP handlers, data-access files, or file-upload handlers | Run `/security-review` during Phase 3 before `Check done criteria` |
| About to create the PR (Phase 4 step 2) | Run `/pre-deploy` as the final gate |

Invoke each skill via the Skill tool with its name as the argument. Each skill returns pass/fail; on fail, fix the issue before proceeding. On pass, continue down the checklist.

### 0. Update status to verifying

```bash
bin/conductor-status update phase=verifying
```

### 1. Run full test suite

Run `HARNESS_TEST_CMD` from `.claude/hooks/harness.config.sh`. All tests must pass.

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

After the PR is created and pushed:

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
