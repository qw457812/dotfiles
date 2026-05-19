import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

/**
 * SQL Guard Extension
 *
 * Validates that SQL executed through SQL MCP tools is read-only.
 *
 * This extension supports the two tool invocation styles used by
 * pi-mcp-adapter:
 *  - Proxy mode (`directTools: false`): toolName === 'mcp', with the actual
 *    tool in input.tool and params in input.args
 *  - Direct mode (`directTools: true`): the concrete tool is called directly,
 *    with params already in event.input
 *
 * pi-mcp-adapter reference:
 *  - https://github.com/nicobailon/pi-mcp-adapter
 *
 * MCP server references:
 *  - SQLcl MCP Server (Oracle): https://www.oracle.com/mcp/
 *  - OceanBase MCP Server: https://github.com/oceanbase/awesome-oceanbase-mcp
 */
const GUARDED_TOOL_PATTERNS = [
  /_sqlcl_run$/, // SQLcl MCP Server: tools like sqlcl_sqlcl_run
  /_sql_run$/, // SQLcl MCP Server: tools like sqlcl_sql_run
  /_execute_sql$/, // OceanBase MCP Server: tools like oceanbase_execute_sql
];
const SQL_PARAM_KEYS = [
  "sql", // Used by tools like sqlcl_sql_run and oceanbase_execute_sql
  "sqlcl", // Used by tools like sqlcl_sqlcl_run
] as const;
const DANGEROUS_KEYWORDS = [
  "INSERT",
  "UPDATE",
  "DELETE",
  "DROP",
  "CREATE",
  "ALTER",
  "TRUNCATE",
  "MERGE",
  "EXECUTE",
  "CALL",
  "GRANT",
  "REVOKE",
];
const READ_ONLY_COMMANDS = new Set(["SELECT", "WITH", "DESC", "DESCRIBE", "SHOW", "EXPLAIN"]);
const DANGEROUS_SQL_RE = new RegExp(`\\b(${DANGEROUS_KEYWORDS.join("|")})\\b`);

type ExtractResult =
  | { kind: "skip" }
  | { kind: "sql"; sql: string }
  | { kind: "block"; error: string }
  | { kind: "confirm"; error: string };

function isGuardedTool(toolName: string) {
  return GUARDED_TOOL_PATTERNS.some((pattern) => pattern.test(toolName));
}

function findSqlParam(args: Record<string, unknown>) {
  for (const key of SQL_PARAM_KEYS) {
    const value = args[key];
    if (typeof value === "string" && value.trim()) return value;
  }
}

/**
 * Extracts the SQL to validate.
 *
 * In `mcp` proxy mode, `input.args` is expected to be a JSON string.
 * This code still handles object-shaped args defensively so SQL validation
 * cannot be bypassed if the adapter behavior changes in the future.
 */
function extractSql(toolName: string, input: Record<string, unknown>): ExtractResult {
  const targetTool = toolName === "mcp" ? String(input.tool || "") : toolName;
  if (!isGuardedTool(targetTool)) return { kind: "skip" };

  let args = input;
  if (toolName === "mcp") {
    const rawArgs = input.args;
    if (typeof rawArgs === "string") {
      if (!rawArgs.trim()) {
        return {
          kind: "confirm",
          error: "Guarded tool called with no arguments — possible schema change",
        };
      }

      try {
        args = JSON.parse(rawArgs) as Record<string, unknown>;
      } catch (error) {
        return {
          kind: "block",
          error: `Failed to parse MCP tool args JSON: ${(error as Error).message}`,
        };
      }
    } else if (rawArgs && typeof rawArgs === "object" && !Array.isArray(rawArgs)) {
      args = rawArgs as Record<string, unknown>;
    } else {
      return {
        kind: "block",
        error: "Guarded tool called with unsupported args shape",
      };
    }
  }

  const sql = findSqlParam(args);
  return sql
    ? { kind: "sql", sql }
    : {
        kind: "confirm",
        error: "Guarded tool matched but no recognized SQL parameter found",
      };
}

function stripSql(sql: string) {
  return sql
    .replace(/--.*$/gm, "")
    .replace(/\/\*.*?\*\//gs, "")
    .trim()
    .replace(/'(?:[^']|'')*'/g, '"STR"')
    .replace(/"(?:[^"]|"")*"/g, '"STR"');
}

/**
 * Allows only SELECT / WITH and a small set of schema inspection commands.
 * Also rejects multi-statement input and common write-operation keywords.
 */
function validateSqlQuery(sql: string): { valid: boolean; error?: string } {
  const invalid = (error: string) => ({ valid: false as const, error });
  if (!sql.trim()) return { valid: true };

  const stripped = stripSql(sql);
  if (!stripped) return { valid: true };

  const firstSemicolon = stripped.indexOf(";");
  const hasInvalidSemicolons =
    firstSemicolon !== -1 &&
    (firstSemicolon !== stripped.length - 1 || firstSemicolon !== stripped.lastIndexOf(";"));
  if (hasInvalidSemicolons) {
    return invalid("Multiple SQL statements are not allowed (semicolons detected).");
  }

  const upper = stripped.toUpperCase();
  const firstWord = upper.split(/\s+/, 1)[0] || "";
  if (!READ_ONLY_COMMANDS.has(firstWord)) {
    return invalid(
      `Only SELECT queries and schema inspection commands are allowed. Found: ${firstWord}`,
    );
  }

  if (firstWord === "SELECT" || firstWord === "WITH") {
    const keyword = upper.match(DANGEROUS_SQL_RE)?.[1];
    if (keyword) {
      return invalid(
        `Query contains dangerous operation: ${keyword}. Only SELECT queries and schema inspection commands are allowed.`,
      );
    }
  }

  return { valid: true };
}

async function confirmOrBlock(
  pi: ExtensionAPI,
  ctx: ExtensionContext,
  title: string,
  message: string,
  reason: string,
) {
  if (!ctx.hasUI) return { block: true, reason };
  pi.events.emit("my:notification", { title, body: message });
  const ok = await ctx.ui.confirm(title, message);
  if (!ok) {
    ctx.abort();
    return { block: true, reason };
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    const input = event.input as Record<string, unknown>;
    const extracted = extractSql(event.toolName, input);

    if (extracted.kind === "skip") return;
    if (extracted.kind === "block") {
      return { block: true, reason: `SQL Guard: ${extracted.error}` };
    }

    if (extracted.kind === "confirm") {
      return confirmOrBlock(
        pi,
        ctx,
        "⚠️ SQL Guard",
        `${extracted.error}\n\nTool: ${event.toolName}\n\nInput:\n${JSON.stringify(event.input, null, 2)}`,
        `SQL Guard: ${extracted.error}`,
      );
    }

    const result = validateSqlQuery(extracted.sql);
    if (result.valid) return;

    return confirmOrBlock(
      pi,
      ctx,
      "⚠️ SQL Guard",
      `${result.error}\n\nTool: ${event.toolName}\n\nInput:\n${JSON.stringify(event.input, null, 2)}`,
      `SQL Guard: ${result.error}`,
    );
  });
}
