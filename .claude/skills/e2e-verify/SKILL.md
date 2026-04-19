<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# E2E Verify (Browser)

Visually verify features end-to-end in the browser using the Claude-in-Chrome MCP. Screenshots are saved to `/tmp/e2e-screenshots/` (not the repo) to avoid repo bloat.

Trigger: after completing UI or API changes, or when the user says "verify", "check it", "test it", "e2e".

## Steps

1. **Ensure dev server is running** — check with:
   ```bash
   # Inside a Conductor workspace the dev server binds to $CONDUCTOR_PORT;
   # outside it falls back to $HARNESS_DEV_PORT from .claude/hooks/harness.config.sh.
   lsof -i :${CONDUCTOR_PORT:-$HARNESS_DEV_PORT}
   ```
2. **Load Chrome tools** — use `ToolSearch` to load `mcp__claude-in-chrome__tabs_context_mcp` first, then other tools as needed
3. **Get tab context** — call `tabs_context_mcp` with `createIfEmpty: true`
4. **Create a fresh tab** — use `tabs_create_mcp` for this session (don't reuse existing tabs)
5. **Navigate** to the relevant page(s) for the feature being verified
6. **Screenshot before interactions** — capture the initial state
7. **Test interactions** — fill forms, click buttons, select dropdowns, submit
8. **Screenshot after interactions** — capture results
9. **Check for errors** — read console messages with pattern filter for errors
10. **Report findings** — summarize what works, what's broken, include screenshot references

## Screenshot Storage

```bash
mkdir -p /tmp/e2e-screenshots
```

Save screenshots here — these are ephemeral and won't pollute the git repo.

## Common Checks

- Forms submit without errors
- New data appears in lists after creation
- Navigation works (links, back buttons)
- Status indicators show correct state
- No console errors or unhandled promise rejections
- Loading states appear and resolve correctly

## Report Format

```
## E2E Verification Report

### Pages Verified
| Page | Status | Notes |
|------|--------|-------|
| [URL] | PASS/FAIL | |

### Interactions Tested
- [action] → [expected result]: PASS/FAIL

### Console Errors
- [errors or "None"]

### Screenshots
- [screenshot path] — [description]

### Verdict: PASS / NEEDS FIXES
[Summary of what was verified and any issues]
```
