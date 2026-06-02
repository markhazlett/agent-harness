import { execFileSync } from "node:child_process";

/**
 * Send a macOS notification via osascript. Title and message are escaped
 * for safe insertion into the AppleScript string literal — embedded
 * backslashes and double quotes are escaped. Failures (e.g. osascript
 * missing) are swallowed so notifications never break agent flow.
 */
export function notify(title: string, message: string): void {
  const safeTitle = escapeForAppleScript(title);
  const safeMessage = escapeForAppleScript(message);
  const script = `display notification "${safeMessage}" with title "${safeTitle}"`;
  try {
    execFileSync("osascript", ["-e", script], { stdio: "ignore" });
  } catch {
    // Best-effort. Never let notifications block or break the agent.
  }
}

function escapeForAppleScript(s: string): string {
  return s.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}
