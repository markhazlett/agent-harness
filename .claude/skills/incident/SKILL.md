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

Structured incident response for production issues. Severity classification → context-gathering → root-cause hypothesis → remediation → verification → report. The discipline gates the fix on the classification, not the other way around.

## The Iron Law

```
NO INCIDENT FIX WITHOUT SEVERITY CLASSIFICATION AND ROOT-CAUSE NAMED
```

Before any patch ships or any rollback executes, two things exist *in writing* in the incident channel: a severity (SEV-1 to SEV-4) and a 1–2 line root-cause hypothesis. "I see the diff in my head" is not naming the cause. Rollback is a remediation, not an exemption — name the cause first.

## Gate Sequence

**REQUIRED SUB-FILE:** Read `response-protocol.md` for the severity matrix, context-gathering steps, and report template.

1. **Classify.** Severity declared in writing. SEV-1/2 drops everything. No fix lands before this.
2. **Gather context (parallel).** Recent changes, app state, DB, related code, monitoring.
3. **Diagnose.** Write root cause + blast radius + trigger + timeline.
4. **Remediate.** Mitigation → root-cause fix → verification. Rollback allowed; rollback-without-cause is not.
5. **Report.** Timeline + root cause + mitigation + fix + verification + prevention.

## Red Flags — STOP

- "Just patch it."
- "We'll write it up after."
- "I already know the cause" (without writing it down).
- "Severity classification is paperwork."
- "Roll back first, diagnose later."
- "I can do the formal write-up tomorrow."
- VP / on-call lead said skip the gate.
- Pushing the fix before SEV is declared in the channel.

**All of these mean: stop. Declare severity and write the root-cause hypothesis before any remediation lands.**

## Common Rationalizations

**REQUIRED SUB-FILE:** Read `rationalizations.md` if you find yourself making excuses. The verbatim-excuse-to-reality table is harvested from a real `incident-rush-fix` baseline (the subagent rolled back without classifying or naming the cause).

## Self-Review Checklist

- [ ] Severity is declared in writing in the incident channel before remediation.
- [ ] Root-cause hypothesis (1–2 lines, with file:line if known) is written before the fix or rollback lands.
- [ ] Blast radius is documented (who is affected, with numbers if possible).
- [ ] Verification step is explicit (test, URL, metric to watch).
- [ ] Report includes timeline, root cause, mitigation, fix, prevention.

Cannot check all boxes? The incident is not closed. Finish the report before claiming resolution.

## What this skill does NOT cover

- **The actual fix.** Once root cause is named, hand off to `/tdd` or `/debug` for the implementation.
- **Postmortem facilitation.** Schedule that as a separate meeting; this skill closes when the report is filed.
- **Status page updates.** Coordinate via the comms lead; outside the technical loop here.
