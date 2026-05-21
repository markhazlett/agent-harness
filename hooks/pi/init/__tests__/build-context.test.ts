import { describe, it, expect, vi, beforeEach } from "vitest";

const {
  mockBranch,
  mockIsDirty,
  mockExecFileSync,
  mockExistsSync,
  mockReadFileSync,
} = vi.hoisted(() => ({
  mockBranch: vi.fn(() => "feature/x"),
  mockIsDirty: vi.fn(() => false),
  mockExecFileSync: vi.fn(),
  mockExistsSync: vi.fn(() => false),
  mockReadFileSync: vi.fn(() => ""),
}));

vi.mock("../../_lib/git.js", () => ({
  currentBranch: () => mockBranch(),
  isDirty: () => mockIsDirty(),
}));

vi.mock("node:child_process", async () => {
  const actual =
    await vi.importActual<typeof import("node:child_process")>(
      "node:child_process",
    );
  return { ...actual, execFileSync: mockExecFileSync };
});

vi.mock("node:fs", async () => {
  const actual = await vi.importActual<typeof import("node:fs")>("node:fs");
  return {
    ...actual,
    existsSync: (...args: unknown[]) => mockExistsSync(...args),
    readFileSync: (...args: unknown[]) => mockReadFileSync(...args),
  };
});

import { buildSessionContext } from "../build-context.js";

describe("buildSessionContext", () => {
  beforeEach(() => {
    mockBranch.mockReturnValue("feature/auth");
    mockIsDirty.mockReturnValue(false);
    mockExistsSync.mockReturnValue(false);
    mockExecFileSync.mockReturnValue(Buffer.from(""));
  });

  it("includes branch on a clean tree", () => {
    const ctx = buildSessionContext({ projectRoot: "/proj" });
    expect(ctx).toContain("Branch: feature/auth");
    expect(ctx).not.toContain("WARNING");
  });

  it("warns when on main", () => {
    mockBranch.mockReturnValue("main");
    const ctx = buildSessionContext({ projectRoot: "/proj" });
    expect(ctx).toContain("WARNING");
    expect(ctx).toContain("main");
  });

  it("warns when on master", () => {
    mockBranch.mockReturnValue("master");
    expect(buildSessionContext({ projectRoot: "/proj" })).toContain("WARNING");
  });

  it("includes recent commits when git log produces output", () => {
    mockExecFileSync.mockImplementation((cmd, args) => {
      if (Array.isArray(args) && args.includes("log")) {
        return Buffer.from("abc1234 fix bug\ndef5678 add feature\n");
      }
      return Buffer.from("");
    });
    const ctx = buildSessionContext({ projectRoot: "/proj" });
    expect(ctx).toContain("Recent commits:");
    expect(ctx).toContain("abc1234");
    expect(ctx).toContain("def5678");
  });

  it("includes uncommitted changes when dirty", () => {
    mockIsDirty.mockReturnValue(true);
    mockExecFileSync.mockImplementation((cmd, args) => {
      if (Array.isArray(args) && args.includes("status")) {
        return Buffer.from(" M src/app.ts\n M README.md\n");
      }
      return Buffer.from("");
    });
    const ctx = buildSessionContext({ projectRoot: "/proj" });
    expect(ctx).toContain("Uncommitted changes:");
    expect(ctx).toContain("src/app.ts");
    expect(ctx).toContain("README.md");
  });

  it("includes handoff notes when handoff file exists", () => {
    mockExistsSync.mockImplementation((p) => {
      return typeof p === "string" && p.endsWith("handoff/latest.md");
    });
    mockReadFileSync.mockImplementation((p) => {
      if (typeof p === "string" && p.endsWith("handoff/latest.md")) {
        return "Previous session left auth flow half-implemented.";
      }
      return "";
    });
    const ctx = buildSessionContext({ projectRoot: "/proj" });
    expect(ctx).toContain("Handoff Notes");
    expect(ctx).toContain("auth flow half-implemented");
  });

  it("omits handoff section when no handoff file", () => {
    mockExistsSync.mockReturnValue(false);
    const ctx = buildSessionContext({ projectRoot: "/proj" });
    expect(ctx).not.toContain("Handoff Notes");
  });
});
