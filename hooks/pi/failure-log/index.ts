import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { appendFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { formatFailureEntry } from "./format.js";
import { findProjectRoot } from "../_lib/paths.js";

export default function (pi: ExtensionAPI) {
  const root = findProjectRoot(process.cwd());
  const logDir = join(root, ".pi", "logs");
  mkdirSync(logDir, { recursive: true });
  const logPath = join(logDir, "failures.jsonl");

  pi.on("tool_result", async (event) => {
    const ev = event as {
      toolName: string;
      input?: unknown;
      error?: unknown;
    };
    if (!ev.error) return;
    const line = formatFailureEntry({
      toolName: ev.toolName,
      input: ev.input ?? {},
      error: String(ev.error),
      timestamp: new Date(),
    });
    appendFileSync(logPath, line + "\n");
  });
}
