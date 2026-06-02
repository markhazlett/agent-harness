/**
 * Generate a filename for a transcript snapshot. Mirrors the
 * `${TIMESTAMP}-${BRANCH}.md` pattern from hooks/shell/pre-compact.sh.
 *
 * Format: YYYYMMDD-HHMMSS-<branch>.md (with `/` in branch names replaced by `-`).
 */
export function snapshotName(date: Date, branch: string): string {
  const safeBranch = branch.replace(/[\/\\]/g, "-");
  const ts = formatTimestamp(date);
  return `${ts}-${safeBranch}.md`;
}

/**
 * Build the body of a transcript snapshot.
 */
export function snapshotBody(opts: {
  branch: string;
  date: Date;
  lastCommit: string;
  uncommitted: string;
}): string {
  return [
    `# Transcript Snapshot`,
    `- **Branch:** ${opts.branch}`,
    `- **Timestamp:** ${opts.date.toISOString()}`,
    `- **Last commit:** ${opts.lastCommit || "(none)"}`,
    `- **Uncommitted changes:**`,
    opts.uncommitted || "(none)",
    "",
  ].join("\n");
}

function formatTimestamp(d: Date): string {
  const y = d.getUTCFullYear();
  const m = pad2(d.getUTCMonth() + 1);
  const day = pad2(d.getUTCDate());
  const hh = pad2(d.getUTCHours());
  const mm = pad2(d.getUTCMinutes());
  const ss = pad2(d.getUTCSeconds());
  return `${y}${m}${day}-${hh}${mm}${ss}`;
}

function pad2(n: number): string {
  return String(n).padStart(2, "0");
}
