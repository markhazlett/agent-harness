#!/usr/bin/env bash
# =============================================================================
# harness.config.sh — Project-specific configuration for the agent harness.
# All hooks source this file at the top. Edit these values when installing.
# =============================================================================

# Package manager: pnpm | npm | yarn | bun
HARNESS_PKG_MGR="${HARNESS_PKG_MGR:-pnpm}"

# Source directories (pipe-separated regex alternation) watched by hooks.
# Used to guard against destructive shell commands on source files.
# Examples: "src" | "apps|packages" | "src|lib|packages"
HARNESS_SRC_DIRS="${HARNESS_SRC_DIRS:-src}"

# Test command (full command to run tests)
HARNESS_TEST_CMD="${HARNESS_TEST_CMD:-${HARNESS_PKG_MGR} test}"

# Typecheck command — set to empty string "" to skip
HARNESS_TYPECHECK_CMD="${HARNESS_TYPECHECK_CMD:-${HARNESS_PKG_MGR} run typecheck}"

# Lint command
HARNESS_LINT_CMD="${HARNESS_LINT_CMD:-${HARNESS_PKG_MGR} run lint}"

# Format command (write mode)
HARNESS_FORMAT_CMD="${HARNESS_FORMAT_CMD:-${HARNESS_PKG_MGR} run format}"

# Build command
HARNESS_BUILD_CMD="${HARNESS_BUILD_CMD:-${HARNESS_PKG_MGR} run build}"

# Application name (used in system notifications)
HARNESS_APP_NAME="${HARNESS_APP_NAME:-My Project}"

# Dev server port
HARNESS_DEV_PORT="${HARNESS_DEV_PORT:-3000}"

# Dev server start command (used by dev-server skill)
HARNESS_DEV_CMD="${HARNESS_DEV_CMD:-${HARNESS_PKG_MGR} run dev}"

# Dev server process name pattern (for pkill when restarting)
HARNESS_DEV_PROCESS="${HARNESS_DEV_PROCESS:-node}"

# Lockfile to protect from direct edits (auto-generated)
# Examples: pnpm-lock.yaml | yarn.lock | package-lock.json
HARNESS_LOCK_FILE="${HARNESS_LOCK_FILE:-pnpm-lock.yaml}"

# DB schema file path relative to repo root — triggers migration on save.
# Leave empty ("") to disable automatic DB migration.
# Example: "packages/db/src/schema.ts" | "src/db/schema.ts"
HARNESS_DB_SCHEMA_PATH="${HARNESS_DB_SCHEMA_PATH:-}"

# DB generate command (runs when schema file changes)
# Example: "pnpm db:generate" | "npx prisma generate"
HARNESS_DB_GENERATE_CMD="${HARNESS_DB_GENERATE_CMD:-}"

# DB push/migrate command (runs after generate)
# Example: "pnpm db:push" | "npx prisma db push"
HARNESS_DB_PUSH_CMD="${HARNESS_DB_PUSH_CMD:-}"

# DB migrations directory (relative to repo root)
# Example: "packages/db/drizzle" | "prisma/migrations"
HARNESS_DB_MIGRATIONS_DIR="${HARNESS_DB_MIGRATIONS_DIR:-}"

# Glob pattern for files that should trigger format + lint on save
# Default covers JS/TS/JSON/CSS. Adjust for other languages.
HARNESS_FORMATTABLE_EXTS="${HARNESS_FORMATTABLE_EXTS:-ts|tsx|js|jsx|json|css}"

# Additional required env vars for pre-deploy checks (space-separated)
# Example: "DATABASE_URL API_KEY AUTH_SECRET"
HARNESS_REQUIRED_ENV_VARS="${HARNESS_REQUIRED_ENV_VARS:-}"

# Opt-in: enable the LangGraph skill set (/lg-design, /lg-scaffold, /lg-add,
# /lg-eval, /lg-review, /lg-cheatsheet). Skills are visible in the slash menu
# either way; with this set to "false" they print an opt-in hint and exit.
HARNESS_LANGGRAPH="${HARNESS_LANGGRAPH:-false}"

# Sprint complexity budget — max complexity points per sprint.
# Complexity weights: [Build] = 3 pts, [Extend] = 1 pt, [Exists] = 0 pts.
# Default 9 = 3× [Build] items, or 9× [Extend], or any mix.
HARNESS_SPRINT_COMPLEXITY_MAX="${HARNESS_SPRINT_COMPLEXITY_MAX:-9}"

# Minimum independently-verifiable checkpoints per sprint.
# A sprint with fewer checkpoints is flagged as a quality risk.
# A checkpoint = one item with its own demo scene verification or its own PR.
HARNESS_SPRINT_CHECKPOINT_MIN="${HARNESS_SPRINT_CHECKPOINT_MIN:-2}"
