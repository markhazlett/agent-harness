import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { decideActions } from "./decide-actions.js";
import { loadHarnessConfig } from "../_lib/config.js";
import { findProjectRoot, getHooksConfigPath } from "../_lib/paths.js";

/**
 * Async post-edit: format + lint + (optionally) db migrate on every Edit
 * /Write tool result. Fire-and-forget: no waiting, no result reported back
 * to the agent. Matches hooks/shell/post-edit.sh's "set -uo pipefail" +
 * "|| true" pattern of swallowing all failures.
 */
export default function (pi: ExtensionAPI) {
  const root = findProjectRoot(process.cwd());
  const cfg = loadHarnessConfig(getHooksConfigPath(root));

  pi.on("tool_result", async (event) => {
    const ev = event as { toolName: string; input?: unknown };
    if (!["edit", "write", "multi_edit"].includes(ev.toolName)) return;
    const input = ev.input as { file_path?: string; path?: string };
    const filePath = input?.file_path ?? input?.path ?? "";
    if (!filePath || !existsSync(filePath)) return;

    const actions = decideActions(filePath, root, cfg);

    if (actions.dbGenerate && cfg.HARNESS_DB_GENERATE_CMD) {
      runDetached(cfg.HARNESS_DB_GENERATE_CMD, root);
    }
    if (actions.dbPush && cfg.HARNESS_DB_PUSH_CMD) {
      runDetached(cfg.HARNESS_DB_PUSH_CMD, root);
    }
    if (actions.format) {
      runDetached(`npx prettier --write ${shellEscape(filePath)}`, root);
    }
    if (actions.lint) {
      runDetached(`npx eslint ${shellEscape(filePath)}`, root);
    }
  });
}

function runDetached(cmdLine: string, cwd: string): void {
  // We use sh -c for a single-string command line because npm-style commands
  // expect their full chain (with options). The cmdLine comes from a trusted
  // config file (hooks/config.sh) or a hardcoded prettier/eslint invocation
  // — never from agent input. The filePath was escaped via shellEscape above.
  const child = spawn("sh", ["-c", cmdLine], {
    cwd,
    detached: true,
    stdio: "ignore",
  });
  child.unref();
}

function shellEscape(s: string): string {
  // Single-quote escaping for safe inclusion in an sh -c command.
  return `'${s.replace(/'/g, `'\\''`)}'`;
}
