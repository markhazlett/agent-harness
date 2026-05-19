import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { buildReinjectContext } from "./build-reinject.js";
import { findProjectRoot } from "../_lib/paths.js";

/**
 * Equivalent of hooks/shell/context-reinject.sh.
 *
 * Pi has no direct equivalent of Claude Code's SessionStart(resume) event;
 * we fire on session_compact (the harness's analogous post-compaction
 * lifecycle event). The next before_agent_start handler chain receives the
 * appended context block; init's handler also fires every turn and includes
 * the full block, so this reinject's block is only relevant if init isn't
 * loaded (e.g., user disabled it).
 *
 * To keep behavior identical to the shell hook on Pi, we set a flag on
 * compaction and inject via before_agent_start on the NEXT turn.
 */
export default function (pi: ExtensionAPI) {
  const root = findProjectRoot(process.cwd());
  let pendingReinject = false;

  pi.on("session_compact", async () => {
    pendingReinject = true;
  });

  pi.on("before_agent_start", async (event) => {
    if (!pendingReinject) return;
    pendingReinject = false;
    const block = buildReinjectContext({ projectRoot: root });
    if (!block) return;
    return {
      systemPrompt: `${event.systemPrompt}\n\n---\n\n${block}`,
    };
  });
}
