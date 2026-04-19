# Conductor Integration Design

**Date:** 2026-04-19
**Topic:** Wire the agent-harness into Conductor's workspace model so `/plan-sprint` and `/build` can drive parallel, isolated, verifiably-complete sprint execution across multiple Conductor workspaces.

## Context

Agent-harness currently has a mature single-workspace flow: `/plan-sprint` breaks weekly goals into plan documents, `/build <plan>` executes one plan end-to-end, and quality skills (`/e2e-verify`, `/security-review`, `/pre-deploy`, etc.) gate shipping. The harness has no awareness of the fact that it runs inside Conductor, which treats each Claude Code session as an isolated parallel workspace.

The user works almost exclusively in Conductor and wants the harness to exploit that: when a sprint plan has independent projects, spin up a Conductor workspace per project, let each one execute `/build` independently, and have each workspace self-verify before declaring done. A new repo should also boot cleanly in Conductor (good setup/run/archive scripts) without the user having to hand-write `conductor.json`.

**Conductor primitives we use:**

- **`conductor.json`** — repo-local config with `setup` (runs on workspace create), `run` (dev server), and `archive` (cleanup) scripts, executed via zsh.
- **Deep links** — `conductor://async?repo=<repo>&plan=<base64-md>` spawns a new workspace with a plan markdown file attached.
- **Workspace filesystem layout** — all workspaces for a repo live as sibling directories under `~/conductor/workspaces/<repo>/<workspace-name>/`.
- **Todos** — Conductor's native "completion requirements before merge" gate. Scriptable status may exist via the undocumented OpenAPI (`openapi.json`); implementation should probe and use it when possible, fall back otherwise.
- **Checkpoints** — automatic turn-by-turn rollback. No action required.

**Design principle:** the user only ever invokes `/plan-sprint`, `/build`, and `/ad-hoc-plan`. Everything else is plumbing (hooks, helpers, automatic setup).

## Non-goals

- No cross-machine coordination. Assumes all workspaces live under `~/conductor/workspaces/<repo>/` on one Mac.
- No parent-workspace polling of Conductor's API as the source of truth. The filesystem manifest is authoritative; API calls (if any) are optional nice-to-haves.
- No new user-facing slash commands. `/dispatch`, `/workspace-status`, `/workspace-verify`, `/workspace-teardown`, `/conductor-init` are explicitly NOT created — their behaviors fold into existing skills or plumbing.
- No changes to existing quality skills (`/e2e-verify`, `/security-review`, `/pre-deploy`, `/tdd`, `/ship`). They are invoked by `/build`; their internals are untouched.

## Architecture overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  Parent workspace (where /plan-sprint runs)                         │
│  ─────────────────────────────────────────                          │
│    /plan-sprint                                                     │
│      → writes plans to docs/plans/YYYY-wNN/sprint-plans/            │
│      → detects waves by dependency                                  │
│      → offers to open conductor:// deep links for Wave 1            │
│                                                                     │
│    open conductor://async?repo=X&plan=<base64>  ──────┐            │
│                                                        │            │
└────────────────────────────────────────────────────────┼────────────┘
                                                         │
                              ┌──────────────────────────┼──────────────────────────┐
                              │ Conductor spawns N sibling workspaces               │
                              │                                                     │
                   ┌──────────▼──────────┐  ┌──────────▼──────────┐  ┌─────▼─────┐ │
                   │ child workspace 1   │  │ child workspace 2   │  │  ...       │ │
                   │ /build <plan-1.md>  │  │ /build <plan-2.md>  │  │            │ │
                   │  writes             │  │  writes             │  │            │ │
                   │   .context/         │  │   .context/         │  │            │ │
                   │   conductor-        │  │   conductor-        │  │            │ │
                   │   status.json       │  │   status.json       │  │            │ │
                   └─────────────────────┘  └─────────────────────┘  └────────────┘
                              │
                              │  Any session (parent or peer) on SessionStart:
                              │  conductor-context.sh reads sibling status files
                              │  and injects rollup into the session context.
                              ▼
```

**Shared state location:** each workspace's `.context/conductor-status.json`. `.context/` is already gitignored in the harness, so this is local-per-workspace and won't pollute branches.

## Components

### 1. `/plan-sprint` enhancement

**Current:** writes plans to `docs/plans/YYYY-wNN/sprint-plans/` after user approval of a breakdown table.

**Additions:**

#### 1a. Wave detection (after plans are written)
The existing "Dependencies" column in the breakdown table + each plan's File Footprint together determine waves. Detection runs at the end of Phase 3 (all plans written) so File Footprints are known.

Algorithm:
1. Build a dependency graph from each plan's `Depends on` field.
2. Topologically sort into candidate waves.
3. Within each candidate wave, compute file-footprint overlap across plans. Any pair with overlapping `Creates` or `Modifies` paths is split into separate waves (lower-priority one moves to the next wave).
4. Emit per-plan `Parallel-safe: yes` iff it shares its wave with ≥1 other plan; `no` otherwise. Write this into the plan's header.

Then print:

```
## Parallel Execution Plan

Wave 1 (parallel-safe, no unmet dependencies):
  - P0.1 feat-some-feature
  - P0.2 feat-another-feature
  - P0.3 fix-important-bug

Wave 2 (after Wave 1 ships):
  - P0.4 feat-builds-on-P0.1 (depends on P0.1)
```

#### 1b. Dispatch offer (after plan files are written)
At the end of Phase 4, print:

```
## Dispatch Wave 1

Open 3 Conductor workspaces now? Each will boot with its plan
file attached so you can type `/build <plan-path>` to start.

  [y] Open all 3
  [s] Show deep links only (I'll open manually)
  [n] Skip
```

On `y`, invoke `bin/conductor-dispatch <plan-path>` once per wave-1 plan. The helper:
1. Base64-encodes the plan markdown.
2. Builds a `conductor://async?repo=<repo>&plan=<base64>` URL.
3. Runs `open "<url>"` on macOS.

Wave 2+ is NOT auto-dispatched; the user revisits `/plan-sprint` (or runs `bin/conductor-dispatch` directly) after Wave 1 ships.

#### 1c. Plan template addition
The plan template gains a `Parallel-safe: yes | no` field in the header, populated by the wave-detection algorithm above.

### 2. `/build <plan>` enhancement

**Current:** Phase 1 prepare → Phase 2 implement → Phase 3 verify → Phase 4 ship.

**Additions:**

#### 2a. Status file maintenance
At each phase transition, write/update `.context/conductor-status.json`:

```json
{
  "workspace": "accra",
  "plan": "docs/plans/2026-w16/sprint-plans/P0.1-feat-x.md",
  "branch": "feat/x",
  "phase": "implementing" | "verifying" | "shipped" | "failed",
  "done_criteria": [
    { "item": "Unit tests passing", "status": "passed" },
    { "item": "E2E browser verification", "status": "pending" }
  ],
  "started_at": "2026-04-19T13:20:00Z",
  "updated_at": "2026-04-19T14:05:00Z",
  "pr_url": null
}
```

#### 2b. Internal skill orchestration (decision rules)
`/build` already implicitly uses quality skills. This makes the rules explicit:

| When | Invoke |
|---|---|
| Writing a new function/service | `/tdd` cycle for that unit |
| Plan has UI/interaction criteria | `/e2e-verify` during Phase 3 |
| Plan touches auth, session, external input, data access, or file upload | `/security-review` during Phase 3 |
| Before PR creation | `/pre-deploy` as final gate |

The rules live in `/build`'s Phase 3 checklist. No user intervention required.

#### 2c. Conductor Todos mirror (probe-and-use)
During Phase 1, after reading the plan's Done Criteria, attempt to mirror them to Conductor Todos via the repo's OpenAPI (`openapi.json`). Implementation steps:
1. Fetch `https://docs.conductor.build/openapi.json` during implementation research.
2. Identify the Todos endpoint if it exists.
3. If a local API is reachable, POST done criteria. If not, log and proceed with file-only status.

This is best-effort. The status file is authoritative.

#### 2d. Final status update
Phase 4 (after `/ship`) writes `phase: shipped` and the PR URL to the status file.

### 3. `/ad-hoc-plan`

**Unchanged.** Existing skill stays simple. A future iteration can add the same dispatch offer, but it's out of scope for this design.

### 4. `setup.sh` enhancement (replaces `/conductor-init`)

The existing interactive wizard detects the stack (package manager, dev command, port, test command, etc.) and writes `harness.config.sh`. Add a second output: `conductor.json` at the repo root.

**Detection flow (additive to what's already there):**
1. Ask: "Generate conductor.json for Conductor workspace scripts? [Y/n]"
2. On yes:
   - `setup` script: `<pkg-mgr> install` + `cp .env.example .env` if `.env.example` exists + any detected migrate/seed command
   - `run` script: `HARNESS_DEV_CMD` (already captured)
   - `archive` script: kill dev server PID if still running + `rm -rf node_modules .next .turbo dist build` (configurable; user confirms)
3. Write `conductor.json` to repo root.
4. Append `conductor.json` to `.gitignore` NO — it's meant to be committed and team-shared. Do not gitignore it.

**Schema verification:** the implementation plan must verify the exact `conductor.json` schema from https://docs.conductor.build/core/scripts before writing. If the schema has required fields we don't know about, fail gracefully with a helpful message.

### 5. Hook: `conductor-context.sh` (SessionStart)

New hook fired at SessionStart and PreCompact. Behavior:

1. Detect the current workspace root: `pwd` starts with `~/conductor/workspaces/<repo>/<workspace-name>/`. If not under `~/conductor/workspaces/`, do nothing (harness works outside Conductor too).
2. Enumerate sibling workspace directories: `~/conductor/workspaces/<repo>/*/`.
3. For each sibling (excluding self), read `.context/conductor-status.json` if present.
4. Emit a compact summary to stdout for Claude to read:

```
## Conductor workspace state

You are: accra (branch: feat/x, phase: implementing)

Siblings:
  - bali   [P0.2 feat-y]    verifying   — feat/y (dev server on :3001)
  - cairo  [P0.3 fix-z]     shipped     — PR #142 merged
  - delhi  [P0.4 feat-w]    implementing — feat/w
```

Wired into `settings.json` alongside the existing `init.sh`. Runs after `init.sh` so existing context injection still works.

### 6. Helper: `bin/conductor-status`

Shared implementation used by both `conductor-context.sh` and `/build` (via invocation from the skill when updating state).

Subcommands:
- `bin/conductor-status list` — prints the rollup shown above (used by the hook).
- `bin/conductor-status update <key>=<value> [<key>=<value> ...]` — updates fields in the current workspace's `.context/conductor-status.json`. Used by `/build` at each phase.
- `bin/conductor-status get <key>` — reads a field from the current workspace's status.

Written in bash + `jq`, matching the rest of the harness.

### 7. Helper: `bin/conductor-dispatch`

Single-purpose helper used by `/plan-sprint`'s dispatch offer.

Usage: `bin/conductor-dispatch <path-to-plan.md>`

Behavior:
1. Resolve the current repo name from git or from `$PWD`.
2. Read the plan markdown, base64-encode.
3. Build `conductor://async?repo=<repo>&plan=<base64>`.
4. `open` the URL (macOS).
5. Print the URL to stdout so `/plan-sprint` can show the user what was opened.

### 8. Hook: `post-ship.sh` (optional, Stop-phase)

On session stop, if the last commit of the session was a merge-commit of the workspace's branch (detected via `git log`), write `phase: shipped` + `pr_url` + `merged_at` to the status file. Light touch — makes the manifest reflect reality after `/ship` completes even if the user ended the session mid-merge.

## Data contracts

### `.context/conductor-status.json`

Single source of truth per workspace. Written by `/build` and `bin/conductor-status update`. Read by `conductor-context.sh`.

```json
{
  "schema_version": 1,
  "workspace": "<conductor-workspace-name>",
  "repo": "<repo-name>",
  "plan": "<path-to-plan-md-relative-to-repo-root>",
  "branch": "<git-branch>",
  "phase": "planning | implementing | verifying | shipped | failed",
  "done_criteria": [{ "item": "<string>", "status": "pending | passed | failed" }],
  "dev_server_port": "<int | null>",
  "pr_url": "<url | null>",
  "last_error": "<string | null>",
  "started_at": "<iso-8601>",
  "updated_at": "<iso-8601>"
}
```

Missing file = workspace hasn't run `/build` yet; treated as `phase: planning` by consumers.

### `conductor.json` (schema to verify)

Per Conductor docs at time of writing:

```json
{
  "scripts": {
    "setup": "string — shell script, runs on workspace create",
    "run":   "string — shell script, triggered by Run button",
    "archive": "string — shell script, runs on archive"
  }
}
```

Exact schema must be confirmed during implementation. If it differs, adjust the setup.sh generator accordingly.

## Testing strategy

The harness lives in an infrastructure repo that doesn't have a conventional test suite. Verification is manual + scripted-smoke:

1. **Unit-ish:** `bin/conductor-status` and `bin/conductor-dispatch` get shell test scripts in `bin/tests/` that assert round-trip behavior (set a field, read it back; dispatch a mock plan to a temp URL instead of opening).
2. **Integration (manual):**
   - Create a fresh throwaway Conductor workspace in a test repo.
   - Run `/plan-sprint` against a fixture goals doc with 3 projects (2 independent, 1 dependent).
   - Verify wave detection output.
   - Accept dispatch offer; confirm 2 workspaces open.
   - In each child, run `/build <plan>`.
   - From any sibling, verify `conductor-context.sh` shows the others' phases correctly.
   - Ship both Wave 1 projects, confirm `/plan-sprint` re-run dispatches Wave 2.
3. **`/harness-health` extension:** add a probe that checks `conductor.json` exists, `bin/conductor-status` is executable, and the hook is wired.

## Failure modes and fallbacks

| Failure | Handling |
|---|---|
| User not on macOS | `bin/conductor-dispatch` detects via `uname`, prints the deep link for manual copy-paste instead of running `open`. |
| Workspace not under `~/conductor/workspaces/` | `conductor-context.sh` silently no-ops. Harness continues to work in plain git clones. |
| Sibling's `.context/conductor-status.json` malformed | Skip that sibling; log to `.claude/logs/failures.jsonl` via the existing failure hook. |
| Conductor Todos API unreachable | `/build` logs and continues; status file is authoritative. |
| `conductor.json` schema changes | Setup wizard fails early with a message pointing at docs; user can hand-edit. |
| Two Wave-1 plans claim the same file | `/plan-sprint` marks them both `Parallel-safe: no`, keeps them in separate waves. |

## Migration / rollout

- All changes are additive. Existing `/plan-sprint` + `/build` behavior is preserved when the new features aren't used.
- Version bump in `VERSION` to `0.3.0`.
- README section added describing the Conductor integration.
- No breaking changes for harness users not on Conductor.
