---
name: e2e-verify
description: Use when the user says "verify", "check it", "test it", "e2e", or after completing UI/API changes that need browser-level confirmation before /ship.
user-invocable: true
tier: rigid
kind: verification
---

<update-check>
Run: `bash "$(git rev-parse --show-toplevel)/bin/harness-update-check"`
- `UPGRADE_AVAILABLE <old> <new>` → tell the user: "agent-harness <new> is available (you have <old>). Visit https://github.com/markhazlett/agent-harness to upgrade." Then continue.
- `JUST_UPGRADED <old> <new>` → tell the user: "agent-harness upgraded <old> → <new>." Then continue.
- No output → continue silently.
</update-check>

# E2E Verify (Browser)

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

Visually verify features end-to-end in the browser using the Claude-in-Chrome MCP. Screenshots saved to `/tmp/e2e-screenshots/` (not the repo). The full golden-path is the gate, not the spot-check.

## The Iron Law

```
NO E2E PASS WITHOUT FRESH BROWSER EVIDENCE OF EVERY GOLDEN-PATH STEP
```

For every UI-affecting change, every step of the affected golden path runs in the browser, in this session, against the current branch. "Unchanged code paths" is a story the model tells itself. Each step produces written evidence: page rendered, console clean, interaction worked, navigation moved, data displayed. No evidence = no pass.

## Gate Sequence

1. **Server up.** Confirm `${CONDUCTOR_PORT:-$HARNESS_DEV_PORT}` via `lsof -i :PORT`; hand off to `/dev-server` if needed.
2. **Chrome ready.** `ToolSearch` to load `mcp__claude-in-chrome__tabs_context_mcp`; call with `createIfEmpty: true`; create fresh tab.
3. **Walk golden path.** For each step (page load → interaction → navigation → data render → completion): screenshot before/after, read console (filtered for errors), write per-step evidence.
4. **Per-step verdict.** PASS/FAIL each. Any FAIL = NEEDS FIXES.
5. **Report.** Pages, interactions, console errors, screenshots, verdict.

```bash
mkdir -p /tmp/e2e-screenshots
```

## Red Flags — STOP

- "I already verified the new error path — that's the actual change."
- "The other steps are unchanged code paths."
- "Console errors are noisy in dev anyway."
- "I checked one page, it loaded."
- "Six minutes is too long when the demo is in nine."
- "Unit tests pass — that covers the rest."
- Skipping a golden-path step as "same as last time."
- Reporting PASS without per-step evidence written.

**All of these mean: stop. Walk every step of the golden path before declaring PASS.**

## Common Rationalizations

**REQUIRED SUB-FILE:** Read `rationalizations.md` if you find yourself making excuses. The verbatim-excuse-to-reality table is harvested from the `time-pressure-quick-fix` baseline (subagent surfaced "unchanged code paths is a story I tell myself" as the load-bearing self-deception).

## Self-Review Checklist

- [ ] Every golden-path step has its own PASS/FAIL verdict in the report.
- [ ] Console was checked at each step, not just at the end.
- [ ] Screenshots exist for the start and end of each step.
- [ ] Any console errors are documented (or explicitly "None").
- [ ] Re-runs use a fresh tab, not a stale session.

Cannot check all boxes? NEEDS FIXES. Re-walk the missing step.

## Report Format

Pages verified (URL, status), interactions tested (action → expected, PASS/FAIL), console errors (or "None"), screenshot paths, and an overall verdict (PASS / NEEDS FIXES). Per-step PASS/FAIL is required — overall PASS without per-step evidence is not a verdict.

## What this skill does NOT cover

- Quick spot-checks — that's `/self-verify` (FLEXIBLE, not gate-worthy).
- Visual regression testing across pixel diffs (separate tooling).
- Cross-browser testing (this skill exercises Chrome via the MCP only).
