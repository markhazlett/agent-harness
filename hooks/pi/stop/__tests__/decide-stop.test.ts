import { describe, it, expect } from "vitest";
import { decideStopActions } from "../decide-stop.js";

describe("decideStopActions", () => {
  const baseCfg = {
    HARNESS_SRC_DIRS: "src|lib",
    HARNESS_TEST_CMD: "pnpm test",
    HARNESS_TYPECHECK_CMD: "pnpm typecheck",
  };

  it("runs tests + typecheck when source files changed", () => {
    const a = decideStopActions({
      changedFiles: ["src/app.ts", "docs/README.md"],
      cfg: baseCfg,
    });
    expect(a.runTests).toBe(true);
    expect(a.runTypecheck).toBe(true);
  });

  it("skips tests when no source files changed", () => {
    const a = decideStopActions({
      changedFiles: ["docs/README.md", "package.json"],
      cfg: baseCfg,
    });
    expect(a.runTests).toBe(false);
    expect(a.runTypecheck).toBe(false);
  });

  it("skips tests when no test command is configured", () => {
    const a = decideStopActions({
      changedFiles: ["src/app.ts"],
      cfg: { HARNESS_SRC_DIRS: "src", HARNESS_TYPECHECK_CMD: "pnpm tc" },
    });
    expect(a.runTests).toBe(false);
    expect(a.runTypecheck).toBe(true);
  });

  it("always writes handoff and notifies", () => {
    const a = decideStopActions({
      changedFiles: [],
      cfg: baseCfg,
    });
    expect(a.writeHandoff).toBe(true);
    expect(a.notify).toBe(true);
  });

  it("respects custom src dirs", () => {
    const a = decideStopActions({
      changedFiles: ["packages/api/src/handler.ts"],
      cfg: {
        HARNESS_SRC_DIRS: "packages|apps",
        HARNESS_TEST_CMD: "pnpm test",
      },
    });
    expect(a.runTests).toBe(true);
  });
});
