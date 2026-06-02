import { describe, it, expect } from "vitest";
import { checkProtectedFile } from "../check.js";

describe("protected-files rules", () => {
  const cfg = { HARNESS_LOCK_FILE: "pnpm-lock.yaml" };

  describe(".env files", () => {
    it("blocks .env", () => {
      expect(checkProtectedFile("/proj/.env", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/env/i),
      });
    });

    it("blocks .env.local", () => {
      expect(checkProtectedFile("/proj/.env.local", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/env/i),
      });
    });

    it("blocks .env.production", () => {
      expect(checkProtectedFile("/proj/sub/.env.production", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/env/i),
      });
    });

    it("allows env.ts (not a dotfile)", () => {
      expect(checkProtectedFile("/proj/src/env.ts", cfg)).toBeUndefined();
    });
  });

  describe("hook scripts", () => {
    it("blocks .claude/hooks/bash-guard.sh", () => {
      expect(
        checkProtectedFile("/proj/.claude/hooks/bash-guard.sh", cfg),
      ).toEqual({
        block: true,
        reason: expect.stringMatching(/hook/i),
      });
    });

    it("blocks hooks/shell/bash-guard.sh (canonical location)", () => {
      expect(
        checkProtectedFile("/proj/hooks/shell/bash-guard.sh", cfg),
      ).toEqual({
        block: true,
        reason: expect.stringMatching(/hook/i),
      });
    });

    it("blocks hooks/pi/bash-guard/index.ts (Pi extension)", () => {
      expect(
        checkProtectedFile("/proj/hooks/pi/bash-guard/index.ts", cfg),
      ).toEqual({
        block: true,
        reason: expect.stringMatching(/hook/i),
      });
    });

    it("blocks hooks/config.sh", () => {
      expect(checkProtectedFile("/proj/hooks/config.sh", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/config/i),
      });
    });
  });

  describe("settings.json", () => {
    it("blocks .claude/settings.json", () => {
      expect(checkProtectedFile("/proj/.claude/settings.json", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/settings/i),
      });
    });

    it("blocks .pi/settings.json", () => {
      expect(checkProtectedFile("/proj/.pi/settings.json", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/settings/i),
      });
    });

    it("allows other JSON files", () => {
      expect(checkProtectedFile("/proj/package.json", cfg)).toBeUndefined();
    });
  });

  describe("lockfile (config-driven)", () => {
    it("blocks pnpm-lock.yaml when configured", () => {
      expect(checkProtectedFile("/proj/pnpm-lock.yaml", cfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/lockfile/i),
      });
    });

    it("blocks pnpm-lock.yaml in a subdir", () => {
      expect(
        checkProtectedFile("/proj/packages/sub/pnpm-lock.yaml", cfg),
      ).toEqual({
        block: true,
        reason: expect.stringMatching(/lockfile/i),
      });
    });

    it("respects the configured lockfile name", () => {
      const npmCfg = { HARNESS_LOCK_FILE: "package-lock.json" };
      expect(checkProtectedFile("/proj/package-lock.json", npmCfg)).toEqual({
        block: true,
        reason: expect.stringMatching(/lockfile/i),
      });
      // pnpm lockfile is NOT blocked when config says npm
      expect(
        checkProtectedFile("/proj/pnpm-lock.yaml", npmCfg),
      ).toBeUndefined();
    });
  });

  describe("benign files", () => {
    it("allows src/app.ts", () => {
      expect(checkProtectedFile("/proj/src/app.ts", cfg)).toBeUndefined();
    });

    it("allows README.md", () => {
      expect(checkProtectedFile("/proj/README.md", cfg)).toBeUndefined();
    });

    it("allows skill files", () => {
      expect(
        checkProtectedFile("/proj/skills/tdd/SKILL.md", cfg),
      ).toBeUndefined();
    });
  });
});
