# Incident Response Protocol — full reference

Loaded on demand from `SKILL.md`. The classification gate, parallel context-gathering steps, and the report template.

## Severity Matrix

| Severity | Criteria | Response |
|----------|----------|----------|
| **SEV-1** | Service down, all users affected, data loss risk | Drop everything. Investigate immediately. |
| **SEV-2** | Major feature broken, many users affected | Investigate now, consider rollback |
| **SEV-3** | Minor feature broken, workaround exists | Investigate, fix in next deploy |
| **SEV-4** | Cosmetic, edge case, low impact | Log and schedule fix |

The classification is the gate. No remediation step (rollback, patch, hotfix) lands before severity is declared *in writing* in the incident channel.

## Gather Context (parallel)

Run these simultaneously to build the incident picture:

**a. Recent changes**

```bash
git log --oneline -20 --since="24 hours ago"
```

Changes in the last 24 hours are prime suspects.

**b. Application state**

- Dev server / production reachable?
- Deployment platform logs (Railway, Vercel, Fly.io, etc.).

**c. Database connectivity**

- Reachable and responsive?
- Recent migration runs or schema changes?

**d. Related code**

- Search the codebase for the affected feature/route/component.
- Read the relevant service, route handler, and component files.
- `git log --oneline -5 -- <file>` for those files.

**e. Application metrics/signals**

- Connected monitoring (PostHog, Datadog, Sentry).
- Correlated errors or traffic spikes.

## Diagnose

From gathered context, identify:

- **Root cause** — what exactly is broken and why.
- **Blast radius** — who is affected, what functionality is degraded.
- **Trigger** — what change or event caused this (deploy, data migration, external service, traffic spike).
- **Timeline** — when did it start, based on logs/commits/signals.

Write the root cause and trigger into the incident channel before any remediation step lands. "I see it in my head" is not naming the cause.

## Remediate (in order of speed)

1. **Immediate mitigation** — reduce impact right now (revert deploy, disable feature flag, add rate limit).
2. **Root cause fix** — the actual code/config change.
3. **Verification** — how to confirm the fix works (test command, URL, metric).

Rollback is a remediation, not a substitute for diagnosis. If you roll back, name the root cause first — otherwise you re-deploy the fix later without knowing what it fixed.

## Report

```
## Incident Report — [date] [time]

### Symptom
[What was reported]

### Severity: SEV-[1-4]

### Timeline
- [time] — First reported
- [time] — Severity declared
- [time] — Root cause hypothesis written
- [time] — [key event]
- [time] — Fix applied / in progress
- [time] — Verified

### Root Cause
[What broke and why, with file:line references]

### Blast Radius
[Who/what is affected, with numbers if possible]

### Immediate Mitigation
[What was done to reduce impact]

### Fix
[Code changes, with specific files and approach]

### Verification
[How the fix was confirmed]

### Prevention
[Test, monitor, or guard that would have caught this earlier]
```

## Execution Rules

- Speed over polish. Get to the root cause fast.
- Check the obvious first: recent deploys, database connectivity, env vars.
- If a rollback is the fastest mitigation, recommend it immediately — but don't execute without user approval, and name the root cause in writing before rolling back.
- NEVER run destructive commands (DROP, DELETE, reset) without explicit user approval.
- After resolution, suggest a monitor or test that would catch this issue earlier next time.
