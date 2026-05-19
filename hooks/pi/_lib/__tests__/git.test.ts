import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { currentBranch, isDirty } from "../git.js";

describe("git helpers", () => {
  let repo: string;

  beforeEach(() => {
    repo = mkdtempSync(join(tmpdir(), "git-test-"));
    execFileSync("git", ["init", "-q", "-b", "main"], { cwd: repo });
    execFileSync("git", ["config", "user.email", "test@test"], { cwd: repo });
    execFileSync("git", ["config", "user.name", "test"], { cwd: repo });
    writeFileSync(join(repo, "README.md"), "hello");
    execFileSync("git", ["add", "."], { cwd: repo });
    execFileSync("git", ["commit", "-q", "-m", "init"], { cwd: repo });
  });

  afterEach(() => {
    rmSync(repo, { recursive: true, force: true });
  });

  describe("currentBranch", () => {
    it("returns main on a freshly initialized repo", () => {
      expect(currentBranch(repo)).toBe("main");
    });

    it("returns the checked-out branch name", () => {
      execFileSync("git", ["checkout", "-q", "-b", "feature/auth"], {
        cwd: repo,
      });
      expect(currentBranch(repo)).toBe("feature/auth");
    });
  });

  describe("isDirty", () => {
    it("returns false on a clean tree", () => {
      expect(isDirty(repo)).toBe(false);
    });

    it("returns true with a modified tracked file", () => {
      writeFileSync(join(repo, "README.md"), "modified");
      expect(isDirty(repo)).toBe(true);
    });

    it("returns true with an untracked file", () => {
      writeFileSync(join(repo, "new.txt"), "new");
      expect(isDirty(repo)).toBe(true);
    });
  });
});
