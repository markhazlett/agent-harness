import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFileSync, spawn } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { decideStopActions } from "./decide-stop.js";
import { loadHarnessConfig } from "../_lib/config.js";
import { findProjectRoot, getHooksConfigPath } from "../_lib/paths.js";
import { notify } from "../_lib/notify.js";

/**
 * agent_end equivalent of hooks/shell/stop.sh.
 *
 * Pi's agent_end is observation-only (no return value blocks the end), so
 * we always run actions asynchronously. Results are written to handoff
 * notes so they're visible to the next session.
 */
export default function (pi: ExtensionAPI) {
  const root = findProjectRoot(process.cwd());
  const cfg = loadHarnessConfig(getHooksConfigPath(root));

  pi.on("agent_end", async () => {
    const changed = changedFiles(root);
    const actions = decideStopActions({ changedFiles: changed, cfg });
    const results: string[] = [];

    if (actions.runTests && cfg.HARNESS_TEST_CMD) {
      runDetached(cfg.HARNESS_TEST_CMD, root, "tests");
      results.push("- tests: started (results streamed to terminal)");
    }
    if (actions.runTypecheck && cfg.HARNESS_TYPECHECK_CMD) {
      runDetached(cfg.HARNESS_TYPECHECK_CMD, root, "typecheck");
      results.push("- typecheck: started");
    }
    if (actions.writeHandoff) {
      writeHandoff(root, results);
    }
    if (actions.notify) {
      notify(cfg.HARNESS_APP_NAME ?? "Agent Harness", "Session complete");
    }
  });
}

function changedFiles(cwd: string): string[] {
  try {
    const tracked = execFileSync("git", ["diff", "--name-only", "HEAD"], {
      cwd,
    })
      .toString()
      .split("\n")
      .filter(Boolean);
    const staged = execFileSync("git", ["diff", "--name-only", "--cached"], {
      cwd,
    })
      .toString()
      .split("\n")
      .filter(Boolean);
    return Array.from(new Set([...tracked, ...staged]));
  } catch {
    return [];
  }
}

function writeHandoff(root: string, actionLines: string[]): void {
  const dir = join(root, ".pi", "handoff");
  mkdirSync(dir, { recursive: true });

  let branch = "unknown";
  let lastCommit = "(none)";
  let changedSummary = "  - (none)";
  try {
    branch = execFileSync("git", ["rev-parse", "--abbrev-ref", "HEAD"], {
      cwd: root,
    })
      .toString()
      .trim();
  } catch {}
  try {
    lastCommit = execFileSync("git", ["log", "--oneline", "-1"], { cwd: root })
      .toString()
      .trim();
  } catch {}
  try {
    const diff = execFileSync("git", ["diff", "--name-only", "HEAD~1"], {
      cwd: root,
    })
      .toString()
      .trim();
    if (diff) {
      changedSummary = diff
        .split("\n")
        .map((l) => `  - ${l}`)
        .join("\n");
    }
  } catch {}

  const body = [
    "# Session Handoff",
    `- **Branch:** ${branch}`,
    `- **Last commit:** ${lastCommit || "(none)"}`,
    `- **Changed files:**`,
    changedSummary,
    `- **Timestamp:** ${new Date().toISOString()}`,
    actionLines.length > 0 ? "" : null,
    actionLines.length > 0 ? "**End-of-session actions:**" : null,
    ...actionLines,
    "",
  ]
    .filter((l): l is string => l !== null)
    .join("\n");

  writeFileSync(join(dir, "latest.md"), body);
}

function runDetached(cmdLine: string, cwd: string, label: string): void {
  void label;
  const child = spawn("sh", ["-c", cmdLine], {
    cwd,
    detached: true,
    stdio: "ignore",
  });
  child.unref();
}
