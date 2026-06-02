export interface FailureEntry {
  toolName: string;
  input: unknown;
  error: string;
  timestamp: Date;
}

/**
 * Format a tool failure as a single-line JSONL entry.
 */
export function formatFailureEntry(e: FailureEntry): string {
  return JSON.stringify({
    ts: e.timestamp.toISOString(),
    tool: e.toolName,
    input: e.input,
    error: e.error,
  });
}
