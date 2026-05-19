import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createAgentSession } from "@earendil-works/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join } from "node:path";
import { parseAgentFile } from "./parse-agent.js";
import { findProjectRoot, getAgentsDir } from "../_lib/paths.js";

/**
 * Custom `task` tool — Pi's equivalent of Claude Code's native Task tool.
 *
 * Discovers agent definitions at .pi/agents/<name>.md, registers a tool that
 * accepts a subagent_type (enum of discovered names) + a prompt, and dispatches
 * to a fresh agent session via createAgentSession (confirmed in research log
 * R1: `@earendil-works/pi-coding-agent` v0.75.3 exports the API at the
 * documented import path).
 *
 * Returns the sub-agent's final message text. Streaming sub-agent progress
 * back to the parent is post-MVP.
 */
export default function (pi: ExtensionAPI) {
  const root = findProjectRoot(process.cwd());
  const agentsDir = getAgentsDir(root);

  if (!existsSync(agentsDir)) {
    // No agents/ tree — skip registering the tool entirely.
    return;
  }

  const agents = readdirSync(agentsDir)
    .filter((f) => f.endsWith(".md"))
    .map((f) => f.slice(0, -3));

  if (agents.length === 0) {
    return;
  }

  pi.registerTool({
    name: "task",
    label: "Task (subagent)",
    description:
      "Dispatch a sub-agent for an isolated multi-step task. Returns the sub-agent's final message text.",
    promptSnippet: "task — dispatch a sub-agent for an isolated task",
    promptGuidelines: [
      "Use task when you need an isolated context for a focused multi-step task.",
      "Pick subagent_type based on the task: builder for implementation, validator for review, e2e-tester for browser checks, migration-validator for DB schema work.",
    ],
    parameters: Type.Object({
      subagent_type: Type.Union(
        agents.map((a) => Type.Literal(a)) as [
          ReturnType<typeof Type.Literal>,
          ...ReturnType<typeof Type.Literal>[],
        ],
      ),
      description: Type.String({
        description: "Short label shown in UI while the sub-agent runs.",
      }),
      prompt: Type.String({
        description: "Full task brief for the sub-agent.",
      }),
    }),

    async execute(_toolCallId, params, signal, onUpdate, _ctx) {
      const typed = params as {
        subagent_type: string;
        description: string;
        prompt: string;
      };
      const agentPath = join(agentsDir, `${typed.subagent_type}.md`);
      const { model, tools, systemPrompt } = parseAgentFile(
        readFileSync(agentPath, "utf8"),
      );

      onUpdate?.({
        content: [
          {
            type: "text",
            text: `Spawning ${typed.subagent_type}: ${typed.description}…`,
          },
        ],
      });

      const result = await createAgentSession({
        systemPrompt,
        ...(model ? { model } : {}),
        ...(tools ? { tools } : {}),
        ...(signal ? { signal } : {}),
      });

      const { session } = result;
      await session.prompt(typed.prompt);
      const text = session.getLastAssistantText?.() ?? "";

      return {
        content: [{ type: "text", text }],
        details: {
          subagent_type: typed.subagent_type,
          description: typed.description,
        },
      };
    },
  });
}
