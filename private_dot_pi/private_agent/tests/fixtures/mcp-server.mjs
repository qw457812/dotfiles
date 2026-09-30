import { appendFileSync, writeFileSync } from "node:fs";
import { createInterface } from "node:readline";

// A real newline-delimited MCP stdio server. Only tools/call counts as dispatch.
const [dispatchPath, pidPath] = process.argv.slice(2);
writeFileSync(pidPath, String(process.pid));
const tools = ["sql_run", "sqlcl_run", "execute_sql", "echo"].map((name) => ({
  name,
  description: `Local regression fixture: ${name}`,
  // Deliberately optional: missing SQL must reach SQL Guard, not schema validation.
  inputSchema: {
    type: "object",
    properties: { sql: { type: "string" }, sqlcl: { type: "string" }, text: { type: "string" } },
    additionalProperties: true,
  },
}));
const lines = createInterface({ input: process.stdin });
lines.on("line", (line) => {
  const request = JSON.parse(line);
  if (request.id === undefined) return;
  let result;
  switch (request.method) {
    case "initialize":
      result = {
        protocolVersion: request.params.protocolVersion,
        capabilities: { tools: {} },
        serverInfo: { name: "mcp-regression", version: "1.0.0" },
      };
      break;
    case "ping":
      result = {};
      break;
    case "tools/list":
      result = { tools };
      break;
    case "tools/call": {
      const { name, arguments: args = {} } = request.params;
      appendFileSync(dispatchPath, `${JSON.stringify({ name, args })}\n`);
      result = { content: [{ type: "text", text: JSON.stringify({ name, args }) }] };
      break;
    }
    default:
      process.stdout.write(
        `${JSON.stringify({ jsonrpc: "2.0", id: request.id, error: { code: -32601, message: "Method not found" } })}\n`,
      );
      return;
  }
  process.stdout.write(`${JSON.stringify({ jsonrpc: "2.0", id: request.id, result })}\n`);
});
lines.on("close", () => process.exit(0));
