import { describe, it, expect, vi } from "vitest";

vi.mock("node:child_process", async () => {
  const actual =
    await vi.importActual<typeof import("node:child_process")>(
      "node:child_process",
    );
  return {
    ...actual,
    execFileSync: vi.fn(),
  };
});

import { execFileSync } from "node:child_process";
import { notify } from "../notify.js";

describe("notify", () => {
  it("invokes osascript with -e and an AppleScript string", () => {
    const spy = vi.mocked(execFileSync);
    spy.mockClear();
    notify("Test title", "Test message");
    expect(spy).toHaveBeenCalledTimes(1);
    const [cmd, args] = spy.mock.calls[0];
    expect(cmd).toBe("osascript");
    expect(args).toEqual(["-e", expect.any(String)]);
    const script = (args as string[])[1];
    expect(script).toContain("display notification");
    expect(script).toContain("Test title");
    expect(script).toContain("Test message");
  });

  it("escapes embedded double quotes in title and message", () => {
    const spy = vi.mocked(execFileSync);
    spy.mockClear();
    notify('a "b" c', 'x"y"z');
    const script = (spy.mock.calls[0][1] as string[])[1];
    expect(script).toContain('\\"b\\"');
    expect(script).toContain('\\"y\\"');
  });

  it("escapes embedded backslashes", () => {
    const spy = vi.mocked(execFileSync);
    spy.mockClear();
    notify("a\\b", "c\\d");
    const script = (spy.mock.calls[0][1] as string[])[1];
    expect(script).toContain("a\\\\b");
    expect(script).toContain("c\\\\d");
  });

  it("does not throw if osascript fails", () => {
    const spy = vi.mocked(execFileSync);
    spy.mockImplementationOnce(() => {
      throw new Error("no osascript on this system");
    });
    expect(() => notify("title", "msg")).not.toThrow();
  });
});
