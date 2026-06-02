import { readFileSync, existsSync } from "node:fs";

export type HarnessConfig = Record<string, string>;

const KEY_VALUE_LINE = /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/;
const FORBIDDEN_COMMAND_SUB = /\$\(|`/;
const UNSUPPORTED_LINE_PREFIX =
  /^(if|then|else|elif|fi|for|while|do|done|case|esac|function|\[)\b/;

/**
 * Parse a config.sh file content into a HarnessConfig record.
 *
 * Accepts:
 *   - KEY=value (unquoted)
 *   - KEY="quoted value" / KEY='single quoted'
 *   - blank lines, shebang, # full-line comments, # inline trailing comments
 *
 * Rejects:
 *   - command substitution: $(...) or backticks
 *   - variable expansion: ${VAR} or $VAR
 *   - shell constructs: if/for/while/case/function/[
 *
 * This is intentionally strict so the config file is statically parseable
 * by both the shell hooks (via source) and the TypeScript Pi hooks (via this
 * parser). Both targets see identical values; no shell interpretation is
 * involved on the TS side.
 */
export function parseHarnessConfig(content: string): HarnessConfig {
  const result: HarnessConfig = {};
  const lines = content.split("\n");

  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i];

    if (raw.trimStart().startsWith("#!")) continue;
    const stripped = stripTrailingComment(raw).trim();
    if (!stripped) continue;
    if (stripped.startsWith("#")) continue;

    if (UNSUPPORTED_LINE_PREFIX.test(stripped)) {
      throw new Error(
        `Line ${i + 1}: unsupported shell construct (only KEY=value supported): ${stripped}`,
      );
    }

    const m = KEY_VALUE_LINE.exec(stripped);
    if (!m) {
      throw new Error(`Line ${i + 1}: not a KEY=value line: ${stripped}`);
    }

    const [, key, rawValue] = m;

    if (FORBIDDEN_COMMAND_SUB.test(rawValue)) {
      throw new Error(
        `Line ${i + 1}: command substitution $(...) or backticks not allowed: ${rawValue}`,
      );
    }

    const valueWithoutQuotes = unquote(rawValue);
    if (/\$\{|\$[A-Za-z_]/.test(valueWithoutQuotes)) {
      throw new Error(
        `Line ${i + 1}: variable expansion \${...} or $VAR not allowed: ${rawValue}`,
      );
    }

    result[key] = valueWithoutQuotes;
  }

  return result;
}

export function loadHarnessConfig(configPath: string): HarnessConfig {
  if (!existsSync(configPath)) {
    throw new Error(`Config file not found: ${configPath}`);
  }
  return parseHarnessConfig(readFileSync(configPath, "utf8"));
}

function stripTrailingComment(line: string): string {
  let inSingle = false;
  let inDouble = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (c === "\\" && i + 1 < line.length) {
      i++;
      continue;
    }
    if (c === "'" && !inDouble) inSingle = !inSingle;
    else if (c === '"' && !inSingle) inDouble = !inDouble;
    else if (c === "#" && !inSingle && !inDouble) return line.slice(0, i);
  }
  return line;
}

function unquote(value: string): string {
  const v = value.trim();
  if (v.length >= 2) {
    if (v.startsWith('"') && v.endsWith('"')) return v.slice(1, -1);
    if (v.startsWith("'") && v.endsWith("'")) return v.slice(1, -1);
  }
  return v;
}
