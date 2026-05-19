import { describe, it, expect, vi, beforeEach } from "vitest";

const { mockBranch, mockExecFileSync, mockExistsSync, mockReadFileSync } =
  vi.hoisted(() => ({
    mockBranch: vi.fn(() => "feature/x"),
    mockExecFileSync: vi.fn(),
    mockExistsSync: vi.fn(() => false),
    mockReadFileSync: vi.fn(() => ""),
  }));

vi.mock("../../_lib/git.js", () => ({
  currentBranch: () => mockBranch(),
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

import { buildReinjectContext } from "../build-reinject.js";

describe("buildReinjectContext", () => {
  beforeEach(() => {
    mockBranch.mockReturnValue("feature/x");
    mockExecFileSync.mockReturnValue(Buffer.from(""));
    mockExistsSync.mockReturnValue(false);
  });

  it("is shorter than the full init context (no full git log, no diff)", () => {
    mockExecFileSync.mockReturnValue(Buffer.from("abc123 some commit"));
    const ctx = buildReinjectContext({ projectRoot: "/proj" });
    expect(ctx).toContain("Branch: feature/x");
    expect(ctx).toContain("Last commit: abc123");
    expect(ctx).not.toContain("Recent commits:");
    expect(ctx).not.toContain("Uncommitted changes:");
  });

  it("includes handoff notes when present", () => {
    mockExistsSync.mockReturnValue(true);
    mockReadFileSync.mockReturnValue("Pick up at step 4 of the plan.");
    const ctx = buildReinjectContext({ projectRoot: "/proj" });
    expect(ctx).toContain("Handoff Notes");
    expect(ctx).toContain("step 4");
  });

  it("omits handoff section when no handoff file", () => {
    mockExistsSync.mockReturnValue(false);
    expect(buildReinjectContext({ projectRoot: "/proj" })).not.toContain(
      "Handoff",
    );
  });
});
