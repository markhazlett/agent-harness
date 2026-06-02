import matter from "gray-matter";

export interface ParsedAgent {
  model?: string;
  tools?: string[];
  systemPrompt: string;
}

/**
 * Parse an agent markdown file with YAML frontmatter into a ParsedAgent.
 *
 * Recognized frontmatter keys: `model`, `tools` (array of tool names).
 * Any other keys are ignored. The body becomes the systemPrompt.
 */
export function parseAgentFile(content: string): ParsedAgent {
  const parsed = matter(content);
  const data = parsed.data as { model?: string; tools?: unknown };
  return {
    model: typeof data.model === "string" ? data.model : undefined,
    tools:
      Array.isArray(data.tools) &&
      data.tools.every((t) => typeof t === "string")
        ? (data.tools as string[])
        : undefined,
    systemPrompt: parsed.content.trim(),
  };
}
