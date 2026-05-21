import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { currentBranch } from "../_lib/git.js";

export interface BuildReinjectOptions {
  projectRoot: string;
}

/**
 * Lighter session-context block for re-injection after compaction or session
 * resume. Mirrors hooks/shell/context-reinject.sh:
 *   - Branch
 *   - Last commit (one line)
 *   - Handoff notes if present
 *
 * Returns a single multi-line string. Empty sections are omitted.
 */
export function buildReinjectContext(opts: BuildReinjectOptions): string {
  const parts: string[] = [];
  parts.push("=== Context (resumed) ===");

  const branch = safe(() => currentBranch(opts.projectRoot), "detached");
  parts.push(`Branch: ${branch}`);

  const lastCommit = safe(
    () =>
      execFileSync("git", ["log", "--oneline", "-1"], {
        cwd: opts.projectRoot,
      })
        .toString()
        .trim(),
    "",
  );
  if (lastCommit) {
    parts.push(`Last commit: ${lastCommit}`);
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
