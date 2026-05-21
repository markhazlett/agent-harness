import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { currentBranch, isDirty } from "../_lib/git.js";

export interface BuildContextOptions {
  projectRoot: string;
}

/**
 * Build the session-context block to inject into the agent's system prompt
 * at session start. Mirrors hooks/shell/init.sh's output sections:
 *   - Branch (with warning on main/master)
 *   - Recent commits (last 5)
 *   - Uncommitted changes (git status --short)
 *   - Handoff notes (.pi/handoff/latest.md, if present)
 *
 * Returns a single multi-line string. Empty sections are omitted.
 */
export function buildSessionContext(opts: BuildContextOptions): string {
  const parts: string[] = [];
  parts.push("=== Session Context ===");

  const branch = safe(() => currentBranch(opts.projectRoot), "detached");
  parts.push(`Branch: ${branch}`);
  if (branch === "main" || branch === "master") {
    parts.push(
      `WARNING: You are on ${branch} — switch to a feature branch before making changes.`,
    );
  }

  const commits = safe(
    () =>
      execFileSync("git", ["log", "--oneline", "-5"], {
        cwd: opts.projectRoot,
      })
        .toString()
        .trim(),
    "",
  );
  if (commits) {
    parts.push("");
    parts.push("Recent commits:");
    parts.push(commits);
  }

  if (safe(() => isDirty(opts.projectRoot), false)) {
    const status = safe(
      () =>
        execFileSync("git", ["status", "--short"], { cwd: opts.projectRoot })
          .toString()
          .trim(),
      "",
    );
    if (status) {
      parts.push("");
      parts.push("Uncommitted changes:");
      parts.push(status);
    }
  }

  const handoffPath = join(opts.projectRoot, ".pi", "handoff", "latest.md");
  if (existsSync(handoffPath)) {
    parts.push("");
    parts.push("=== Handoff Notes ===");
    parts.push(readFileSync(handoffPath, "utf8").trim());
  }

  return parts.join("\n");
}

function safe<T>(fn: () => T, fallback: T): T {
  try {
    return fn();
  } catch {
    return fallback;
  }
}
