import { describe, it, expect } from "vitest";
import { formatFailureEntry } from "../format.js";

describe("formatFailureEntry", () => {
  it("produces a single-line JSON", () => {
    const line = formatFailureEntry({
      toolName: "bash",
      input: { command: "exit 1" },
      error: "exit code 1",
      timestamp: new Date("2026-05-18T12:00:00Z"),
    });
    expect(line.includes("\n")).toBe(false);
    expect(() => JSON.parse(line)).not.toThrow();
  });

  it("includes all four fields with expected names", () => {
    const line = formatFailureEntry({
      toolName: "edit",
      input: { file_path: "/tmp/foo.ts" },
      error: "permission denied",
      timestamp: new Date("2026-01-01T00:00:00Z"),
    });
    const obj = JSON.parse(line);
    expect(obj.ts).toBe("2026-01-01T00:00:00.000Z");
    expect(obj.tool).toBe("edit");
    expect(obj.input).toEqual({ file_path: "/tmp/foo.ts" });
    expect(obj.error).toBe("permission denied");
  });

  it("safely handles complex input objects (no JSON escape issues)", () => {
    const line = formatFailureEntry({
      toolName: "bash",
      input: { command: 'echo "hello \\ world"' },
      error: "exit 1",
      timestamp: new Date(),
    });
    const obj = JSON.parse(line);
    expect(obj.input.command).toBe('echo "hello \\ world"');
  });
});
