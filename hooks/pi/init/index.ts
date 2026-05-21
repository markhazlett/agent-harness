import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { buildSessionContext } from "./build-context.js";
import { findProjectRoot } from "../_lib/paths.js";

/**
 * Equivalent of hooks/shell/init.sh.
 *
 * Per R3 research finding (docs/superpowers/specs/2026-05-18-pi-harness-research.md),
 * the `before_agent_start` handler receives the assembled system prompt in
 * `event.systemPrompt` and can return `{ systemPrompt: ... }` to replace
 * it for that turn. Multiple extensions chain by each reading the previous
 * result.
 *
 * We compute the session-context block once (cheap) and append it to the
 * system prompt on every turn. The model only needs to see it on the first
 * turn; subsequent turns just re-paste the same block, which is harmless.
 */
export default function (pi: ExtensionAPI) {
  const root = findProjectRoot(process.cwd());
  const contextBlock = buildSessionContext({ projectRoot: root });

  pi.on("before_agent_start", async (event) => {
    if (!contextBlock) return;
    return {
      systemPrompt: `${event.systemPrompt}\n\n---\n\n${contextBlock}`,
    };
  });
}
