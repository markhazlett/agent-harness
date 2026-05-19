export interface PostEditConfig {
  HARNESS_FORMATTABLE_EXTS?: string;
  HARNESS_DB_SCHEMA_PATH?: string;
  HARNESS_DB_GENERATE_CMD?: string;
  HARNESS_DB_PUSH_CMD?: string;
}

export interface PostEditActions {
  format: boolean;
  lint: boolean;
  dbGenerate: boolean;
  dbPush: boolean;
}

/**
 * Decide which post-edit actions to run for a given file path.
 *
 * Mirrors hooks/shell/post-edit.sh:
 *   - format: file matches HARNESS_FORMATTABLE_EXTS
 *   - lint: file matches ts|tsx|js|jsx
 *   - dbGenerate: file path matches HARNESS_DB_SCHEMA_PATH and
 *     HARNESS_DB_GENERATE_CMD is set
 *   - dbPush: dbGenerate && HARNESS_DB_PUSH_CMD is set
 */
export function decideActions(
  filePath: string,
  repoRoot: string,
  cfg: PostEditConfig,
): PostEditActions {
  const exts = cfg.HARNESS_FORMATTABLE_EXTS ?? "ts|tsx|js|jsx|json|css";
  const formattableRe = new RegExp(`\\.(${exts})$`);
  const lintRe = /\.(ts|tsx|js|jsx)$/;

  const format = formattableRe.test(filePath);
  const lint = lintRe.test(filePath);

  const relPath = filePath.startsWith(repoRoot + "/")
    ? filePath.slice(repoRoot.length + 1)
    : filePath;

  const dbGenerate = !!(
    cfg.HARNESS_DB_SCHEMA_PATH &&
    cfg.HARNESS_DB_GENERATE_CMD &&
    relPath === cfg.HARNESS_DB_SCHEMA_PATH
  );
  const dbPush = dbGenerate && !!cfg.HARNESS_DB_PUSH_CMD;

  return { format, lint, dbGenerate, dbPush };
}
