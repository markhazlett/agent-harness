# Dev Server

Start, stop, and monitor the local development server. Use when the user says "start the dev server", "restart the server", "check the server logs", "what's the server error", or similar.

## Configuration

Read `.claude/hooks/harness.config.sh` for:
- `HARNESS_DEV_CMD` — command to start the dev server (e.g., `pnpm dev`)
- `HARNESS_DEV_PORT` — port the server runs on (default: 3000)
- `HARNESS_DEV_PROCESS` — process name pattern for pkill
- `HARNESS_APP_NAME` — used for log file naming

## Starting the Server

1. Create the logs directory:
   ```bash
   mkdir -p /tmp/${HARNESS_APP_NAME// /-}-logs
   ```

2. Kill any existing dev server to avoid port conflicts:
   ```bash
   pkill -f "$HARNESS_DEV_PROCESS" 2>/dev/null || true
   ```
   Wait 2 seconds for ports to release.

3. Start the dev server in the background using the Bash tool with `run_in_background: true`:
   ```bash
   cd $(git rev-parse --show-toplevel) && $HARNESS_DEV_CMD 2>&1 | tee /tmp/${HARNESS_APP_NAME// /-}-logs/dev.log
   ```

4. Tell the user:
   - The server is running in the background
   - They can watch logs with: `tail -f /tmp/<app-name>-logs/dev.log`
   - You can check logs anytime via TaskOutput

## Checking Logs

When asked about server errors or logs, use TaskOutput to read the background task output. Also check:
```bash
tail -100 /tmp/<app-name>-logs/dev.log
```

## Restarting the Server

1. Stop the current background task (TaskStop)
2. Follow the "Starting the Server" steps above

## Stopping the Server

1. Stop the background task (TaskStop)
2. Clean up:
   ```bash
   pkill -f "$HARNESS_DEV_PROCESS" 2>/dev/null || true
   ```
