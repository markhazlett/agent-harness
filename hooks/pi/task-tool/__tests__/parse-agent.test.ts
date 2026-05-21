import { describe, it, expect } from "vitest";
import { parseAgentFile } from "../parse-agent.js";

describe("parseAgentFile", () => {
  it("extracts model + tools from frontmatter and body as systemPrompt", () => {
    const raw = `---
model: opus
tools:
  - read
  - bash
  - edit
---
You are a reviewer. Be terse.`;
    const p = parseAgentFile(raw);
    expect(p.model).toBe("opus");
    expect(p.tools).toEqual(["read", "bash", "edit"]);
    expect(p.systemPrompt).toBe("You are a reviewer. Be terse.");
  });

  it("returns undefined model/tools when not specified", () => {
    const p = parseAgentFile(`---\n---\nHello there.`);
    expect(p.model).toBeUndefined();
    expect(p.tools).toBeUndefined();
    expect(p.systemPrompt).toBe("Hello there.");
  });

  it("works with no frontmatter at all", () => {
    const p = parseAgentFile(`Just a body.`);
    expect(p.model).toBeUndefined();
    expect(p.tools).toBeUndefined();
    expect(p.systemPrompt).toBe("Just a body.");
  });

  it("ignores non-string model and non-array tools", () => {
    const raw = `---
model: 42
tools: "read"
---
Body.`;
    const p = parseAgentFile(raw);
    expect(p.model).toBeUndefined();
    expect(p.tools).toBeUndefined();
  });

  it("parses the real builder.md from agents/", () => {
    const builderMd = `---
model: sonnet
---

# Builder Agent

You are a builder agent.`;
    const p = parseAgentFile(builderMd);
    expect(p.model).toBe("sonnet");
    expect(p.systemPrompt).toContain("Builder Agent");
  });
});
