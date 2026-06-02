import { currentBranch } from "../_lib/git.js";

export interface BashGuardConfig {
  HARNESS_SRC_DIRS?: string;
}

export type BashGuardResult = { block: true; reason: string } | undefined;

/**
 * Pure check function — mirrors the rules in hooks/shell/bash-guard.sh.
 * Returns { block: true, reason } if the command should be blocked,
 * undefined otherwise.
 *
 * Rules (in order):
 *   1. Block `git commit` or `git push` on main/master.
 *   2. Block any `--no-verify`.
 *   3. Block `sed -i` writes into source directories.
 *   4. Block `rm -rf` of source directories.
 *   5. Block redirect overwrites (`> path`) into source directories.
 */
export function checkBashCommand(
  cmd: string,
  cfg: BashGuardConfig,
): BashGuardResult {
  const srcDirs = cfg.HARNESS_SRC_DIRS ?? "src|lib";

  // Rule 1: git commit/push on main or master.
  if (/^\s*git\s+(commit|push)\b/.test(cmd)) {
    const branch = currentBranch();
    if (branch === "main" || branch === "master") {
      return {
        block: true,
        reason: `Cannot commit or push on ${branch} — use a feature branch.`,
      };
    }
  }

  // Rule 2: --no-verify.
  if (/--no-verify\b/.test(cmd)) {
    return {
      block: true,
      reason: "--no-verify is not allowed — hooks must not be skipped.",
    };
  }

  // Rule 3: sed -i on source files.
  if (new RegExp(`sed\\s+-i.*\\s+(${srcDirs})/`).test(cmd)) {
    return {
      block: true,
      reason:
        "sed -i on source files is not allowed — use the Edit tool instead.",
    };
  }

  // Rule 4: rm -rf on source directories.
  if (new RegExp(`rm\\s+-rf\\s+(${srcDirs})/?\\b`).test(cmd)) {
    return {
      block: true,
      reason: "rm -rf on source directories is not allowed.",
    };
  }

  // Rule 5: redirect into source directories.
  if (new RegExp(`>\\s+(${srcDirs})/`).test(cmd)) {
    return {
      block: true,
      reason:
        "Redirect to source files is not allowed — use the Write tool instead.",
    };
  }

  return undefined;
}
