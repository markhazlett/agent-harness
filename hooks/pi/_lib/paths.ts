import { existsSync } from "node:fs";
import { join, resolve, dirname } from "node:path";

/**
 * Walk up from startDir until a directory containing .pi/ or .claude/ is found.
 * Throws if no such ancestor exists.
 */
export function findProjectRoot(startDir: string): string {
  let dir = resolve(startDir);
  while (true) {
    if (existsSync(join(dir, ".pi")) || existsSync(join(dir, ".claude"))) {
      return dir;
    }
    const parent = dirname(dir);
    if (parent === dir) {
      throw new Error(
        `No project root (no .pi/ or .claude/) found above ${startDir}`,
      );
    }
    dir = parent;
  }
}

export function getHooksConfigPath(projectRoot: string): string {
  return join(projectRoot, ".pi", "hooks", "config.sh");
}

export function getAgentsDir(projectRoot: string): string {
  return join(projectRoot, ".pi", "agents");
}
