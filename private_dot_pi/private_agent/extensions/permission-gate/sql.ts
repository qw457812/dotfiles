import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { requestApproval } from "./approval.ts";
import { REASON_LABELS, SQL_QUESTION_VERSION, judgeSql } from "./jev.ts";

/**
 * SQL Guard Extension
 *
 * Validates that SQL executed through SQL MCP tools is read-only.
 *
 * MCP tools (`mcp__<server>__<tool>`) receive params directly in
 * event.input, including nested calls from codemode.
 *
 * MCP server references:
 *  - SQLcl MCP Server (Oracle): https://www.oracle.com/mcp/
 *  - OceanBase MCP Server: https://github.com/oceanbase/awesome-oceanbase-mcp
 */
const GUARDED_TOOL_PATTERNS = [
  /_sqlcl_run$/, // SQLcl MCP Server: mcp__sqlcl__sqlcl_run
  /_sql_run$/, // SQLcl MCP Server: mcp__sqlcl__sql_run
  /_execute_sql$/, // OceanBase MCP Server: mcp__oceanbase__execute_sql
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

function findSqlParam(args: Record<string, unknown>) {
  for (const key of SQL_PARAM_KEYS) {
    const value = args[key];
    if (typeof value === "string" && value.trim()) return value;
  }
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
function sqlConfirmationReason(sql: string): string | undefined {
  const stripped = stripSql(sql);
  if (!stripped) return;

  const firstSemicolon = stripped.indexOf(";");
  const hasInvalidSemicolons =
    firstSemicolon !== -1 &&
    (firstSemicolon !== stripped.length - 1 || firstSemicolon !== stripped.lastIndexOf(";"));
  if (hasInvalidSemicolons) {
    return "Multiple SQL statements are not allowed (semicolons detected).";
  }

  const upper = stripped.toUpperCase();
  const firstWord = upper.split(/\s+/, 1)[0] || "";
  if (!READ_ONLY_COMMANDS.has(firstWord)) {
    return `Only SELECT queries and schema inspection commands are allowed. Found: ${firstWord}`;
  }

  if (firstWord === "SELECT" || firstWord === "WITH") {
    const keyword = upper.match(DANGEROUS_SQL_RE)?.[1];
    if (keyword) {
      return `Query contains dangerous operation: ${keyword}. Only SELECT queries and schema inspection commands are allowed.`;
    }
  }
}

export default function registerSqlChecks(
  pi: ExtensionAPI,
  isJevEnabled: () => boolean,
  getLifetime: () => AbortSignal,
  isEnabled: () => boolean = () => true,
) {
  pi.on("tool_call", async (event, ctx) => {
    if (!isEnabled()) return;
    // Route by the concrete tool name, never by an input parameter.
    if (!GUARDED_TOOL_PATTERNS.some((pattern) => pattern.test(event.toolName))) return;
    const input = event.input;
    if (!input || typeof input !== "object" || Array.isArray(input)) {
      return { block: true, reason: "SQL Guard: Guarded tool called with unsupported args shape" };
    }

    // Like Bash, later handlers may not rewrite SQL that has already been checked.
    for (const key of SQL_PARAM_KEYS) {
      if (!(key in input)) continue;
      Object.defineProperty(input, key, {
        value: Reflect.get(input, key),
        writable: false,
        configurable: false,
        enumerable: true,
      });
    }
    const sql = findSqlParam(input);
    const reason = sql
      ? sqlConfirmationReason(sql)
      : "Guarded tool matched but no recognized SQL parameter found";
    if (!reason) return;

    const lifetime = getLifetime();
    const signal = ctx.signal ? AbortSignal.any([lifetime, ctx.signal]) : lifetime;
    const sessionId = ctx.sessionManager.getSessionId();
    const sameSession = () => !lifetime.aborted && ctx.sessionManager.getSessionId() === sessionId;
    return requestApproval(pi, ctx, {
      signal,
      isValid: sameSession,
      canRecord: sameSession,
      classify:
        sql && isJevEnabled()
          ? () => judgeSql(ctx.modelRegistry, sql, event.toolName, signal)
          : undefined,
      questionVersion: SQL_QUESTION_VERSION,
      rules: ["sql"],
      title: "⚠️ SQL Guard",
      message: (judgment) =>
        `${reason}${sql ? `\n${REASON_LABELS[judgment.reason]}` : ""}\n\nTool: ${event.toolName}\n\nInput:\n${JSON.stringify(input, null, 2)}`,
    });
  });
}
