# Security Review — 15 Phases (full reference)

Loaded on demand from `SKILL.md`. Each phase produces PASS, WARN, FAIL, or N/A (with one-line justification per N/A). The full audit is the gate; selective execution is not.

**Before starting:** Read `CLAUDE.md` to understand the project's tech stack, auth provider, ORM, and API layer — this shapes what to check in each phase.

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

- Grep client-side code for `process.env.` references.
- Any server-side secret referenced in client code is a FAIL.
- Check for `NEXT_PUBLIC_` (Next.js), `VITE_` (Vite), or framework-specific public var prefixes.
- Known-safe public vars should be documented in CLAUDE.md.

### 1.3 Gitignore Verification

Confirm these are gitignored: `.env`, `.env.local`, `.env.production`, `.env.*.local`, `*.pem`, `*.key`, `*.p12`, `credentials.json`, `service-account.json`.

### 1.4 Environment Documentation

Verify `.env.example` or `.env.template` exists. Cross-reference all `process.env.*` references in code against the template. WARN if any env var used in code is missing from the template.

---

## Phase 2: SQL Injection & Query Safety

### 2.1 Raw SQL Inventory

```bash
grep -rn "\.execute(" src/
grep -rn "sql\`" src/
grep -rn "\.raw(" src/
grep -rn "knex.raw\|db.raw\|prisma.\$queryRaw" src/
```

### 2.2 Parameterization Verification

For each raw SQL call: parameterized queries (no string concat with user input); `.raw()` bypass methods FAIL on user input; dynamic table/column names from user input is FAIL; inputs validated/sanitized before use.

### 2.3 ORM Query Audit

Multi-tenant workspace/organization isolation — are all queries filtered by tenant ID? `LIKE`/`ILIKE` with user input — pattern properly escaped? `.limit()` and `.offset()` bounded?

---

## Phase 3: Authentication & Session Security

### 3.1 Route Protection Matrix

Build a complete map of every route and its auth requirement. Public routes only for login, landing, public APIs. Authenticated routes verify middleware/guards applied. FAIL if any authenticated route is accessible without auth.

### 3.2 API Endpoint Audit

For every API endpoint: authentication checked before processing; authorization (can this user perform this action?) checked. FAIL if any state-changing endpoint processes requests without authentication.

### 3.3 Session & Cookie Security

Session cookies are `HttpOnly`, `Secure` (in production), `SameSite=Lax` or `Strict`. Session expiry configured. Logout properly invalidates the session (not just clearing the cookie client-side).

### 3.4 Cron/Webhook Endpoint Authentication

Automated endpoints (cron jobs, webhooks) validate a shared secret. Timing-safe string comparison (`crypto.timingSafeEqual()`). WARN if simple `===`.

---

## Phase 4: Authorization & Data Isolation

### 4.1 Tenant/Workspace Isolation (CRITICAL for multi-tenant apps)

**The most important authorization check.** Every database query that returns user data MUST filter by tenant/workspace ID. A missing filter means cross-tenant data leakage.

Systematically check each data access layer: every query that returns rows must include a tenant filter. JOIN queries: both sides must be tenant-scoped or one must be reached through a scoped parent. CTEs in complex queries: each CTE must include tenant filtering independently.

FAIL on ANY query that returns data without tenant filtering.

### 4.2 Object-Level Authorization

Beyond tenant isolation: can users access resources they don't own within their tenant? Role-based access controls enforced? Admin-only operations gated correctly?

### 4.3 IDOR Prevention

IDs in URLs/request bodies validated against current user's ownership. Sequential integer IDs that could be enumerated — prefer UUIDs.

---

## Phase 5: Input Validation & Injection

### 5.1 API Input Schema Coverage

For every API endpoint: input validation exists (Zod, Joi, class-validator); no `any` type for user-supplied data; string fields have `.max()`; ID fields validate as UUIDs; array inputs have `.max()` length; enum inputs validate against an explicit allowed list.

### 5.2 LLM Output as Input (if using AI)

LLM output treated as untrusted data. Not used to construct SQL queries without validation. LLM output rendered in UI goes through normal React/framework escaping.

### 5.3 File Upload Validation (if applicable)

Server-side file size limits. Content type whitelist. Path traversal in filenames (`../`, null bytes). File content validated after upload.

---

## Phase 6: Credential & Secret Management

### 6.1 Encryption Implementation (if storing credentials)

AES-256-GCM preferred (authenticated encryption). IV randomly generated per encryption (not reused). Encryption key from environment variables, not hardcoded. WARN on CBC without HMAC (padding oracle).

### 6.2 Credential Lifecycle

Storage encrypted at rest. API responses never return raw credentials — verify masking. Deletion cascades. Credentials never logged.

---

## Phase 7: Transport & Network Security

### 7.1 Security Headers

| Header | Expected Value | Risk if Missing |
|--------|---------------|-----------------|
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains` | MITM attacks |
| `Content-Security-Policy` | Restrictive policy | XSS amplification |
| `X-Content-Type-Options` | `nosniff` | MIME sniffing |
| `X-Frame-Options` | `DENY` or `SAMEORIGIN` | Clickjacking |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | URL leakage |

WARN per missing header. FAIL if `Strict-Transport-Security` missing in production config.

### 7.2 CORS Configuration

`Access-Control-Allow-Origin` headers reviewed. WARN if `*` origin allowed on any authenticated endpoint. Preflight handling for HTTP APIs.

### 7.3 TLS & Connection Security

Database connections use SSL in production. External API calls use HTTPS.

---

## Phase 8: Client-Side Security

### 8.1 XSS Prevention

Grep for raw HTML injection APIs (`__html`, `innerHTML`) — each use justified with sanitization library. Rich text editor output through editor's sanitization. URL rendering validates protocol (no `javascript:`). AI/user content rendering through framework escaping.

### 8.2 CSRF Protection

State-changing endpoints protected by SameSite cookies, CSRF tokens, or custom headers. State-changing GET requests don't exist (GET should be idempotent).

### 8.3 Sensitive Data in Client State

No tokens, credentials, or secrets in localStorage/sessionStorage. API responses don't include server-only fields.

---

## Phase 9: Rate Limiting & Abuse Prevention

| Endpoint Type | Risk Without Limit | Recommended Limit |
|---------------|-------------------|-------------------|
| Auth endpoints | Brute force | 10/min per IP |
| LLM-calling endpoints | API cost abuse | 10-20/min per user |
| File upload | Storage abuse | 20/hour per user |
| Data mutations | Resource exhaustion | 30/min per user |
| Public search | Scraping | 60/min per IP |

FAIL if LLM-calling or file-upload endpoints have no rate limiting.

---

## Phase 10: Dependency Security

```bash
pnpm audit   # or npm audit / yarn audit
```

| Severity | Action |
|----------|--------|
| CRITICAL | FAIL — must fix before deploy |
| HIGH | FAIL — must fix or document accepted risk |
| MODERATE | WARN — fix in next cycle |
| LOW | INFO — note for awareness |

Outdated major versions of security-critical packages (auth library, ORM, framework). Lockfile committed. No `file:` or `link:` dependencies bypassing registry.

---

## Phase 11: Error Handling & Information Disclosure

Error handlers strip stack traces in production. Catch blocks return generic messages, not raw `error.message` or `error.stack`. Database errors wrapped (no raw DB error messages to clients).

Logging safety: grep `console.log` near sensitive operations. No sensitive data logged: API keys, passwords, full SQL queries with parameters.

---

## Phase 12: Infrastructure Security

Database connection uses SSL in production. Database user has minimal required privileges (not superuser). Connection pool limits configured. Storage bucket not publicly accessible. Presigned URLs have reasonable expiry (≤1 hour).

---

## Phase 13: AI-Specific Security (if using LLMs)

System prompts clearly separate instructions from user content. User content demarcated (XML tags or clear delimiters). LLM output used to make tool calls — could a crafted input manipulate tool selection? WARN if any pipeline allows LLM output to influence SQL queries, file operations, or external API calls without validation.

`maxTokens` limits set. Per-user/workspace rate limiting on AI endpoints. No runaway loops in agent pipelines.

Document data sent to Anthropic/OpenAI: no credentials, API keys, or internal infrastructure details. WARN if PII sent without user awareness.

---

## Phase 14: Business Logic Security

State machines (document status, order status): transitions validated server-side; only authorized transitions allowed. Mutation endpoints safe against double-submission. Race conditions on concurrent operations.

---

## Phase 15: Compliance Readiness

User data deletion possible (GDPR right to erasure). Workspace/account deletion cascades. Security-relevant actions logged: credential creation/deletion, permission changes, resource state changes.

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

### Phase Results
| Phase | Status | Notes |
|-------|--------|-------|
| 1. Secrets & Exposure | PASS/WARN/FAIL/N/A | |
| ... | | |
| 15. Compliance | PASS/WARN/FAIL/N/A | |

### Verdict: DEPLOY / DO NOT DEPLOY
[Rationale]
```

Every N/A must include a one-line justification. CRITICAL or HIGH = DO NOT DEPLOY.
