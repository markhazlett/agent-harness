# Conductor reference

Captured: 2026-04-19. Re-run Task 1 of the conductor-integration plan if Conductor changes.

Source pages:
- https://docs.conductor.build/core/scripts
- https://docs.conductor.build/core/conductor-json
- https://docs.conductor.build/core/deep-links
- https://docs.conductor.build/tips/conductor-env

## conductor.json schema

```json
{
  "scripts": {
    "setup":   "<zsh script — runs each time you create a workspace>",
    "run":     "<zsh script — triggered by the Run button>",
    "archive": "<zsh script — runs when archiving a workspace>"
  },
  "runScriptMode": "concurrent",
  "enterpriseDataPrivacy": false
}
```

### Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `scripts` | object | **Yes** | Container for script definitions |
| `scripts.setup` | string | No | Runs when creating a workspace |
| `scripts.run` | string | No | Triggered by the Run button (dev server / main process) |
| `scripts.archive` | string | No | Runs when archiving the workspace (e.g. cleanup) |
| `runScriptMode` | `"concurrent"` \| `"nonconcurrent"` | No | Set to `"nonconcurrent"` to kill any in-progress run script before starting a new one |
| `enterpriseDataPrivacy` | boolean | No | Set to `true` to disable analytics and telemetry data collection |

**Execution:** scripts run under zsh with Conductor env vars available (see below).

**Working directory:** setup script runs inside the newly-created workspace directory.

**Process lifecycle:** on teardown Conductor sends SIGHUP, waits up to 200ms for the process to exit, then sends SIGKILL. Applies to run scripts, setup scripts, and terminal sessions.

**Override precedence:** Repository Settings scripts override `conductor.json` unless personal scripts are cleared first. Commit this file to git for team distribution.

### Minimum viable example

```json
{
  "scripts": {
    "setup": "npm install",
    "run":   "npm run dev"
  }
}
```

## Conductor environment variables

Available in all scripts and terminals:

| Variable | Description |
|----------|-------------|
| `CONDUCTOR_WORKSPACE_NAME` | Workspace name |
| `CONDUCTOR_WORKSPACE_PATH` | Workspace path |
| `CONDUCTOR_ROOT_PATH` | Path to the repository root directory |
| `CONDUCTOR_DEFAULT_BRANCH` | Default branch (typically `main`) |
| `CONDUCTOR_PORT` | First in a range of 10 ports assigned to the workspace |

## Deep link formats

- `conductor://prompt=<encoded-prompt>` — new workspace, first repo, prompt pre-filled
- `conductor://prompt=<encoded-prompt>&path=<repo-path>` — targets a specific repo path; falls back to first repo if path does not match
- `conductor://linear_id=<issue-id>&prompt=<optional-encoded-prompt>` — fetches Linear issue, auto-detects matching repo, navigates to or creates workspace on that issue's branch (requires connected Linear account)
- `conductor://async?repo=<repo-name>&plan=<base64-md>` — creates a workspace with a base64-encoded markdown plan file; `repo` is optional and defaults to first repository

All parameter values must be URL-encoded.

**Format rules:**
- Generic links (`prompt`, `linear_id`): flat `key=value&key=value` directly after `conductor://` — no hostname or path component
- Async links: standard URL structure with hostname (`conductor://async?key=value&...`)
