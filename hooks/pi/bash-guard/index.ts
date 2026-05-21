import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { checkBashCommand } from "./check.js";
import { loadHarnessConfig } from "../_lib/config.js";
import { findProjectRoot, getHooksConfigPath } from "../_lib/paths.js";

export default function (pi: ExtensionAPI) {
  const root = findProjectRoot(process.cwd());
  const cfg = loadHarnessConfig(getHooksConfigPath(root));

  pi.on("tool_call", async (event) => {
    if (event.toolName !== "bash") return;
    const cmd = (event.input as { command?: string })?.command ?? "";
    return checkBashCommand(cmd, cfg);
  });
}
