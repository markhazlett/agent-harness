import { execFileSync } from "node:child_process";

/**
 * Return the currently checked-out git branch name for `cwd` (or the
 * current working directory if not specified).
 */
export function currentBranch(cwd: string = process.cwd()): string {
  return execFileSync("git", ["rev-parse", "--abbrev-ref", "HEAD"], { cwd })
    .toString()
    .trim();
}

/**
 * Return true if the working tree has any uncommitted changes (tracked
 * modifications, deletions, additions, or untracked files).
 */
export function isDirty(cwd: string = process.cwd()): boolean {
  const out = execFileSync("git", ["status", "--porcelain"], {
    cwd,
  }).toString();
  return out.trim().length > 0;
}
