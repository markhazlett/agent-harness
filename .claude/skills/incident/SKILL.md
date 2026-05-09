---
name: incident
description: Use when the user reports a production problem — "users can't log in", "500 errors", "the site is down", "something broke", "getting errors on [page]", "incident", or "production issue". Drives structured triage → diagnosis → remediation.
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

# Incident

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

Structured incident response for production issues. Takes a symptom, investigates systematically, and produces a diagnosis with remediation steps.

Trigger: when the user reports a production problem — "users can't log in", "500 errors", "the site is down", "something broke", "getting errors on [page]", "incident", "production issue".

## Response Protocol

### 1. Acknowledge & Classify

Immediately classify severity:

| Severity | Criteria | Response |
|----------|----------|----------|
| **SEV-1** | Service down, all users affected, data loss risk | Drop everything. Investigate immediately. |
| **SEV-2** | Major feature broken, many users affected | Investigate now, consider rollback |
| **SEV-3** | Minor feature broken, workaround exists | Investigate, fix in next deploy |
| **SEV-4** | Cosmetic, edge case, low impact | Log and schedule fix |

### 2. Gather Context (Parallel)

Run these simultaneously to build the incident picture:

**a. Recent changes**
```bash
git log --oneline -20 --since="24 hours ago"
```
What shipped recently? Changes in the last 24 hours are prime suspects.

**b. Application state**
- Check if the dev server / production is reachable
- Check deployment platform logs (Railway, Vercel, Fly.io, etc.)

**c. Database connectivity**
- Check if the database is reachable and responsive
- Look for recent migration runs or schema changes

**d. Related code**
- Search the codebase for the affected feature/route/component
- Read the relevant service, route handler, and component files
- Check for recent changes to those files: `git log --oneline -5 -- <file>`

**e. Application metrics/signals**
- Check any connected monitoring (PostHog, Datadog, Sentry, etc.) for anomalies
- Look for correlated errors or traffic spikes

### 3. Diagnose

Based on gathered context, identify:

- **Root cause** — what exactly is broken and why
- **Blast radius** — who is affected, what functionality is degraded
- **Trigger** — what change or event caused this (deploy, data migration, external service, traffic spike)
- **Timeline** — when did it start, based on logs/commits/signals

### 4. Remediate

Propose fixes in order of speed:

1. **Immediate mitigation** — can we reduce impact right now? (revert deploy, disable feature flag, add rate limit)
2. **Root cause fix** — the actual code/config change needed
3. **Verification** — how to confirm the fix works (test command, URL to check, metric to watch)

### 5. Report

Output a structured incident report:

```
## Incident Report — [date] [time]

### Symptom
[What the user reported]

### Severity: SEV-[1-4]

### Timeline
- [time] — First reported
- [time] — [key event]
- [time] — Root cause identified
- [time] — Fix applied / in progress

### Root Cause
[What broke and why, with file:line references]

### Blast Radius
[Who/what is affected]

### Immediate Mitigation
[What was done to reduce impact]

### Fix
[Code changes needed, with specific files and approach]

### Verification
[How to confirm the fix works]

### Prevention
[What would prevent this class of issue in the future — test, monitor, guard]
```

## Rules

- Speed over polish. Get to the root cause fast
- Check the obvious first: recent deploys, database connectivity, env vars
- If a rollback is the fastest mitigation, recommend it immediately (but don't execute without user approval)
- NEVER run destructive commands (DROP, DELETE, reset) without explicit user approval
- If the issue is in production and you can't access logs, tell the user what to check and what to look for
- After resolution, suggest a monitor or test that would catch this issue earlier next time
