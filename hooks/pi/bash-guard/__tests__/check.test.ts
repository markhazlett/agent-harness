import { describe, it, expect, vi, beforeEach } from "vitest";

const mockCurrentBranch = vi.fn(() => "feature/x");
vi.mock("../../_lib/git.js", () => ({
  currentBranch: () => mockCurrentBranch(),
}));

import { checkBashCommand } from "../check.js";

describe("bash-guard rules", () => {
  const cfg = { HARNESS_SRC_DIRS: "src|lib" };

  beforeEach(() => {
    mockCurrentBranch.mockReturnValue("feature/x");
  });

  describe("rule 1: git commit/push on main/master", () => {
    it("blocks git commit on main", () => {
      mockCurrentBranch.mockReturnValue("main");
      expect(checkBashCommand("git commit -m 'wip'", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/main/i),
      });
    });

    it("blocks git push on master", () => {
      mockCurrentBranch.mockReturnValue("master");
      expect(checkBashCommand("git push origin master", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/master/i),
      });
    });

    it("allows git commit on feature branch", () => {
      mockCurrentBranch.mockReturnValue("feature/auth");
      expect(checkBashCommand("git commit -m 'wip'", cfg)).toBeUndefined();
    });

    it("allows git status on main", () => {
      mockCurrentBranch.mockReturnValue("main");
      expect(checkBashCommand("git status", cfg)).toBeUndefined();
    });
  });

  describe("rule 2: --no-verify", () => {
    it("blocks --no-verify", () => {
      expect(checkBashCommand("git commit --no-verify -m 'x'", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/no-verify/i),
      });
    });

    it("blocks --no-verify with different commands", () => {
      expect(checkBashCommand("git push --no-verify", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/no-verify/i),
      });
    });
  });

  describe("rule 3: sed -i on source files", () => {
    it("blocks sed -i on src/", () => {
      expect(checkBashCommand("sed -i 's/a/b/' src/foo.ts", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/sed -i/i),
      });
    });

    it("blocks sed -i on lib/", () => {
      expect(checkBashCommand("sed -i '' 's/a/b/' lib/foo.ts", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/sed -i/i),
      });
    });

    it("allows sed -i on /tmp/", () => {
      expect(
        checkBashCommand("sed -i 's/a/b/' /tmp/scratch.ts", cfg),
      ).toBeUndefined();
    });

    it("allows sed without -i (read-only)", () => {
      expect(checkBashCommand("sed 's/a/b/' src/foo.ts", cfg)).toBeUndefined();
    });
  });

  describe("rule 4: rm -rf on source dirs", () => {
    it("blocks rm -rf src/foo", () => {
      expect(checkBashCommand("rm -rf src/foo", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/rm -rf/i),
      });
    });

    it("blocks rm -rf lib/", () => {
      expect(checkBashCommand("rm -rf lib/", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/rm -rf/i),
      });
    });

    it("allows rm -rf node_modules", () => {
      expect(checkBashCommand("rm -rf node_modules", cfg)).toBeUndefined();
    });

    it("allows rm -rf /tmp/scratch", () => {
      expect(checkBashCommand("rm -rf /tmp/scratch", cfg)).toBeUndefined();
    });
  });

  describe("rule 5: redirect overwrite to source dir", () => {
    it("blocks > src/foo.ts", () => {
      expect(checkBashCommand("echo hello > src/foo.ts", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/redirect/i),
      });
    });

    it("blocks > lib/foo.json", () => {
      expect(checkBashCommand("cat x.json > lib/foo.json", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/redirect/i),
      });
    });

    it("allows > /dev/null", () => {
      expect(checkBashCommand("echo hello > /dev/null", cfg)).toBeUndefined();
    });

    it("allows > /tmp/out.log", () => {
      expect(
        checkBashCommand("echo hello > /tmp/out.log", cfg),
      ).toBeUndefined();
    });

    it("allows > .claude/logs/foo.log", () => {
      expect(
        checkBashCommand("echo hello > .claude/logs/foo.log", cfg),
      ).toBeUndefined();
    });
  });

  describe("benign commands", () => {
    it("allows ls", () => {
      expect(checkBashCommand("ls -la", cfg)).toBeUndefined();
    });

    it("allows pnpm test", () => {
      expect(checkBashCommand("pnpm test", cfg)).toBeUndefined();
    });

    it("allows pnpm run build", () => {
      expect(checkBashCommand("pnpm run build", cfg)).toBeUndefined();
    });

    it("allows git diff", () => {
      expect(checkBashCommand("git diff", cfg)).toBeUndefined();
    });
  });
});
