#!/usr/bin/env bash
# =============================================================================
# setup.sh — Configure the agent harness for your project.
#
# Run this once after copying .claude/ into your project:
#   chmod +x setup.sh && ./setup.sh
#
# What it does:
#   1. Asks configuration questions
#   2. Writes values to .claude/hooks/config.sh
#   3. Makes all hook scripts executable
#   4. Adds .claude/logs/, .claude/handoff/, .claude/transcripts/, .claude/worktrees/
#      to .gitignore (if not already there)
#   5. Prints a summary and next steps
# =============================================================================

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
# CONFIG is assigned below once we know the host (Pi uses .pi/hooks/, the
# Claude/Conductor hosts use .claude/hooks/).
CONFIG=""

echo ""
echo "========================================"
echo "  Agent Harness Setup"
echo "========================================"
echo ""
echo "This will configure the harness for your project."
echo "Press Enter to accept defaults (shown in brackets)."
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Gather inputs
# ──────────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────────
# Workspace host: Conductor (default inside a Conductor workspace) or plain
# Claude Code. Controls whether we generate conductor.json and chmod Conductor
# helpers, and is written to config.sh for runtime mode detection.
# ──────────────────────────────────────────────────────────────────────────────

# Auto-detect default: Conductor if workspaces dir exists or env var set, else claude-code.
if [ -n "${CONDUCTOR_WORKSPACES_ROOT:-}" ] || [ -d "$HOME/conductor/workspaces" ]; then
  HOST_DEFAULT=1
  HOST_DEFAULT_LABEL="Conductor"
else
  HOST_DEFAULT=2
  HOST_DEFAULT_LABEL="Claude Code"
fi

echo "Workspace host:"
echo "  [1] Conductor"
echo "  [2] Claude Code only"
echo "  [3] Pi"
read -p "Choice [${HOST_DEFAULT} = ${HOST_DEFAULT_LABEL}]: " HOST_CHOICE
HOST_CHOICE="${HOST_CHOICE:-$HOST_DEFAULT}"

case "$HOST_CHOICE" in
  1) HARNESS_HOST="conductor" ;;
  2) HARNESS_HOST="claude-code" ;;
  3) HARNESS_HOST="pi" ;;
  *) echo "error: invalid choice '$HOST_CHOICE' — expected 1, 2, or 3" >&2; exit 1 ;;
esac

# Pick install root + config location based on host.
case "$HARNESS_HOST" in
  pi)
    INSTALL_ROOT="$REPO_ROOT/.pi"
    CONFIG="$INSTALL_ROOT/hooks/config.sh"
    mkdir -p "$INSTALL_ROOT/hooks"
    ;;
  *)
    INSTALL_ROOT="$REPO_ROOT/.claude"
    CONFIG="$INSTALL_ROOT/hooks/config.sh"
    ;;
esac

echo "Selected host: $HARNESS_HOST (install root: $INSTALL_ROOT)"
echo ""

read -p "App / project name [My Project]: " APP_NAME
APP_NAME="${APP_NAME:-My Project}"

read -p "Package manager (pnpm/npm/yarn/bun) [pnpm]: " PKG_MGR
PKG_MGR="${PKG_MGR:-pnpm}"

read -p "Source directory pattern (pipe-separated, e.g. src|lib|apps) [src]: " SRC_DIRS
SRC_DIRS="${SRC_DIRS:-src}"

read -p "Test command [${PKG_MGR} test]: " TEST_CMD
TEST_CMD="${TEST_CMD:-${PKG_MGR} test}"

read -p "Typecheck command (blank to skip) [${PKG_MGR} run typecheck]: " TYPECHECK_CMD
TYPECHECK_CMD="${TYPECHECK_CMD:-${PKG_MGR} run typecheck}"

read -p "Lint command [${PKG_MGR} run lint]: " LINT_CMD
LINT_CMD="${LINT_CMD:-${PKG_MGR} run lint}"

read -p "Format command [${PKG_MGR} run format]: " FORMAT_CMD
FORMAT_CMD="${FORMAT_CMD:-${PKG_MGR} run format}"

read -p "Build command [${PKG_MGR} run build]: " BUILD_CMD
BUILD_CMD="${BUILD_CMD:-${PKG_MGR} run build}"

read -p "Dev server command [${PKG_MGR} run dev]: " DEV_CMD
DEV_CMD="${DEV_CMD:-${PKG_MGR} run dev}"

read -p "Dev server port (project default; \$CONDUCTOR_PORT overrides at runtime inside Conductor) [3000]: " DEV_PORT
DEV_PORT="${DEV_PORT:-3000}"

read -p "Lockfile name [${PKG_MGR}-lock.yaml]: " LOCK_FILE
LOCK_FILE="${LOCK_FILE:-${PKG_MGR}-lock.yaml}"
# Normalize common lock file names
case "$PKG_MGR" in
  npm)  LOCK_FILE="${LOCK_FILE:-package-lock.json}" ;;
  yarn) LOCK_FILE="${LOCK_FILE:-yarn.lock}" ;;
  bun)  LOCK_FILE="${LOCK_FILE:-bun.lockb}" ;;
esac

echo ""
echo "Database setup (press Enter to skip if no DB):"
read -p "DB schema file path (relative to repo root, e.g. src/db/schema.ts) [blank]: " DB_SCHEMA
read -p "DB generate command (e.g. ${PKG_MGR} run db:generate) [blank]: " DB_GENERATE
read -p "DB push command (e.g. ${PKG_MGR} run db:push) [blank]: " DB_PUSH
read -p "DB migrations directory (e.g. prisma/migrations) [blank]: " DB_MIGRATIONS

echo ""
read -p "Required env vars for pre-deploy check (space-separated, e.g. DATABASE_URL API_KEY) [blank]: " REQUIRED_ENV

echo ""
echo "LangGraph skill set (opt-in):"
echo "  Adds /lg-design, /lg-scaffold, /lg-add, /lg-eval, /lg-review,"
echo "  and /lg-cheatsheet for building LangChain/LangGraph agents."
read -p "Enable? [y/N]: " LG_CHOICE
LG_CHOICE="${LG_CHOICE:-N}"
case "$LG_CHOICE" in
  [Yy]*) HARNESS_LANGGRAPH="true" ;;
  *)     HARNESS_LANGGRAPH="false" ;;
esac

# ──────────────────────────────────────────────────────────────────────────────
# Write config.sh
# ──────────────────────────────────────────────────────────────────────────────

cat > "$CONFIG" <<EOF
#!/usr/bin/env bash
# =============================================================================
# config.sh — Project-specific configuration for the agent harness.
# Generated by setup.sh on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Edit directly to update values.
# =============================================================================

HARNESS_HOST="${HARNESS_HOST}"
HARNESS_PKG_MGR="${PKG_MGR}"
HARNESS_SRC_DIRS="${SRC_DIRS}"
HARNESS_TEST_CMD="${TEST_CMD}"
HARNESS_TYPECHECK_CMD="${TYPECHECK_CMD}"
HARNESS_LINT_CMD="${LINT_CMD}"
HARNESS_FORMAT_CMD="${FORMAT_CMD}"
HARNESS_BUILD_CMD="${BUILD_CMD}"
HARNESS_APP_NAME="${APP_NAME}"
HARNESS_DEV_PORT="${DEV_PORT}"
HARNESS_DEV_CMD="${DEV_CMD}"
HARNESS_DEV_PROCESS="node"
HARNESS_LOCK_FILE="${LOCK_FILE}"
HARNESS_DB_SCHEMA_PATH="${DB_SCHEMA:-}"
HARNESS_DB_GENERATE_CMD="${DB_GENERATE:-}"
HARNESS_DB_PUSH_CMD="${DB_PUSH:-}"
HARNESS_DB_MIGRATIONS_DIR="${DB_MIGRATIONS:-}"
HARNESS_FORMATTABLE_EXTS="ts|tsx|js|jsx|json|css"
HARNESS_REQUIRED_ENV_VARS="${REQUIRED_ENV:-}"
HARNESS_LANGGRAPH="${HARNESS_LANGGRAPH}"
EOF

echo "Wrote $CONFIG"

# ──────────────────────────────────────────────────────────────────────────────
# Generate conductor.json (Conductor mode only)
# ──────────────────────────────────────────────────────────────────────────────

if [ "$HARNESS_HOST" = "conductor" ]; then
  echo ""
  read -p "Generate conductor.json for Conductor workspace scripts? [Y/n]: " GEN_CONDUCTOR
  GEN_CONDUCTOR="${GEN_CONDUCTOR:-Y}"

  if [[ "$GEN_CONDUCTOR" =~ ^[Yy]$ ]]; then
    CONDUCTOR_JSON="$REPO_ROOT/conductor.json"

    # Compose setup script: install deps, then copy .env.example if present,
    # then run DB generate + push if configured.
    SETUP_LINES=("${PKG_MGR} install")
    if [ -f "$REPO_ROOT/.env.example" ]; then
      SETUP_LINES+=("if [ ! -f .env ]; then cp .env.example .env; fi")
    fi
    if [ -n "${DB_GENERATE:-}" ]; then
      SETUP_LINES+=("${DB_GENERATE}")
    fi
    if [ -n "${DB_PUSH:-}" ]; then
      SETUP_LINES+=("${DB_PUSH}")
    fi
    # Join with &&
    SETUP_SCRIPT=$(printf "%s && " "${SETUP_LINES[@]}")
    SETUP_SCRIPT="${SETUP_SCRIPT% && }"

    # Run script: bind the dev server to the workspace's assigned port.
    # CONDUCTOR_PORT is expanded at runtime so each workspace gets its own port;
    # falls back to the configured default when running outside a Conductor
    # workspace. Most modern dev servers (Next.js, Vite) honor PORT env var.
    RUN_SCRIPT="PORT=\${CONDUCTOR_PORT:-${DEV_PORT}} ${DEV_CMD}"

    # Archive script: stop dev server on the workspace's assigned port + clean
    # build artifacts. CONDUCTOR_PORT is expanded at archive time so each
    # workspace kills its own dev server; falls back to the configured default
    # when running outside a Conductor workspace.
    ARCHIVE_SCRIPT="PIDS=\$(lsof -ti:\${CONDUCTOR_PORT:-${DEV_PORT}} 2>/dev/null || true); [ -n \"\$PIDS\" ] && kill -TERM \$PIDS 2>/dev/null || true; rm -rf node_modules .next .turbo dist build .cache"

    # Write conductor.json via jq for safe quoting.
    jq -n \
      --arg setup "$SETUP_SCRIPT" \
      --arg run "$RUN_SCRIPT" \
      --arg archive "$ARCHIVE_SCRIPT" \
      '{scripts: {setup: $setup, run: $run, archive: $archive}}' > "$CONDUCTOR_JSON"

    echo "Wrote $CONDUCTOR_JSON"
    echo ""
    echo "  setup:   $SETUP_SCRIPT"
    echo "  run:     $RUN_SCRIPT"
    echo "  archive: $ARCHIVE_SCRIPT"
    echo ""
    echo "Review and edit conductor.json before committing — the archive script"
    echo "removes build artifacts aggressively. Adjust for your stack."
  fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# Install target tree (skills + prompts + agents + hooks/extensions)
# ──────────────────────────────────────────────────────────────────────────────

if [ "$HARNESS_HOST" = "pi" ]; then
  install_pi_target() {
    echo "Installing Pi target into $INSTALL_ROOT/..."
    mkdir -p "$INSTALL_ROOT/skills" "$INSTALL_ROOT/prompts" \
             "$INSTALL_ROOT/agents" "$INSTALL_ROOT/extensions" \
             "$INSTALL_ROOT/hooks" "$INSTALL_ROOT/handoff" \
             "$INSTALL_ROOT/logs" "$INSTALL_ROOT/transcripts"

    # Copy canonical content into the .pi/ tree.
    [ -d "$REPO_ROOT/skills" ]    && cp -R "$REPO_ROOT/skills/." "$INSTALL_ROOT/skills/"
    [ -d "$REPO_ROOT/prompts" ]   && cp -R "$REPO_ROOT/prompts/." "$INSTALL_ROOT/prompts/"
    [ -d "$REPO_ROOT/agents" ]    && cp -R "$REPO_ROOT/agents/." "$INSTALL_ROOT/agents/"
    [ -d "$REPO_ROOT/hooks/pi" ]  && cp -R "$REPO_ROOT/hooks/pi/." "$INSTALL_ROOT/extensions/"
    # Config was written by the wizard step above directly at $CONFIG
    # ($INSTALL_ROOT/hooks/config.sh), so no separate copy needed.

    # Generate .pi/settings.json
    cat > "$INSTALL_ROOT/settings.json" <<JSON
{
  "skills": ["./.pi/skills/*/SKILL.md"],
  "prompts": ["./.pi/prompts/*.md"],
  "extensions": ["./.pi/extensions/*/index.ts"],
  "defaultProvider": "anthropic",
  "defaultModel": "claude-sonnet-4-20250514",
  "theme": "dark"
}
JSON
    echo "Wrote $INSTALL_ROOT/settings.json"

    # Install npm dependencies for the extensions (best-effort).
    if [ -f "$INSTALL_ROOT/extensions/package.json" ]; then
      if command -v pnpm >/dev/null 2>&1; then
        (cd "$INSTALL_ROOT/extensions" && pnpm install --silent) || true
      elif command -v npm >/dev/null 2>&1; then
        (cd "$INSTALL_ROOT/extensions" && npm install --silent) || true
      else
        echo "WARNING: neither pnpm nor npm found — install dependencies in $INSTALL_ROOT/extensions/ manually."
      fi
    fi

    echo "Pi target installed."
  }
  install_pi_target
else
  chmod +x "$REPO_ROOT/.claude/hooks/"*.sh 2>/dev/null || true
  echo "Made hooks executable"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Update .gitignore
# ──────────────────────────────────────────────────────────────────────────────

GITIGNORE="$REPO_ROOT/.gitignore"
touch "$GITIGNORE"

add_gitignore() {
  local pattern="$1"
  if ! grep -qF "$pattern" "$GITIGNORE"; then
    echo "$pattern" >> "$GITIGNORE"
    echo "Added $pattern to .gitignore"
  fi
}

echo "" >> "$GITIGNORE"
echo "# Agent harness — ephemeral files" >> "$GITIGNORE"
if [ "$HARNESS_HOST" = "pi" ]; then
  add_gitignore ".pi/logs/"
  add_gitignore ".pi/handoff/"
  add_gitignore ".pi/transcripts/"
  add_gitignore ".pi/extensions/node_modules/"
else
  add_gitignore ".claude/logs/"
  add_gitignore ".claude/handoff/"
  add_gitignore ".claude/transcripts/"
  add_gitignore ".claude/worktrees/"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Verify settings.json exists (Claude/Conductor only — Pi generates its own)
# ──────────────────────────────────────────────────────────────────────────────

if [ "$HARNESS_HOST" != "pi" ] && [ ! -f "$REPO_ROOT/.claude/settings.json" ]; then
  echo "WARNING: .claude/settings.json not found. Copy it from the agent-harness repo."
fi

# ──────────────────────────────────────────────────────────────────────────────
# Instructions file: CLAUDE.md for Claude/Conductor hosts, AGENTS.md for Pi.
# Pi natively reads AGENTS.md; Claude Code reads CLAUDE.md. We never overwrite
# an existing instructions file.
# ──────────────────────────────────────────────────────────────────────────────

if [ "$HARNESS_HOST" = "pi" ]; then
  TARGET_FILE="$REPO_ROOT/AGENTS.md"
  TARGET_LABEL="AGENTS.md"
else
  TARGET_FILE="$REPO_ROOT/CLAUDE.md"
  TARGET_LABEL="CLAUDE.md"
fi
TEMPLATE="$REPO_ROOT/AGENTS.md.template"

if [ -f "$TEMPLATE" ]; then
  if [ -f "$TARGET_FILE" ]; then
    echo ""
    echo "$TARGET_LABEL already exists at the repo root — keeping it as-is."
    echo "Starter template (with the 12 behavior rules) is at:"
    echo "  AGENTS.md.template"
    echo "Review it and merge sections marked [REQUIRED] or [RECOMMENDED] as needed."
  else
    read -p "No $TARGET_LABEL found. Copy the harness starter template? [Y/n]: " COPY_CHOICE
    COPY_CHOICE="${COPY_CHOICE:-Y}"
    case "$COPY_CHOICE" in
      [Yy]*)
        cp "$TEMPLATE" "$TARGET_FILE"
        echo "Wrote $TARGET_FILE. Fill in the {{...}} placeholders for your project."
        ;;
      *)
        echo "Skipped $TARGET_LABEL. Template available at AGENTS.md.template when you're ready."
        ;;
    esac
  fi
fi

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────

echo ""
echo "========================================"
echo "  Setup complete!"
echo "========================================"
echo ""
echo "Configuration written to: .claude/hooks/config.sh"
echo ""
echo "Next steps:"
echo "  1. Review .claude/hooks/config.sh and adjust if needed"
echo "  2. Add .claude/settings.json to your project if not already there"
echo "  3. Review CLAUDE.md (or merge from .claude/docs/claude-md-template.md)"
echo "  4. Run: claude /harness-health"
echo "     to verify everything is wired up correctly"
echo ""
if [ "$HARNESS_HOST" = "conductor" ]; then
  echo "Conductor workspace scripts written to: conductor.json"
  echo "Review and edit conductor.json before committing."
  echo ""
fi
echo "Workflow:"
echo "  /weekly-goals  → /demo-script → /plan-sprint → /build → /sync"
echo ""
