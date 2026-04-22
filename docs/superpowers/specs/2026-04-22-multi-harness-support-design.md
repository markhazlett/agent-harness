# Multi-Harness Support — Design

**Date:** 2026-04-22
**Author:** Mark Hazlett
**Status:** Draft — awaiting review

## Motivation

The Agent Harness currently assumes Conductor as the workspace host. A developer who uses plain Claude Code (no Conductor) can install the harness and it mostly works — most skills silently skip Conductor-specific phases when helpers are missing — but three surfaces still steer them toward Conductor or report false failures:

1. `setup.sh` offers to generate `conductor.json` and chmods Conductor helper scripts by default, with only a single `Y/n` prompt to opt out.
2. `/harness-health` prints `FAIL:` for every Conductor probe when Conductor helpers are absent, making a healthy Claude Code install look broken.
3. `README.md` leads with Conductor as a first-class feature rather than as an activation layer on top of a Claude-Code-first install.

The trigger for this work: a user's colleague works in plain Claude Code and wants to adopt the harness. Friction in the three surfaces above would make that adoption feel second-class.

## Goals

- A developer on plain Claude Code can run `setup.sh` and end up with a clean, green `/harness-health` — no Conductor artifacts on disk, no spurious failures.
- An existing Conductor user sees zero behavior change unless they opt to re-run `setup.sh`.
- The README is equally welcoming to both audiences.

## Non-Goals

- Support for additional hosts (Superset, etc.). Out of scope for this change.
- A pluggable host-adapter architecture. Out of scope.
- File or directory renames (`bin/conductor-*`, `.claude/hooks/conductor-context.sh`). The Conductor-prefixed names stay; they describe what the helpers *do*, which is Conductor-specific.
- Skill-file edits. Skills like `plan-sprint` and `build-plan` already have `[ -x bin/conductor-* ]` preconditions; rather than extend those preconditions to also check `HARNESS_HOST`, we make the helpers themselves self-gate (see §4). No `.claude/skills/*.md` or `.claude/commands/*.md` change except `harness-health.md`.
- Migration tooling for existing installs. Re-running `setup.sh` is the documented path.

## Design

### 1. Config model

Add a single field to `.claude/hooks/harness.config.sh`:

```bash
HARNESS_HOST="conductor"   # or "claude-code"
```

**Default selection in `setup.sh`:** if `$HOME/conductor/workspaces` exists or `$CONDUCTOR_WORKSPACES_ROOT` is set in the env, default to `conductor`; otherwise default to `claude-code`.

**Backward compatibility:** when `HARNESS_HOST` is absent from an existing install (e.g. a user who upgrades the harness without re-running `setup.sh`), any code that reads `HARNESS_HOST` treats an empty value as `conductor`. This preserves current behavior for every existing install.

### 2. `setup.sh` changes

- A new **first** prompt asks for the workspace host:

  ```
  Workspace host:
    [1] Conductor (default if ~/conductor detected)
    [2] Claude Code only
  Choice [1]:
  ```

- The remaining prompts (package manager, commands, dev port, DB, required env) are host-agnostic and unchanged.
- The existing Conductor-specific steps — `conductor.json` generation, printing the setup/run/archive summary, and `chmod +x bin/conductor-*` — only execute when `HARNESS_HOST=conductor`. The existing `Y/n` confirmation for `conductor.json` stays, nested inside the Conductor branch.
- The final "Next steps" summary branches on host: Conductor mode shows the Conductor-specific tips as today; Claude Code mode points at `/harness-health` and the planning workflow only.
- `HARNESS_HOST` is written as the first line of the generated `harness.config.sh` body (after the header comment).

### 3. `/harness-health` changes

`.claude/commands/harness-health.md` currently runs eight Conductor probes unconditionally. Convert that block into a conditional:

- When `HARNESS_HOST=claude-code`: each Conductor probe prints `SKIP: <probe name> (host = claude-code)` instead of running.
- When `HARNESS_HOST=conductor` (or unset): probes run exactly as today.

The expected-output section at the bottom of the file documents both branches.

### 4. Helper self-gating and hook wiring

`bin/conductor-status` and `bin/conductor-dispatch` ship as executable (`+x` in git), so the existing `[ -x bin/conductor-* ]` preconditions in `plan-sprint` and `build-plan` do not protect a Claude Code install — the skills would still invoke the helpers, which in plain Claude Code would write stray `.context/conductor-status.json` files and attempt to open `conductor://` URLs with no handler.

Fix at the helper level, not the skill level:

- At the top of each helper (`bin/conductor-status`, `bin/conductor-dispatch`), source `.claude/hooks/harness.config.sh` (if present) and check `HARNESS_HOST`. When `HARNESS_HOST=claude-code`, the helper prints nothing and exits `0` — a silent no-op for both read (`get`, `list`) and write (`update`, dispatch) subcommands.
- Missing/empty `HARNESS_HOST` falls through to normal Conductor behavior (the backward-compat rule from §1).

This keeps every decision about Conductor-ness in one place per helper and lets all downstream skills stay unchanged.

`.claude/hooks/conductor-context.sh` is already self-gating on directory pattern and needs no edit. It stays wired in `settings.json` for both modes — on Claude Code mode it exits 0 immediately, and keeping the wiring single-path avoids a second axis of mode-dependent configuration for `/harness-health` to verify.

### 5. README reshuffle

- **New "Choose your host" subsection** inserted above the existing Quick Start. Two short paragraphs — Conductor (three sentences) and Claude Code (three sentences) — explaining what activates in each mode.
- **Quick Start step 3** is updated:

  _Before:_ `Run ./setup.sh — ask me each prompt it shows (package manager, dev port, DB commands, conductor.json, etc.) and relay my answers`

  _After:_ `Run ./setup.sh — ask me each prompt it shows (workspace host, package manager, dev port, DB commands, etc.) and relay my answers`

- The existing **"Conductor integration"** section stays in place but gets a one-line preface: `Only activates when HARNESS_HOST=conductor (default in a Conductor workspace).`

### 6. Tests

- **New:** `bin/tests/setup-claude-code.test.sh` — drives `setup.sh` non-interactively with host=`claude-code` (piping input through stdin per the existing test pattern). Asserts:
  - `harness.config.sh` contains `HARNESS_HOST="claude-code"`
  - no `conductor.json` exists at the repo root
- **New:** `bin/tests/helper-self-gate.test.sh` — seeds a temporary workspace with `HARNESS_HOST="claude-code"` in `harness.config.sh` and verifies that `bin/conductor-status update foo=bar` and `bin/conductor-dispatch <some-plan>` both exit `0` with empty stdout and do not create `.context/conductor-status.json`. Also verifies that with `HARNESS_HOST=""` (backward-compat) or `HARNESS_HOST="conductor"`, the helpers run normally.
- **Updated:** `bin/tests/setup-conductor-json.test.sh` — assert `HARNESS_HOST="conductor"` is written and the Conductor branch runs as today.
- **Updated:** `bin/tests/conductor-status.test.sh` and `bin/tests/conductor-dispatch.test.sh` — ensure existing cases either seed `HARNESS_HOST="conductor"` or rely on the empty/backward-compat fallthrough, so the self-gating addition doesn't break them.
- **Updated:** `/harness-health` expected-output documentation reflects the `SKIP:` lines in Claude Code mode.

## Open Questions

None.

## Acceptance Criteria

1. On a fresh clone with `$HOME/conductor` absent, running `./setup.sh` with all defaults produces a harness configured for `claude-code`, no `conductor.json`, and a green `/harness-health`.
2. On a fresh clone with `$HOME/conductor/workspaces` present, running `./setup.sh` with all defaults produces a harness configured for `conductor`, a generated `conductor.json`, and a green `/harness-health` identical to today.
3. An existing install with no `HARNESS_HOST` in `harness.config.sh` continues to work unchanged — `/harness-health` behaves as it does today.
4. All existing `bin/tests/*.test.sh` files continue to pass.
