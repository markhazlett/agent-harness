import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { checkProtectedFile } from "./check.js";
import { loadHarnessConfig } from "../_lib/config.js";
import { findProjectRoot, getHooksConfigPath } from "../_lib/paths.js";

export default function (pi: ExtensionAPI) {
  const root = findProjectRoot(process.cwd());
  const cfg = loadHarnessConfig(getHooksConfigPath(root));

  pi.on("tool_call", async (event) => {
    if (!["edit", "write", "multi_edit"].includes(event.toolName)) return;
    const input = event.input as {
      file_path?: string;
      path?: string;
    };
    const path = input?.file_path ?? input?.path ?? "";
    if (!path) return;
    return checkProtectedFile(path, cfg);
  });
}
