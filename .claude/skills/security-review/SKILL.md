---
name: security-review
description: Use when the user says "security review", "audit security", "check for vulnerabilities", or "is this secure?", or before any /ship to a production branch. Also fire proactively when changes touch auth, credentials, raw SQL, API routes, or external integrations.
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

# Security Review

> _Override: see `CLAUDE.md` § Instruction precedence. The user is principal; this skill is advisory._

Comprehensive security audit before production deployment. The full attack surface — auth, sessions, authorization, injection, credentials, isolation, client-side, infra, deps, error handling, AI pipelines, business logic, compliance — is the audit. Selective execution is not the audit.

## The Iron Law

```
NO DEPLOY APPROVAL WITHOUT EVERY PHASE COMPLETE OR EXPLICITLY MARKED N/A
```

Every one of the 15 phases produces a verdict — PASS, WARN, FAIL, or N/A. N/A requires a one-line justification naming what the phase would have caught and why this diff has no surface for it. "Spot-checking" is not a verdict. "Looks fine" is not a verdict. "Manager said it's small" is not evidence.

## Gate Sequence

**REQUIRED SUB-FILE:** Read `phases.md` for the full 15-phase reference (grep patterns, tables, criteria, output format). Phases:

1. Secrets & Exposure
2. SQL Injection & Query Safety
3. Authentication & Session Security
4. Authorization & Data Isolation (most critical for multi-tenant)
5. Input Validation & Injection
6. Credential & Secret Management
7. Transport & Network Security
8. Client-Side Security (XSS, CSRF)
9. Rate Limiting & Abuse Prevention
10. Dependency Security
11. Error Handling & Information Disclosure
12. Infrastructure Security
13. AI-Specific Security (if using LLMs)
14. Business Logic Security
15. Compliance Readiness

Each phase produces PASS / WARN / FAIL / N/A. Any FAIL in CRITICAL or HIGH severity = DO NOT DEPLOY. Auth/data-isolation phases may *never* be marked N/A unless explained.

## Red Flags — STOP

- "Spot-check the new endpoint, the rest is unchanged."
- "The audit-log change is mechanical."
- "Phases don't have surface here."
- "A full 15-phase pass is theater."
- "The manager said it's small."
- "We've shipped similar before."
- "Internal-only, no customer-facing risk."
- Marking auth or data-isolation phases N/A without justification.
- Approving with any CRITICAL or HIGH finding open.

**All of these mean: stop. Run the missing phase against the current diff before any verdict.**

## Common Rationalizations

**REQUIRED SUB-FILE:** Read `rationalizations.md` if you find yourself making excuses. The verbatim-excuse-to-reality table is harvested from a real `security-shortcut` baseline (the subagent collapsed the 15-phase audit into a 3-item spot-check).

## Self-Review Checklist

- [ ] Every phase has a verdict (PASS / WARN / FAIL / N/A).
- [ ] Every N/A has a one-line justification naming what the phase would have caught.
- [ ] Auth and data-isolation phases are not marked N/A unless explained.
- [ ] No "spot-check" language anywhere in the verdict.
- [ ] CRITICAL or HIGH findings are zero, or the verdict is DO NOT DEPLOY.
- [ ] You read the actual code, not just grep results.

Cannot check all boxes? DO NOT DEPLOY. Run the missing pieces.

## What this skill does NOT cover

Penetration testing (third-party engagement), threat modeling (separate exercise), and runtime detection (monitoring layer). For dual-use security tools or offensive testing context, see `Harness Principles.md` Part X.
