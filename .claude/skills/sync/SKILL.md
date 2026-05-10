---
name: sync
description: Use when the user says "/sync", "pull main", "sync with main", or "get latest". Switches to main and pulls the latest from remote.
user-invocable: true
tier: util
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Run `/harness-update` to pull it in." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Sync

Run `git checkout main && git pull` to switch back to the main branch and pull the latest changes.
