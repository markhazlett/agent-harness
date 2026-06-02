export interface StopConfig {
  HARNESS_SRC_DIRS?: string;
  HARNESS_TEST_CMD?: string;
  HARNESS_TYPECHECK_CMD?: string;
  HARNESS_APP_NAME?: string;
}

export interface StopActions {
  runTests: boolean;
  runTypecheck: boolean;
  writeHandoff: boolean;
  notify: boolean;
}

/**
 * Decide which end-of-session actions to perform.
 *
 * runTests/runTypecheck only when source files (matching HARNESS_SRC_DIRS)
 * have changed in the working tree or index. writeHandoff and notify
 * always fire.
 */
export function decideStopActions(opts: {
  changedFiles: string[];
  cfg: StopConfig;
}): StopActions {
  const srcDirs = opts.cfg.HARNESS_SRC_DIRS ?? "src|lib";
  const srcRe = new RegExp(`(?:^|/)(?:${srcDirs})/.+\\.(?:[tj]sx?|json|css)$`);
  const touchedSrc = opts.changedFiles.some((f) => srcRe.test(f));

  return {
    runTests: touchedSrc && !!opts.cfg.HARNESS_TEST_CMD,
    runTypecheck: touchedSrc && !!opts.cfg.HARNESS_TYPECHECK_CMD,
    writeHandoff: true,
    notify: true,
  };
}
