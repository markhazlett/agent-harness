# Risk Surfaces — /ship

Files and paths whose presence in a diff should trigger the pre-pipeline risk-check question. Loaded on demand from `SKILL.md`.

## Auth/session

- `src/auth/`
- `src/session*`
- Any path matching `auth|session|token|login|logout|impersonate`

## Schema/migrations

- `HARNESS_DB_SCHEMA_PATH` (the configured schema file)
- `HARNESS_DB_MIGRATIONS_DIR` (the configured migrations directory)
- Any path matching `migration|schema\.(ts|sql|prisma)`

## Deploy config

- `.github/workflows/`
- `Dockerfile*`, `docker-compose*`
- `vercel.json`, `netlify.toml`, `wrangler*.toml`, `fly.toml`, `serverless.yml`
- `.env.*`

## Hooks

- `.claude/hooks/` — these guard the harness; modifying them affects every future run.

When any of the above appears in the diff, ask the user once:

> "Did you run `/pre-deploy`? This diff touches `<surface>` — recommend running it before push."

Don't auto-fire `/pre-deploy`. Just ask. Continue when the user responds.
