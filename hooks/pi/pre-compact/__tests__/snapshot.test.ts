import { describe, it, expect } from "vitest";
import { snapshotName, snapshotBody } from "../snapshot.js";

describe("snapshotName", () => {
  it("formats date as YYYYMMDD-HHMMSS followed by branch", () => {
    const d = new Date("2026-05-18T12:34:56Z");
    expect(snapshotName(d, "main")).toBe("20260518-123456-main.md");
  });

  it("replaces slashes in branch names", () => {
    const d = new Date("2026-01-01T00:00:00Z");
    expect(snapshotName(d, "feature/auth/wip")).toBe(
      "20260101-000000-feature-auth-wip.md",
    );
  });
});

describe("snapshotBody", () => {
  it("includes branch, timestamp, last commit, uncommitted summary", () => {
    const body = snapshotBody({
      branch: "feature/x",
      date: new Date("2026-05-18T12:34:56Z"),
      lastCommit: "abc123 some commit",
      uncommitted: " M src/app.ts",
    });
    expect(body).toContain("**Branch:** feature/x");
    expect(body).toContain("**Timestamp:** 2026-05-18T12:34:56");
    expect(body).toContain("**Last commit:** abc123 some commit");
    expect(body).toContain("src/app.ts");
  });

  it("substitutes (none) when no uncommitted or commit", () => {
    const body = snapshotBody({
      branch: "main",
      date: new Date(),
      lastCommit: "",
      uncommitted: "",
    });
    expect(body).toContain("**Last commit:** (none)");
    expect(body).toContain("(none)");
  });
});
