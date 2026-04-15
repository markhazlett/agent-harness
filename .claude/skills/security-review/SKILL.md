# Security Review

Comprehensive security audit before production deployment. Covers the full attack surface: authentication, authorization, injection, credential handling, data isolation, client-side security, infrastructure, and dependency health.

Trigger: before production deploys, when the user says "security review", "audit security", "check for vulnerabilities", "is this secure?", or before any `/ship` to a production branch. Also run proactively when changes touch auth, credentials, raw SQL, API routes, or external integrations.

**Before starting:** Read `CLAUDE.md` to understand the project's tech stack, auth provider, ORM, and API layer — this shapes what to check in each phase.

## Audit Scope

This review covers 15 security domains. Each produces PASS, WARN, or FAIL with file:line references and specific remediation. The review is designed to be re-run — after fixes, re-run the full audit to confirm resolution.

---

## Phase 1: Secrets & Exposure

### 1.1 Hardcoded Secrets Scan

Search the entire codebase (excluding `node_modules/`, `.git/`, `.env*`, `*.lock`) for:

```
Patterns to grep:
- API key prefixes: sk-, pk_, phx_, pa-, key-, token-, secret-
- Connection strings: postgres://, mysql://, redis://, mongodb://
- Base64-encoded secrets: strings >40 chars matching [A-Za-z0-9+/=]
- AWS patterns: AKIA[0-9A-Z]{16}
- Generic: password\s*=, secret\s*=, apikey\s*=, api_key\s*=
```

For each match, verify it's a placeholder, test value, or documentation — not a real credential. FAIL on any real credential in source code.

### 1.2 Environment Variable Isolation

**Server-only variables must never reach the client bundle.**

- Grep client-side code for `process.env.` references
- Any server-side secret referenced in client code is a FAIL
- Check for `NEXT_PUBLIC_` (Next.js), `VITE_` (Vite), or framework-specific public var prefixes
- Known-safe public vars should be documented in CLAUDE.md

### 1.3 Gitignore Verification

Confirm these are gitignored:
- `.env`, `.env.local`, `.env.production`, `.env.*.local`
- `*.pem`, `*.key`, `*.p12`
- `credentials.json`, `service-account.json`

### 1.4 Environment Documentation

- Verify `.env.example` or `.env.template` exists
- Cross-reference all `process.env.*` references in code against the template
- WARN if any env var used in code is missing from the template (undocumented dependency)

---

## Phase 2: SQL Injection & Query Safety

### 2.1 Raw SQL Inventory

Find every raw SQL execution point. These bypass ORM protections:

```bash
grep -rn "\.execute(" src/
grep -rn "sql\`" src/
grep -rn "\.raw(" src/
grep -rn "knex.raw\|db.raw\|prisma.\$queryRaw" src/
```

For each match, verify it's necessary and safe.

### 2.2 Parameterization Verification

For each raw SQL call:
1. Verify parameterized queries are used (no string concatenation with user input)
2. Check for `.raw()` bypass methods — FAIL if user input can reach these
3. Check for dynamic table/column names from user input
4. Verify inputs are validated/sanitized before use in queries

### 2.3 ORM Query Audit

Spot-check ORM queries for:
- Multi-tenant workspace/organization isolation — are all queries filtered by tenant ID?
- `LIKE`/`ILIKE` with user input — is the pattern properly escaped?
- `.limit()` and `.offset()` — are they bounded? Unbounded queries risk DoS.

---

## Phase 3: Authentication & Session Security

### 3.1 Route Protection Matrix

Build a complete map of every route and its auth requirement:
- Which routes are public? (only login, landing pages, public APIs)
- Which routes require authentication? Verify middleware/guards are applied
- FAIL if any authenticated route is accessible without auth

### 3.2 API Endpoint Audit

For every API endpoint:
- Verify authentication is checked before processing
- Verify authorization (can this user perform this action?) is checked
- FAIL if any state-changing endpoint processes requests without authentication

### 3.3 Session & Cookie Security

- Verify session cookies are: `HttpOnly`, `Secure` (in production), `SameSite=Lax` or `Strict`
- Check session expiry configuration
- Verify logout properly invalidates the session (not just clearing the cookie client-side)

### 3.4 Cron/Webhook Endpoint Authentication

- Verify automated endpoints (cron jobs, webhooks) validate a shared secret
- Check for timing-safe string comparison (constant-time to prevent timing attacks)
- WARN if using simple `===` comparison — recommend `crypto.timingSafeEqual()`

---

## Phase 4: Authorization & Data Isolation

### 4.1 Tenant/Workspace Isolation (CRITICAL for multi-tenant apps)

**This is the most important authorization check.** Every database query that returns user data MUST filter by tenant/workspace ID. A missing filter means cross-tenant data leakage.

Systematically check each data access layer:
- Every query that returns rows must include a tenant filter
- JOIN queries: both sides must be tenant-scoped or one must be reached through a scoped parent
- CTEs in complex queries: each CTE must include tenant filtering independently

FAIL on ANY query that returns data without tenant filtering.

### 4.2 Object-Level Authorization

Beyond tenant isolation, check:
- Can users access resources they don't own within their tenant?
- Are there role-based access controls that need enforcement?
- Are admin-only operations gated correctly?

### 4.3 IDOR Prevention

- Verify that IDs in URLs/request bodies are validated against the current user's ownership
- Check for sequential integer IDs that could be enumerated — prefer UUIDs

---

## Phase 5: Input Validation & Injection

### 5.1 API Input Schema Coverage

For every API endpoint, verify:
- Input validation exists (Zod, Joi, class-validator, etc.)
- No use of `any` type for user-supplied data
- String fields have `.max()` length limits
- ID fields validate as UUIDs where appropriate
- Array inputs have `.max()` length limits
- Enum inputs validate against an explicit allowed list

### 5.2 LLM Output as Input (if using AI)

If the project feeds LLM outputs back into the system:
- Verify LLM output is treated as untrusted data
- Check that LLM output is not used to construct SQL queries without validation
- Check that LLM output rendered in the UI goes through normal React/framework escaping

### 5.3 File Upload Validation (if applicable)

- Verify file size limits are enforced server-side
- Verify content type whitelist exists
- Check for path traversal in filenames (`../`, null bytes)
- Verify file content is validated after upload

---

## Phase 6: Credential & Secret Management

### 6.1 Encryption Implementation (if storing credentials)

- Verify algorithm: AES-256-GCM preferred (provides authenticated encryption)
- Verify IV is randomly generated per encryption (not reused)
- Verify encryption key comes from environment variables, not hardcoded
- WARN if using CBC without HMAC (vulnerable to padding oracle attacks)

### 6.2 Credential Lifecycle

- **Storage:** Encrypted at rest — verify
- **Display:** API responses must never return raw credentials — verify masking
- **Deletion:** When disconnected, credentials are deleted (not just soft-deleted)
- **Logging:** Credentials are never logged

---

## Phase 7: Transport & Network Security

### 7.1 Security Headers

Check `next.config.ts`, `vercel.json`, nginx config, etc. for:

| Header | Expected Value | Risk if Missing |
|--------|---------------|-----------------|
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains` | MITM attacks |
| `Content-Security-Policy` | Restrictive policy | XSS amplification |
| `X-Content-Type-Options` | `nosniff` | MIME sniffing |
| `X-Frame-Options` | `DENY` or `SAMEORIGIN` | Clickjacking |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | URL leakage |

WARN for each missing header. FAIL if `Strict-Transport-Security` is missing in production config.

### 7.2 CORS Configuration

- Check for `Access-Control-Allow-Origin` headers
- WARN if `*` origin is allowed on any authenticated endpoint
- Verify preflight handling for any HTTP APIs

### 7.3 TLS & Connection Security

- Verify database connections use SSL in production
- Verify external API calls use HTTPS

---

## Phase 8: Client-Side Security

### 8.1 XSS Prevention

React/Vue/modern frameworks provide baseline XSS protection, but check for bypasses:

- Grep for raw HTML injection APIs (e.g., `__html` props in React) — each use must be justified with a sanitization library (DOMPurify, etc.)
- Grep for direct `innerHTML` assignment in vanilla JS — these bypass framework sanitization
- Verify rich text editor output is rendered through the editor's own sanitization layer
- Check URL rendering — verify `href`/`src` attributes validate protocol (no `javascript:` URLs)
- Check AI-generated or user-provided content rendering — ensure it goes through framework escaping

### 8.2 CSRF Protection

- Verify state-changing endpoints are protected by SameSite cookies, CSRF tokens, or custom headers
- Verify state-changing GET requests don't exist (GET should be idempotent)

### 8.3 Sensitive Data in Client State

- No tokens, credentials, or secrets in localStorage/sessionStorage
- Verify API responses don't include fields that should be server-only

---

## Phase 9: Rate Limiting & Abuse Prevention

### 9.1 Document Existing Rate Limits

List all current rate limiting implementations.

### 9.2 Check for Missing Rate Limits

| Endpoint Type | Risk Without Limit | Recommended Limit |
|---------------|-------------------|-------------------|
| Auth endpoints | Brute force | 10/min per IP |
| LLM-calling endpoints | API cost abuse | 10-20/min per user |
| File upload | Storage abuse | 20/hour per user |
| Data mutations | Resource exhaustion | 30/min per user |
| Public search | Scraping | 60/min per IP |

FAIL if LLM-calling or file-upload endpoints have no rate limiting (direct cost exposure).

### 9.3 Resource Limits

- Verify unbounded queries don't exist — all user-controlled limits are capped
- Verify streaming endpoints have timeout limits

---

## Phase 10: Dependency Security

### 10.1 Vulnerability Scan

```bash
pnpm audit   # or npm audit / yarn audit
```

| Severity | Action |
|----------|--------|
| CRITICAL | FAIL — must fix before deploy |
| HIGH | FAIL — must fix or document accepted risk |
| MODERATE | WARN — fix in next cycle |
| LOW | INFO — note for awareness |

### 10.2 Dependency Hygiene

- Check for outdated major versions of security-critical packages (auth library, ORM, framework)
- Verify lockfile is committed (reproducible builds)
- Check for `file:` or `link:` dependencies that bypass registry

---

## Phase 11: Error Handling & Information Disclosure

### 11.1 Error Response Audit

- Verify error handlers strip stack traces in production
- Verify catch blocks return generic messages, not raw `error.message` or `error.stack`
- Verify database errors are wrapped (no raw DB error messages to clients)

### 11.2 Logging Safety

- Grep for `console.log` near sensitive operations (credential decrypt, auth, SQL)
- Verify no sensitive data is logged: API keys, passwords, full SQL queries with parameters

---

## Phase 12: Infrastructure Security

### 12.1 Database Security

- Verify database connection uses SSL in production
- Check if database user has minimal required privileges (not superuser)
- Verify connection pool limits (prevent connection exhaustion)

### 12.2 Object Storage (if applicable)

- Verify storage bucket is not publicly accessible
- Verify presigned URLs have reasonable expiry (1 hour or less)

---

## Phase 13: AI-Specific Security (if using LLMs)

### 13.1 Prompt Injection Defenses

For each LLM pipeline:
- Verify system prompts clearly separate instructions from user content
- Verify user content is demarcated (XML tags or clear delimiters)
- Check if LLM output is used to make tool calls — could a crafted input manipulate tool selection?
- WARN if any pipeline allows LLM output to influence SQL queries, file operations, or external API calls without validation

### 13.2 Cost Controls

- Verify LLM calls have `maxTokens` limits set
- Check for per-user/workspace rate limiting on AI endpoints
- Verify no runaway loops are possible in agent pipelines

### 13.3 Data Sent to External AI Services

Document what data is sent to Anthropic, OpenAI, etc.:
- Verify no credentials, API keys, or internal infrastructure details are sent
- WARN if PII is sent without user awareness

---

## Phase 14: Business Logic Security

### 14.1 State Machine Integrity

- Identify state machines in the app (document status, order status, etc.)
- Verify state transitions are validated server-side (can't skip states)
- Verify only authorized transitions are allowed

### 14.2 Idempotency

- Verify mutation endpoints are safe against double-submission
- Check for race conditions on concurrent operations

---

## Phase 15: Compliance Readiness

### 15.1 Data Handling

- Verify user data deletion is possible (GDPR right to erasure)
- Check if workspace/account deletion cascades properly

### 15.2 Audit Trail

- Verify security-relevant actions are logged:
  - Credential creation/deletion
  - Permission changes
  - Resource state changes

---

## Output Format

```
## Security Review — [date] — [commit hash]

### Severity Summary
| Level | Count | Status |
|-------|-------|--------|
| CRITICAL | X | Must fix before deploy |
| HIGH | X | Fix before deploy |
| MEDIUM | X | Fix soon |
| LOW | X | Noted |
| PASS | X | Verified secure |

### Critical Findings (Deploy Blockers)
| # | Finding | Location | Remediation |
|---|---------|----------|-------------|
| 1 | [description] | file:line | [specific fix] |

### High Findings
...

### Medium Findings
...

### Low Findings / Notes
...

### Phase Results
| Phase | Status | Notes |
|-------|--------|-------|
| 1. Secrets & Exposure | PASS/WARN/FAIL | |
| 2. SQL Injection | PASS/WARN/FAIL | |
| 3. Authentication | PASS/WARN/FAIL | |
| 4. Authorization & Isolation | PASS/WARN/FAIL | |
| 5. Input Validation | PASS/WARN/FAIL | |
| 6. Credential Management | PASS/WARN/FAIL | |
| 7. Transport & Network | PASS/WARN/FAIL | |
| 8. Client-Side Security | PASS/WARN/FAIL | |
| 9. Rate Limiting | PASS/WARN/FAIL | |
| 10. Dependencies | PASS/WARN/FAIL | |
| 11. Error Handling | PASS/WARN/FAIL | |
| 12. Infrastructure | PASS/WARN/FAIL | |
| 13. AI-Specific | PASS/WARN/FAIL | N/A if no AI |
| 14. Business Logic | PASS/WARN/FAIL | |
| 15. Compliance | PASS/WARN/FAIL | |

### Verdict: DEPLOY / DO NOT DEPLOY
[Rationale]
```

---

## Known Vulnerability History

Track previously found and fixed vulnerabilities here so future reviews can verify they haven't regressed:

| Date | Finding | Severity | Status |
|------|---------|----------|--------|
| (add entries as found) | | | |

---

## Execution Rules

- NEVER skip a phase. If a phase doesn't apply, mark it N/A with reason
- NEVER auto-fix security issues without user approval — report them with specific remediation
- READ the actual code, don't just grep for patterns. Context matters for security
- If any CRITICAL or HIGH finding exists, verdict is DO NOT DEPLOY
- After fixes, re-run the FULL audit — don't spot-check. Fixes can introduce new issues
- Document every finding even if it's a false positive — explain WHY it's safe
- When in doubt, flag it. False positives are cheap; missed vulnerabilities are not
