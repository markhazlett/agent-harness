import { describe, it, expect } from "vitest";
import { parseHarnessConfig, loadHarnessConfig } from "../config.js";
import { join } from "node:path";

describe("parseHarnessConfig", () => {
  describe("supported forms", () => {
    it("parses KEY=value (unquoted)", () => {
      expect(parseHarnessConfig(`HARNESS_PKG_MGR=pnpm`)).toEqual({
        HARNESS_PKG_MGR: "pnpm",
      });
    });

    it('parses KEY="value with spaces"', () => {
      expect(parseHarnessConfig(`HARNESS_TEST_CMD="pnpm test"`)).toEqual({
        HARNESS_TEST_CMD: "pnpm test",
      });
    });

    it("parses KEY='single quoted'", () => {
      expect(parseHarnessConfig(`HARNESS_APP_NAME='My App'`)).toEqual({
        HARNESS_APP_NAME: "My App",
      });
    });

    it("skips blank lines", () => {
      expect(parseHarnessConfig(`\n\n\nKEY=value\n\n`)).toEqual({
        KEY: "value",
      });
    });

    it("skips full-line comments", () => {
      expect(parseHarnessConfig(`# comment\nKEY=value\n# another\n`)).toEqual({
        KEY: "value",
      });
    });

    it("strips inline trailing comments", () => {
      expect(parseHarnessConfig(`KEY=value  # this is a comment`)).toEqual({
        KEY: "value",
      });
    });

    it("does not strip # inside double-quoted values", () => {
      expect(parseHarnessConfig(`KEY="value with # hash"`)).toEqual({
        KEY: "value with # hash",
      });
    });

    it("does not strip # inside single-quoted values", () => {
      expect(parseHarnessConfig(`KEY='value with # hash'`)).toEqual({
        KEY: "value with # hash",
      });
    });

    it("parses multiple keys", () => {
      const input = `
        HARNESS_PKG_MGR=pnpm
        HARNESS_SRC_DIRS="src|lib|app"
        HARNESS_TEST_CMD='pnpm test'
        HARNESS_HOST=claude-code
      `;
      expect(parseHarnessConfig(input)).toEqual({
        HARNESS_PKG_MGR: "pnpm",
        HARNESS_SRC_DIRS: "src|lib|app",
        HARNESS_TEST_CMD: "pnpm test",
        HARNESS_HOST: "claude-code",
      });
    });

    it("preserves regex alternation characters", () => {
      expect(
        parseHarnessConfig(`HARNESS_SRC_DIRS="src|lib|packages/[^/]+"`),
      ).toEqual({ HARNESS_SRC_DIRS: "src|lib|packages/[^/]+" });
    });

    it("ignores shebang line", () => {
      expect(parseHarnessConfig(`#!/usr/bin/env bash\nKEY=value`)).toEqual({
        KEY: "value",
      });
    });
  });

  describe("rejected forms", () => {
    it("rejects command substitution $(...)", () => {
      expect(() => parseHarnessConfig(`KEY=$(date)`)).toThrow(
        /command substitution/i,
      );
    });

    it("rejects backticks", () => {
      expect(() => parseHarnessConfig("KEY=`date`")).toThrow(
        /command substitution/i,
      );
    });

    it("rejects variable expansion ${OTHER}", () => {
      expect(() => parseHarnessConfig(`KEY=\${OTHER}`)).toThrow(
        /variable expansion/i,
      );
    });

    it("rejects bare variable expansion $VAR", () => {
      expect(() => parseHarnessConfig(`KEY=$VAR`)).toThrow(
        /variable expansion/i,
      );
    });

    it("rejects shell conditionals", () => {
      expect(() =>
        parseHarnessConfig(`if [ -n "$X" ]; then\nKEY=value\nfi`),
      ).toThrow(/unsupported|conditional|if/i);
    });

    it("rejects for loops", () => {
      expect(() =>
        parseHarnessConfig(`for x in a b c; do\nKEY=value\ndone`),
      ).toThrow(/unsupported|for/i);
    });

    it("rejects malformed lines", () => {
      expect(() => parseHarnessConfig(`NOT_A_KEY_VALUE_LINE`)).toThrow(
        /not a KEY=value/i,
      );
    });
  });

  describe("loadHarnessConfig (real config.sh in this repo)", () => {
    it("loads the actual hooks/config.sh without throwing", () => {
      const repoRoot = join(__dirname, "..", "..", "..", "..");
      const cfg = loadHarnessConfig(join(repoRoot, "hooks", "config.sh"));
      expect(cfg.HARNESS_PKG_MGR).toBeDefined();
      expect(cfg.HARNESS_SRC_DIRS).toBeDefined();
      expect(cfg.HARNESS_APP_NAME).toBeDefined();
    });

    it("throws when the file does not exist", () => {
      expect(() => loadHarnessConfig("/nonexistent/path/config.sh")).toThrow(
        /Config file not found/,
      );
    });
  });
});
