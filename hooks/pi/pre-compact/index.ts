import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFileSync } from "node:child_process";
import {
  mkdirSync,
  writeFileSync,
  readdirSync,
  unlinkSync,
  statSync,
} from "node:fs";
import { join } from "node:path";
import { snapshotName, snapshotBody } from "./snapshot.js";
import { currentBranch } from "../_lib/git.js";
import { findProjectRoot } from "../_lib/paths.js";

const KEEP_LAST = 10;

export default function (pi: ExtensionAPI) {
  pi.on("session_before_compact", async () => {
    const root = findProjectRoot(process.cwd());
    const dir = join(root, ".pi", "transcripts");
    mkdirSync(dir, { recursive: true });

    const branch = safe(() => currentBranch(root), "unknown");
    const lastCommit = safe(
      () =>
        execFileSync("git", ["log", "--oneline", "-1"], { cwd: root })
          .toString()
          .trim(),
      "",
    );
    const uncommitted = safe(
      () =>
        execFileSync("git", ["status", "--short"], { cwd: root })
          .toString()
          .trim(),
      "",
    );

    const now = new Date();
    const path = join(dir, snapshotName(now, branch));
    writeFileSync(
      path,
      snapshotBody({ branch, date: now, lastCommit, uncommitted }),
    );

    pruneOldSnapshots(dir, KEEP_LAST);
  });
}

function pruneOldSnapshots(dir: string, keep: number): void {
  try {
    const files = readdirSync(dir)
      .filter((f) => f.endsWith(".md"))
      .map((f) => ({ name: f, mtime: statSync(join(dir, f)).mtimeMs }))
      .sort((a, b) => b.mtime - a.mtime);
    for (const f of files.slice(keep)) {
      unlinkSync(join(dir, f.name));
    }
  } catch {
    // best-effort prune; never block compaction
  }
}

function safe<T>(fn: () => T, fallback: T): T {
  try {
    return fn();
  } catch {
    return fallback;
  }
}
