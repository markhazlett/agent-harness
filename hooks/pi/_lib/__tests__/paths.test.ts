import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { findProjectRoot, getHooksConfigPath, getAgentsDir } from "../paths.js";

describe("paths", () => {
  let tmp: string;

  beforeEach(() => {
    tmp = join(
      tmpdir(),
      `paths-test-${Date.now()}-${Math.random().toString(36).slice(2)}`,
    );
    mkdirSync(tmp, { recursive: true });
  });

  afterEach(() => {
    rmSync(tmp, { recursive: true, force: true });
  });

  describe("findProjectRoot", () => {
    it("returns the directory containing .pi/ when started from a deep subdir", () => {
      const root = join(tmp, "project");
      mkdirSync(join(root, ".pi"), { recursive: true });
      mkdirSync(join(root, "src", "deep", "nested"), { recursive: true });
      expect(findProjectRoot(join(root, "src", "deep", "nested"))).toBe(root);
    });

    it("returns the directory containing .claude/ when no .pi/ is present", () => {
      const root = join(tmp, "project");
      mkdirSync(join(root, ".claude"), { recursive: true });
      mkdirSync(join(root, "sub"), { recursive: true });
      expect(findProjectRoot(join(root, "sub"))).toBe(root);
    });

    it("prefers the closest ancestor when both .pi/ and a parent .claude/ exist", () => {
      const outer = join(tmp, "outer");
      const inner = join(outer, "inner");
      mkdirSync(join(outer, ".claude"), { recursive: true });
      mkdirSync(join(inner, ".pi"), { recursive: true });
      mkdirSync(join(inner, "src"), { recursive: true });
      expect(findProjectRoot(join(inner, "src"))).toBe(inner);
    });

    it("throws when no ancestor has .pi/ or .claude/", () => {
      mkdirSync(join(tmp, "lonely"), { recursive: true });
      expect(() => findProjectRoot(join(tmp, "lonely"))).toThrow(
        /No project root/,
      );
    });
  });

  describe("getHooksConfigPath", () => {
    it("returns <root>/.pi/hooks/config.sh", () => {
      expect(getHooksConfigPath("/proj")).toBe(
        join("/proj", ".pi", "hooks", "config.sh"),
      );
    });
  });

  describe("getAgentsDir", () => {
    it("returns <root>/.pi/agents", () => {
      expect(getAgentsDir("/proj")).toBe(join("/proj", ".pi", "agents"));
    });
  });
});
