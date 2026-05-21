# Pi Harness Support — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the agent harness to support Pi as a third `HARNESS_HOST` option (alongside `conductor` and `claude-code`), with full feature parity.

**Architecture:** Restructure the harness source repo to a neutral canonical layout (`skills/`, `prompts/`, `agents/`, `hooks/{shell,pi}/`), with target-specific copies at install time. Pi hooks are TypeScript extensions implementing the same semantics as the existing shell hooks. A new `task-tool` extension provides subagent dispatch via Pi's SDK.

**Tech Stack:** TypeScript (Pi extensions via the Pi SDK), Bash (existing shell hooks + setup.sh), Vitest (TS unit tests), Bats-style scripts (existing `bin/tests/`), Node ≥20.

**Spec reference:** `docs/superpowers/specs/2026-05-18-pi-harness-design.md` — **read this before starting any task**. The spec has the canonical TypeScript code samples for each extension; this plan references spec sections by number instead of inlining them.

---

## Phase 0 — Research tasks (resolve open questions)

Each task writes findings into `docs/superpowers/specs/2026-05-18-pi-harness-research.md`. Resolve all of these before Phase 4.

### Task R0: Create research log file

**Files:** Create `docs/superpowers/specs/2026-05-18-pi-harness-research.md`.

- [ ] **Step 1:** Create the file with five top-level sections (R1–R5), each with subsections "Question", "Method", "Finding", "Implication."
- [ ] **Step 2:** Commit: `docs(pi-harness): start research log`.

### Task R1: Confirm createAgentSession API in the Pi SDK

**Goal:** Determine whether `createAgentSession` exists in `@earendil-works/pi-coding-agent` and what its signature is. Spec §5 assumes it does.

- [ ] **Step 1:** In a scratch dir, `npm install @earendil-works/pi-coding-agent`.
- [ ] **Step 2:** Inspect the package's `.d.ts` files for `createAgentSession`, `spawnAgent`, `SessionRuntime`, or any session-spawning primitive. List exported symbols.
- [ ] **Step 3:** Write findings into R1: either "API confirmed at `<import path>` with signature `<sig>`" or "Not found — alternative API is `<X>` OR fallback to subprocess (`pi --headless`) per R4."
- [ ] **Step 4:** If the API exists, write a 10-line smoke test that spawns a session and prints its response. Run it with `ANTHROPIC_API_KEY` set.
- [ ] **Step 5:** Commit findings.

### Task R2: Confirm parallel session spawning

**Goal:** Verify that two `createAgentSession` calls in `Promise.all` run in parallel (not serialized).

- [ ] **Step 1:** If R1 found no session API, mark this N/A (subprocess fallback is parallel-by-default).
- [ ] **Step 2:** Otherwise, write a small script that spawns 3 sessions in `Promise.all`, each asking "what's your label?". Compare total wall-clock against the longest individual call.
- [ ] **Step 3:** Write findings: parallel-supported (total ≈ longest) or serialized (total ≈ sum). If serialized, document v1 behavior as sequential-only.
- [ ] **Step 4:** Commit findings.

### Task R3: Confirm before_agent_start can mutate the system prompt

**Goal:** `init.sh` injects branch + commits + handoff into the agent context. Determine how to do this on Pi.

- [ ] **Step 1:** Grep the Pi SDK `.d.ts` files for the return shape of the `before_agent_start` handler.
- [ ] **Step 2:** Write a 20-line scratch extension that returns various shapes from `before_agent_start` (system-prompt additions, prepended messages). Run with `pi --extension ./scratch/index.ts`.
- [ ] **Step 3:** Document which return shape (if any) actually injects context. If none works, document the fallback: use `pi.sendMessage({ role: "system", content })` on `session_start` instead.
- [ ] **Step 4:** Commit findings.

### Task R4: Confirm pi --headless

**Goal:** The integration test (Task 32) needs a non-interactive Pi invocation.

- [ ] **Step 1:** Run `pi --help` and grep for `headless`, `rpc`, `json`, `non-interactive`.
- [ ] **Step 2:** Try the documented invocation with a trivial prompt; observe whether it executes and what the output format is.
- [ ] **Step 3:** Document the exact flag(s) and output format.
- [ ] **Step 4:** Commit findings.

### Task R5: Defer Pi + Conductor compatibility

- [ ] **Step 1:** Write a brief R5 section noting v2 scope: probe whether Conductor's workspace config can override the launched binary (`pi` instead of `claude`).
- [ ] **Step 2:** Commit.

---

## Phase 1 — Repo restructure (commit 1)

Single behavior-preserving refactor.

### Task 1: Create canonical directories

- [ ] **Step 1:** `mkdir -p skills prompts agents hooks/shell hooks/pi` and add a `.gitkeep` to each.
- [ ] **Step 2:** Verify with `ls -la`.

### Task 2: Move skills to canonical location

- [ ] **Step 1:** `git mv .claude/skills/* skills/`.
- [ ] **Step 2:** `rmdir .claude/skills && ln -s ../skills .claude/skills`.
- [ ] **Step 3:** Verify: `ls skills/` shows ≥30 dirs; `ls -la .claude/skills` shows symlink.

### Task 3: Move prompts to canonical location

- [ ] **Step 1:** `git mv .claude/commands/*.md prompts/`.
- [ ] **Step 2:** `rmdir .claude/commands && ln -s ../prompts .claude/commands`.
- [ ] **Step 3:** Verify.

### Task 4: Move agents to canonical location

- [ ] **Step 1:** `git mv .claude/agents/*.md agents/`.
- [ ] **Step 2:** `rmdir .claude/agents && ln -s ../agents .claude/agents`.

### Task 5: Move shell hooks; rename config

- [ ] **Step 1:** For each `.sh` file in `.claude/hooks/` that is NOT `harness.config.sh`: `git mv` it to `hooks/shell/`.
- [ ] **Step 2:** `git mv .claude/hooks/harness.config.sh hooks/config.sh`.
- [ ] **Step 3:** `rmdir .claude/hooks && ln -s ../hooks/shell .claude/hooks`.

### Task 6: Update hook sourcing paths

The shell hooks source `harness.config.sh` via `$(dirname "$0")/harness.config.sh`. After the move, the relative path is wrong.

- [ ] **Step 1:** `grep -l "harness.config.sh" hooks/shell/*.sh` to find affected files.
- [ ] **Step 2:** In each, change `source "$(dirname "$0")/harness.config.sh"` → `source "$(dirname "$0")/../config.sh"`.
- [ ] **Step 3:** Verify each hook still parses: `for f in hooks/shell/*.sh; do bash -n "$f"; done`.

### Task 7: Bulk-update cross-references

Many files reference the old paths. Update them.

- [ ] **Step 1:** Inventory:
  ```
  grep -rln "\.claude/skills/\|\.claude/commands/\|\.claude/agents/\|\.claude/hooks/\|harness\.config\.sh" --include="*.md" --include="*.sh"
  ```
- [ ] **Step 2:** Apply substitutions (sed in-place):
  - `.claude/skills/` → `skills/`
  - `.claude/commands/` → `prompts/`
  - `.claude/agents/` → `agents/`
  - `.claude/hooks/harness.config.sh` → `hooks/config.sh` (do this BEFORE the next one)
  - `.claude/hooks/` → `hooks/shell/`
- [ ] **Step 3:** Re-grep to verify zero remaining old-path references in `*.md` and `*.sh`. (`.claude/settings.json` may legitimately keep that path; ignore.)
- [ ] **Step 4:** Syntax-check all touched shell scripts.

### Task 8: Update bin/tests

- [ ] **Step 1:** The Task 7 sed pass already covers `bin/tests/*.test.sh`. Verify: `grep -rn "\.claude/skills/\|\.claude/commands/\|\.claude/agents/" bin/tests/` returns empty.
- [ ] **Step 2:** Run the bin test suite: `for t in bin/tests/*.test.sh; do bash "$t"; done`. Expect all pass.

### Task 9: Run /harness-health

- [ ] **Step 1:** Invoke `/harness-health` in this repo (host=conductor or claude-code). Confirm all checks green.

### Task 10: Commit the restructure

- [ ] **Step 1:** Review `git status` + `git diff --stat`. Expect ~30 skill dirs renamed, ~25 prompt files, 4 agents, 10 hook files renamed, ~80–120 files modified for path updates, 4 symlinks added.
- [ ] **Step 2:** Commit with message:
  ```
  refactor: move skills/prompts/agents/hooks to neutral canonical layout

  Preparing for Pi host support. Skills, prompts, agents, and shell hooks
  now live at neutral root locations (skills/, prompts/, agents/,
  hooks/shell/); .claude/ contains symlinks into the canonical tree.
  Project config renamed from harness.config.sh to hooks/config.sh.
  ~80 cross-references updated.

  No behavior change: Claude Code and Conductor installs work identically.
  ```

---

## Phase 2 — Pi extension scaffolding

### Task 11: Create hooks/pi package files

**Files:** `hooks/pi/package.json`, `hooks/pi/tsconfig.json`, `hooks/pi/vitest.config.ts`.

- [ ] **Step 1:** Write `package.json` per spec §4 (peer deps on Pi SDK packages, dev dep on TypeScript and Vitest, dep on `gray-matter`).
- [ ] **Step 2:** Write `tsconfig.json` (ESM, strict, `noEmit: true` since Pi loads `.ts` via jiti).
- [ ] **Step 3:** Write `vitest.config.ts` pointing at `**/__tests__/*.test.ts`.
- [ ] **Step 4:** `cd hooks/pi && npm install`. Verify install succeeds.
- [ ] **Step 5:** `npm run typecheck` — passes with zero source files.

### Task 12: Implement hooks/pi/_lib/paths.ts

**Goal:** `findProjectRoot()`, `getHooksConfigPath()`, `getAgentsDir()`.

- [ ] **Step 1:** Write `_lib/__tests__/paths.test.ts` covering: walks up from a starting dir; returns correct paths to `.pi/hooks/config.sh` and `.pi/agents`.
- [ ] **Step 2:** Run the test — expect FAIL (module not found).
- [ ] **Step 3:** Implement `_lib/paths.ts`. The functions use `existsSync` from `node:fs` to walk up looking for `.pi/` or `.claude/`. Code sample in spec §4.
- [ ] **Step 4:** Run tests — expect PASS.
- [ ] **Step 5:** Commit: `feat(pi/hooks): add paths utility`.

### Task 13: Implement hooks/pi/_lib/config.ts — the shell-config parser

**Goal:** Parse `hooks/config.sh` directly in TypeScript without invoking a shell. Spec §4 bullet "Project config bridge" describes the constraints.

- [ ] **Step 1:** Write `_lib/__tests__/config.test.ts` covering:
  - `KEY=value` (unquoted)
  - `KEY="value with spaces"` (double-quoted)
  - `KEY='single quoted'`
  - Comment lines and blank lines skipped
  - Inline trailing comments stripped (respecting quote context)
  - Rejects `KEY=$(date)` (command substitution) — throws
  - Rejects backticks — throws
  - Rejects `if/then/fi` blocks — throws
  - Rejects `${VAR}` expansion — throws
  - Parses multiple keys correctly
- [ ] **Step 2:** Run — expect FAIL.
- [ ] **Step 3:** Implement the parser. Strategy:
  - Split by line; trim each.
  - Strip trailing comments via a small state machine that respects single/double quotes.
  - Match against `^([A-Za-z_][A-Za-z0-9_]*)=(.*)$`.
  - Reject any line with `$(`, backtick, `${`, or `$<letter>` in the value.
  - Reject lines starting with shell keywords (`if`, `for`, `while`, `case`, `function`, `[`, `export ... =`).
  - Unquote the value if it's wrapped in matching `"` or `'`.
- [ ] **Step 4:** Run — expect PASS.
- [ ] **Step 5:** Smoke-test against the real config:
  ```
  node -e "import('./hooks/pi/_lib/config.js').then(m => console.log(m.loadHarnessConfig('./hooks/config.sh')))"
  ```
  Expect: object with real keys. If it throws, the real config has an unsupported construct — fix the config (preferred) or extend the parser.
- [ ] **Step 6:** Commit: `feat(pi/hooks): add config.sh parser (no shell exec)`.

### Task 14: Implement hooks/pi/_lib/git.ts

**Goal:** `currentBranch()`, `isDirty()`.

- [ ] **Step 1:** Write tests in `_lib/__tests__/git.test.ts` using a tempdir-based real git repo (init, commit, modify, branch). Tests verify branch detection on main and on a feature branch, dirty/clean detection.
- [ ] **Step 2:** Run — expect FAIL.
- [ ] **Step 3:** Implement. Each function uses `execFileSync('git', [...args])` from `node:child_process` (the safe variant — no shell, explicit arg array). Returns trimmed stdout strings.
- [ ] **Step 4:** Run — expect PASS.
- [ ] **Step 5:** Commit: `feat(pi/hooks): add git helpers`.

### Task 15: Implement hooks/pi/_lib/notify.ts

**Goal:** macOS notifications via `osascript`, with safe escaping of title/message.

- [ ] **Step 1:** Write tests covering: notifier is called with `osascript` + `-e` + an AppleScript string; escapes embedded quotes; does not throw if osascript fails.
- [ ] **Step 2:** Run — expect FAIL.
- [ ] **Step 3:** Implement using `execFileSync('osascript', ['-e', script])` (safe — explicit arg array, no shell). Build the script string with `\"` escaping for double quotes in title/message. Wrap in try/catch so notification failures never break the agent.
- [ ] **Step 4:** Run — expect PASS.
- [ ] **Step 5:** Commit: `feat(pi/hooks): add macOS notify helper`.

---

## Phase 3 — Hook ports

Eight hooks. Each follows the same shape: read the shell original, write tests that mirror its rules/behavior, implement, verify, commit. Most have a pure check/decide function (testable in isolation) plus a thin Pi-extension wrapper (registers the event handler).

### Task 16: Port bash-guard

**Original:** `hooks/shell/bash-guard.sh`. **New:** `hooks/pi/bash-guard/index.ts` + `check.ts`.

- [ ] **Step 1:** Read the shell file. List every rule it enforces (block git commit on main, block --no-verify, block rm -rf on source dirs, block sed -i on source files, etc.).
- [ ] **Step 2:** Write tests in `bash-guard/__tests__/bash-guard.test.ts` — one test per rule, plus negative tests for benign commands. Tests target a pure `checkBashCommand(cmd, cfg)` function.
- [ ] **Step 3:** Run — expect FAIL.
- [ ] **Step 4:** Implement `check.ts` exporting `checkBashCommand(cmd, cfg)`. Code sample in spec §4. Each rule is one `if` returning `{ block: true, reason }`; final return is `undefined`.
- [ ] **Step 5:** Implement `index.ts` — thin wrapper that loads config via `loadHarnessConfig(getHooksConfigPath(findProjectRoot(process.cwd())))`, registers `pi.on("tool_call", ...)`, filters to `event.toolName === "bash"`, returns `checkBashCommand(cmd, cfg)`.
- [ ] **Step 6:** Run tests — expect PASS.
- [ ] **Step 7:** Compare rules against shell hook one more time — any gap means an extra test + extra `if`.
- [ ] **Step 8:** Commit: `feat(pi/hooks): port bash-guard`.

### Task 17: Port protected-files

**Original:** `hooks/shell/protected-files.sh`. **New:** `hooks/pi/protected-files/{index,check}.ts`.

- [ ] **Step 1:** Enumerate rules from the shell file (block `.env*`, lockfiles, `settings.json`, hook scripts, `hooks/config.sh`, etc.).
- [ ] **Step 2:** Write tests against a pure `checkProtectedFile(path)` function.
- [ ] **Step 3:** Implement `check.ts` with regex patterns for each protected path family.
- [ ] **Step 4:** Implement `index.ts` — registers `pi.on("tool_call", ...)`, filters to `["edit","write","multi_edit"].includes(event.toolName)`, extracts `event.input.file_path`, returns `checkProtectedFile(path)`.
- [ ] **Step 5:** Run tests — expect PASS.
- [ ] **Step 6:** Commit: `feat(pi/hooks): port protected-files`.

### Task 18: Port init (session-context injection)

**Original:** `hooks/shell/init.sh`. **New:** `hooks/pi/init/{index,build-context}.ts`.

- [ ] **Step 1:** Read the shell hook. Note the exact format it injects (sections, headings).
- [ ] **Step 2:** Write tests for a pure `buildSessionContext({ projectRoot })` function that returns a string. Tests mock `git` helpers; verify the string contains the branch, recent commits, uncommitted-changes stat, and (when present) the prior handoff note.
- [ ] **Step 3:** Implement `build-context.ts`. Uses `currentBranch()` and `isDirty()` from `_lib/git.ts`; calls `git log --oneline -5` and `git diff --stat` via `execFileSync` from `node:child_process`. Reads `.pi/handoff/latest.md` if it exists.
- [ ] **Step 4:** Implement `index.ts`. Uses the injection mechanism confirmed by R3 — either return value from `before_agent_start` or a synthetic `pi.sendMessage` on `session_start`. Whichever R3 documents.
- [ ] **Step 5:** Run tests — expect PASS.
- [ ] **Step 6:** Commit: `feat(pi/hooks): port init`.

### Task 19: Port context-reinject

**Original:** `hooks/shell/context-reinject.sh`. **New:** `hooks/pi/context-reinject/{index,build-reinject}.ts`.

- [ ] **Step 1:** Read the shell hook. Note that it fires on resume/compact and is lighter than the init context.
- [ ] **Step 2:** Write tests for `buildReinjectContext({ projectRoot })`.
- [ ] **Step 3:** Implement `build-reinject.ts` — a shorter context (branch + "check git status reminder").
- [ ] **Step 4:** Implement `index.ts` registering `pi.on("session_compact", ...)`.
- [ ] **Step 5:** Run tests — expect PASS.
- [ ] **Step 6:** Commit: `feat(pi/hooks): port context-reinject`.

### Task 20: Port post-edit

**Original:** `hooks/shell/post-edit.sh`. **New:** `hooks/pi/post-edit/{index,decide-actions}.ts`.

- [ ] **Step 1:** Read the shell hook. Note: it runs format + lint asynchronously; also runs the DB migrate command when a schema file is touched.
- [ ] **Step 2:** Write tests for `decideActions(path, cfg)` returning `{ format: bool, lint: bool, dbMigrate: bool }`. Tests cover source TS files (format+lint true), schema files (dbMigrate true), docs/README files (all false).
- [ ] **Step 3:** Implement `decide-actions.ts` — regex-based, reads `HARNESS_SRC_DIRS` and `HARNESS_DB_SCHEMA` from config.
- [ ] **Step 4:** Implement `index.ts`. Registers `pi.on("tool_result", ...)`, filters to edit/write/multi_edit, looks up actions, fires each chosen action via `spawn(...)` from `node:child_process` (detached, `stdio: "ignore"`, `.unref()` — fire-and-forget so the agent isn't blocked).
- [ ] **Step 5:** Run tests — expect PASS.
- [ ] **Step 6:** Commit: `feat(pi/hooks): port post-edit`.

### Task 21: Port stop

**Original:** `hooks/shell/stop.sh`. **New:** `hooks/pi/stop/{index,decide-stop}.ts`.

- [ ] **Step 1:** Read the shell hook. Note: runs test + typecheck if sources changed; writes a handoff file; sends macOS notification.
- [ ] **Step 2:** Write tests for `decideStopActions({ changedFiles, cfg })` returning `{ test, typecheck, handoff }`.
- [ ] **Step 3:** Implement `decide-stop.ts`.
- [ ] **Step 4:** Implement `index.ts`. On `agent_end`: derive changed files (`git diff --name-only HEAD` via `execFileSync`), compute actions, fire test/typecheck commands detached, write handoff file to `.pi/handoff/latest.md`, call `notify()` from `_lib/notify.ts`.
- [ ] **Step 5:** Run tests — expect PASS.
- [ ] **Step 6:** Commit: `feat(pi/hooks): port stop`.

### Task 22: Port failure-log

**Original:** `hooks/shell/failure-log.sh`. **New:** `hooks/pi/failure-log/{index,format}.ts`.

- [ ] **Step 1:** Read the shell hook. Note format: JSONL line per failure with `ts`, `tool`, `input`, `error`.
- [ ] **Step 2:** Write test for `formatFailureEntry(e)` producing a single-line valid JSON.
- [ ] **Step 3:** Implement `format.ts` — one-liner JSON stringification.
- [ ] **Step 4:** Implement `index.ts`. Registers `pi.on("tool_result", ...)`. If `event.error` is truthy, append a JSONL line to `.pi/logs/failures.jsonl` (mkdir -p first).
- [ ] **Step 5:** Run tests — expect PASS.
- [ ] **Step 6:** Commit: `feat(pi/hooks): port failure-log`.

### Task 23: Port pre-compact

**Original:** `hooks/shell/pre-compact.sh`. **New:** `hooks/pi/pre-compact/{index,snapshot-name}.ts`.

- [ ] **Step 1:** Read the shell hook. Note: snapshots the transcript before compaction to `.pi/transcripts/transcript-<ts>.jsonl`.
- [ ] **Step 2:** Write test for `snapshotName(date)` producing the timestamped filename.
- [ ] **Step 3:** Implement `snapshot-name.ts`.
- [ ] **Step 4:** Implement `index.ts`. On `session_before_compact`: get entries via `ctx.sessionManager.getBranch()`, write each as a JSON line to the snapshot path.
- [ ] **Step 5:** Run tests — expect PASS.
- [ ] **Step 6:** Commit: `feat(pi/hooks): port pre-compact`.

---

## Phase 4 — task-tool

### Task 24: Implement task-tool

**New:** `hooks/pi/task-tool/{index,parse-agent}.ts`.

- [ ] **Step 1:** Check R1 outcome. Pick branch:
  - **A. R1 confirmed Pi SDK has `createAgentSession`** — use it directly.
  - **B. R1 found no session API** — fall back to subprocess: spawn `pi` (with whatever headless flag R4 confirmed) using `execFile` from `node:child_process`. Pass the agent's system prompt via flag/stdin per R4.
- [ ] **Step 2:** Write test for `parseAgentFile(raw)` — extracts `model`, `tools`, `systemPrompt` from frontmatter using `gray-matter`.
- [ ] **Step 3:** Implement `parse-agent.ts`.
- [ ] **Step 4:** Implement `index.ts` per spec §5:
  - Discover available agents by listing `getAgentsDir(findProjectRoot(...))`.
  - Register a `task` tool with parameters `subagent_type` (enum of discovered agents), `description`, `prompt`.
  - In `execute`, parse the chosen agent's `.md`, dispatch via Path A or Path B from Step 1, return final message.
- [ ] **Step 5:** Run unit tests — `parseAgentFile` passes. Full `execute()` flow is covered by the integration test in Task 32.
- [ ] **Step 6:** Commit: `feat(pi/hooks): add task-tool for subagent dispatch`.

---

## Phase 5 — setup.sh (commit 2)

### Task 25: Add third host option

**Files:** modify `setup.sh`.

- [ ] **Step 1:** Locate the existing host-prompt block (`[1] Conductor / [2] Claude Code only`).
- [ ] **Step 2:** Add `[3] Pi`. Extend the `case` block: `3) HARNESS_HOST="pi" ;;` and an `*)` arm that errors on invalid input.
- [ ] **Step 3:** After host selection, branch into `install_claude_code_target` (existing logic, refactored into a function) or `install_pi_target` (Task 26).
- [ ] **Step 4:** Verify with `bash -n setup.sh`.

### Task 26: Implement install_pi_target

**Files:** modify `setup.sh`.

- [ ] **Step 1:** Add the function. Steps:
  1. `mkdir -p` `.pi/{skills,prompts,agents,extensions,hooks}`.
  2. `cp -r` `skills/.` → `.pi/skills/`, `prompts/.` → `.pi/prompts/`, `agents/.` → `.pi/agents/`, `hooks/pi/.` → `.pi/extensions/`.
  3. `cp hooks/config.sh .pi/hooks/config.sh`.
  4. Generate `.pi/settings.json` (skeleton per spec §6).
  5. Install npm deps inside `.pi/extensions/` (`pnpm install` or `npm install`).
  6. If `AGENTS.md` doesn't exist, copy from `AGENTS.md.template`.
  7. Print next-steps banner.
- [ ] **Step 2:** Verify `bash -n setup.sh`.
- [ ] **Step 3:** Dry-run against a tempdir:
  ```
  TMP=$(mktemp -d); cp -r skills prompts agents hooks setup.sh VERSION "$TMP/"
  HARNESS_HOST=pi REPO_ROOT="$TMP" bash -c "cd '$TMP'; source ./setup.sh; install_pi_target"
  ls "$TMP/.pi/"
  ```
  Expect: skills, prompts, agents, extensions, hooks, settings.json all present.

### Task 27: Write bin/tests/setup-pi.test.sh

- [ ] **Step 1:** Write a bats-style script (mirror existing tests' style) with three test cases:
  - `install_pi_target` populates `.pi/skills/` with files
  - `install_pi_target` writes valid JSON to `.pi/settings.json` (verify with `jq .`)
  - `install_pi_target` copies all extension dirs including `task-tool/index.ts`
- [ ] **Step 2:** Make executable and run. Expect all pass.
- [ ] **Step 3:** Commit:
  ```
  feat(setup): add third host option (pi) + install_pi_target

  Adds Pi as a third HARNESS_HOST. install_pi_target copies skills,
  prompts, agents, and TypeScript extensions into .pi/, generates
  .pi/settings.json, and installs npm dependencies. Tested by
  bin/tests/setup-pi.test.sh.
  ```

---

## Phase 6 — AGENTS.md template

### Task 28: Rename template + branch in setup.sh

- [ ] **Step 1:** `git mv docs/claude-md-template.md AGENTS.md.template`.
- [ ] **Step 2:** Locate the template-copy logic in setup.sh. Change `CLAUDE.md` → variable `TARGET_FILE`:
  - `host=conductor|claude-code` → `TARGET_FILE="CLAUDE.md"`
  - `host=pi` → `TARGET_FILE="AGENTS.md"`
  - If `! -f "$TARGET_FILE"`, copy from `AGENTS.md.template`.
- [ ] **Step 3:** Read the template. Generalize any "Claude Code"–specific language; keep host-neutral phrasing for the precedence and convention sections.
- [ ] **Step 4:** Commit: `feat(setup): rename CLAUDE.md template to AGENTS.md.template (host-neutral)`.

---

## Phase 7 — Skill + doc updates

### Task 29: Make /harness-update target-aware

**Files:** modify `skills/harness-update/SKILL.md`.

- [ ] **Step 1:** Read the skill. Identify the section listing source→target path mappings.
- [ ] **Step 2:** Add an early "Detect target" section: read `HARNESS_HOST` from `hooks/config.sh`, then switch the path-mapping table on it.
  - `HARNESS_HOST=pi`: sources `skills/`, `prompts/`, `agents/`, `hooks/pi/` → targets `.pi/skills/`, `.pi/prompts/`, `.pi/agents/`, `.pi/extensions/`.
  - Else: existing Claude Code mapping.
- [ ] **Step 3:** Run the skill against this repo (host=conductor or claude-code) — confirm it still classifies files correctly.
- [ ] **Step 4:** Commit: `feat(harness-update): target-aware diff for pi vs claude-code`.

### Task 30: Update harness-overview to document Pi

**Files:** modify `skills/harness-overview/SKILL.md`.

- [ ] **Step 1:** Append a "Pi extensions (for HARNESS_HOST=pi)" table listing the 8 ports + `task-tool` with event + purpose.
- [ ] **Step 2:** Add `pi` to the `HARNESS_HOST` values list at the top of the skill.
- [ ] **Step 3:** Commit: `docs(harness-overview): document Pi target`.

### Task 31: Update README

**Files:** modify `README.md`.

- [ ] **Step 1:** Add a "Pi mode (optional)" section after the existing "Conductor mode (optional)" section. Content: how to pick Pi at setup, feature parity table (skills/prompts/hooks/subagents all yes), exceptions (config-audit dropped, Conductor integration N/A).
- [ ] **Step 2:** Commit: `docs(readme): document Pi mode`.

---

## Phase 8 — Integration test (commit 3)

### Task 32: Integration test for pi + bash-guard

**Files:** create `bin/tests/pi-integration.test.sh`.

- [ ] **Step 1:** Skip if `pi` isn't on PATH (print SKIP and exit 0).
- [ ] **Step 2:** Otherwise: in a tempdir, init a git repo, copy `skills/`, `prompts/`, `agents/`, `hooks/`, `setup.sh`, `VERSION`, `AGENTS.md.template`. Run `install_pi_target`.
- [ ] **Step 3:** Invoke `pi` with whatever headless flag R4 confirmed, passing a prompt like "run: rm -rf src/foo". Capture output.
- [ ] **Step 4:** Assert the output contains the bash-guard block reason ("Refusing rm -rf"). PASS or FAIL accordingly.
- [ ] **Step 5:** Make executable; run. Expect PASS (or SKIP if pi not installed).
- [ ] **Step 6:** Commit: `test(pi): add integration test for bash-guard via pi headless`.

### Task 33: Phase 3+4 consolidation verification

- [ ] **Step 1:** `git log --oneline | grep "pi/hooks"` — expect ≥10 commits (8 ports + scaffolding + task-tool).
- [ ] **Step 2:** `cd hooks/pi && npm test` — all pass.
- [ ] **Step 3:** `for t in bin/tests/*.test.sh; do bash "$t"; done` — all pass.

---

## Phase 9 — VERSION bump + ship (commit 4)

### Task 34: Bump VERSION

- [ ] **Step 1:** `echo "0.15.0" > VERSION`.
- [ ] **Step 2:** Commit: `chore: bump version to 0.15.0 (Pi host support)`.

### Task 35: Final verification + PR

- [ ] **Step 1:** Run all tests one more time (Pi unit + bin tests + `/harness-health`).
- [ ] **Step 2:** Review the full commit graph: `git log --oneline main..HEAD`. Expect ~21 commits.
- [ ] **Step 3:** Hand off to `/ship` for the lint + test + push + PR pipeline. PR body should summarize the 4 logical phases (restructure, Pi extensions + task-tool, setup.sh + AGENTS.md, docs + VERSION).

---

## Self-review

**Spec coverage:**
- §1 Repo restructure → Tasks 1–10 ✓
- §2 Skills layer → Tasks 2 + 7 ✓
- §3 Prompts layer → Tasks 3 + 7 ✓
- §4 Hooks port → Tasks 11–15 (scaffolding) + Tasks 16–23 (eight ports) ✓
- §5 task tool → Task 24 ✓
- §6 setup.sh → Tasks 25–27 ✓
- §7 AGENTS.md → Task 28 ✓
- §8 Update-check / VERSION / testing / distribution → Tasks 29–35 ✓

**Placeholder scan:** every task is concrete. The phrase "code sample in spec §N" intentionally refers the executor to the spec — this is DRY between two documents, not a placeholder.

**Type consistency:** the `HarnessConfig` type lives in `_lib/config.ts` and is imported by every hook. Each hook's pure check/decide function has its own result type defined in the same file.

**One known soft spot:** Task 18 (init) and Task 19 (context-reinject) depend on R3's outcome. If R3 finds that Pi can't mutate the system prompt from extension handlers, the implementation falls back to `pi.sendMessage({ role: "system", ...})` on `session_start` instead of injecting via `before_agent_start`. The task body anticipates this and says "use the injection mechanism confirmed by R3"; the executor must read R3 findings before implementing.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-18-pi-harness.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks. Best fit because the 35 tasks are highly independent (each hook is its own commit) and subagent isolation prevents one bad implementation from polluting another.

2. **Inline Execution** — execute tasks in this session using `superpowers:executing-plans`, batch with checkpoints. Faster start, but 35 tasks will strain context.

Which approach?
