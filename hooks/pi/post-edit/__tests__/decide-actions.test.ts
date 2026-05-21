import { describe, it, expect } from "vitest";
import { decideActions } from "../decide-actions.js";

describe("decideActions", () => {
  const ROOT = "/proj";

  it("returns format + lint for a TS file", () => {
    const a = decideActions("/proj/src/app.ts", ROOT, {});
    expect(a.format).toBe(true);
    expect(a.lint).toBe(true);
  });

  it("returns format only for JSON (no lint)", () => {
    const a = decideActions("/proj/package.json", ROOT, {});
    expect(a.format).toBe(true);
    expect(a.lint).toBe(false);
  });

  it("returns no actions for a .md file (not formattable by default)", () => {
    const a = decideActions("/proj/README.md", ROOT, {});
    expect(a.format).toBe(false);
    expect(a.lint).toBe(false);
  });

  it("respects HARNESS_FORMATTABLE_EXTS configuration", () => {
    const a = decideActions("/proj/style.scss", ROOT, {
      HARNESS_FORMATTABLE_EXTS: "ts|scss",
    });
    expect(a.format).toBe(true);
  });

  it("triggers dbGenerate when path matches HARNESS_DB_SCHEMA_PATH", () => {
    const a = decideActions("/proj/prisma/schema.prisma", ROOT, {
      HARNESS_DB_SCHEMA_PATH: "prisma/schema.prisma",
      HARNESS_DB_GENERATE_CMD: "pnpm db:generate",
    });
    expect(a.dbGenerate).toBe(true);
    expect(a.dbPush).toBe(false);
  });

  it("triggers dbPush when both generate and push are configured", () => {
    const a = decideActions("/proj/src/db/schema.ts", ROOT, {
      HARNESS_DB_SCHEMA_PATH: "src/db/schema.ts",
      HARNESS_DB_GENERATE_CMD: "pnpm db:generate",
      HARNESS_DB_PUSH_CMD: "pnpm db:push",
    });
    expect(a.dbGenerate).toBe(true);
    expect(a.dbPush).toBe(true);
  });

  it("does NOT trigger dbGenerate when schema path is empty", () => {
    const a = decideActions("/proj/prisma/schema.prisma", ROOT, {
      HARNESS_DB_GENERATE_CMD: "pnpm db:generate",
    });
    expect(a.dbGenerate).toBe(false);
  });

  it("does NOT trigger dbGenerate when generate command is empty", () => {
    const a = decideActions("/proj/prisma/schema.prisma", ROOT, {
      HARNESS_DB_SCHEMA_PATH: "prisma/schema.prisma",
    });
    expect(a.dbGenerate).toBe(false);
  });
});
