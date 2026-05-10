---
name: self-verify
description: Use when the user says "check the UI", "verify changes", "does it look right", or after completing UI work — quick browser spot-check (not a deploy gate; that is /e2e-verify).
user-invocable: true
tier: flexible
kind: verification
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Run `/harness-update` to pull it in." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# Self-Verify (Browser)

Visually verify UI changes using the browser. Use when the user says "check the UI", "verify changes", "does it look right", or after completing UI work.

## Steps

1. **Ensure dev server is running** — reference the `dev-server` skill if needed. Check port with `lsof -i :${CONDUCTOR_PORT:-$HARNESS_DEV_PORT}` (inside a Conductor workspace the dev server binds to `CONDUCTOR_PORT`; outside it uses `HARNESS_DEV_PORT`)
2. **Navigate** to the relevant page (default: `http://localhost:${CONDUCTOR_PORT:-$HARNESS_DEV_PORT}`)
3. **Check browser console** for errors or warnings
4. **Visually verify** that changes render correctly
5. **Test basic interactions** — click buttons, fill forms, navigate links
6. **Report findings** — what looks correct, any issues found

## Tools

Use Claude-in-Chrome MCP tools (`mcp__claude-in-chrome__*`) or Playwright (`mcp__playwright__*`) for browser automation.

Load tools with `ToolSearch` before first use.

## What to Check

- Page renders without blank screens or layout breaks
- New UI elements appear in the correct location
- Interactive elements respond correctly (buttons, forms, dropdowns)
- No JavaScript errors in the browser console
- Navigation links work
- Data loads and displays correctly

## Report Format

```
## Self-Verify Report

### Page: [URL]

**Rendering:** PASS/FAIL
**Interactions:** PASS/FAIL
**Console errors:** None / [list errors]

### Findings
- [finding]

### Verdict: PASS / NEEDS FIXES
```
