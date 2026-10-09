import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { runToolCall, type AgentToolCallOutcome } from "@earendil-works/pi-agent-core";
import type { AssistantMessage, JsonObject } from "@earendil-works/pi-ai";
import {
  type AgentSession,
  createAgentSession,
  createCodemodeExtension,
  createMcpExtension,
  DefaultResourceLoader,
  SessionManager,
  SettingsManager,
  type ToolCallEvent,
  type ExtensionUIContext,
  VERSION,
} from "@earendil-works/pi-coding-agent";
// These helpers are not exported at the package root. Use installed SDK internals
// solely to isolate config/OAuth storage; transports and extensions are not mocked.
import { InMemoryAuthStorageBackend } from "../node_modules/@earendil-works/pi-coding-agent/dist/core/auth-storage.js";
import { loadMcpConfig } from "../node_modules/@earendil-works/pi-coding-agent/dist/extensions/mcp/config.js";
import { McpOAuthCredentialStore } from "../node_modules/@earendil-works/pi-coding-agent/dist/extensions/mcp/oauth.js";
import sqlGuard from "../extensions/permission-gate/sql-guard.ts";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const fixturePath = fileURLToPath(new URL("./fixtures/mcp-server.mjs", import.meta.url));
const guardedTools = [
  { name: "sql_run", key: "sql" },
  { name: "sqlcl_run", key: "sqlcl" },
  { name: "execute_sql", key: "sql" },
] as const;
const mcpToolName = (name: string) => `mcp__fixture__${name}`;
type Dispatch = { name: string; args: Record<string, unknown> };
const resultText = (outcome: AgentToolCallOutcome) =>
  outcome.result.content.flatMap((item) => (item.type === "text" ? [item.text] : [])).join("\n");

// No prompt/streaming provider: run the SDK's public tool pipeline against real
// session tools and its installed hooks. A synthetic assistant supplies call context
// (also required by the SDK for nested codemode calls), not a fake model response.
function assistantFor(id: string, name: string, args: JsonObject): AssistantMessage {
  return {
    role: "assistant",
    content: [{ type: "toolCall", id, name, arguments: args }],
    api: "openai-completions",
    provider: "regression-offline",
    model: "no-model-requests",
    usage: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    stopReason: "toolUse",
    timestamp: Date.now(),
  };
}

describe("MCP SQL Guard integration (installed SDK 1.1.0)", () => {
  let root: string;
  let session: AgentSession | undefined;
  let callNumber: number;
  let calls: ToolCallEvent[];
  let errors: string[];

  async function dispatches(): Promise<Dispatch[]> {
    const data = await readFile(join(root, "dispatch.jsonl"), "utf8");
    return data.trim()
      ? data
          .trim()
          .split("\n")
          .map((line) => JSON.parse(line) as Dispatch)
      : [];
  }

  async function invoke(name: string, args: JsonObject) {
    if (!session) throw new Error("Session not initialized");
    const id = `regression-${++callNumber}`;
    const assistantMessage = assistantFor(id, name, args);
    session.agent.state.messages = [assistantMessage];
    return runToolCall(
      { type: "toolCall", id, name, arguments: args },
      {
        tools: session.agent.state.tools,
        assistantMessage,
        context: { messages: session.agent.state.messages, tools: session.agent.state.tools },
        beforeToolCall: session.agent.beforeToolCall,
        afterToolCall: session.agent.afterToolCall,
      },
    );
  }

  beforeEach(async () => {
    root = await mkdtemp(join(tmpdir(), "pi-mcp-"));
    callNumber = 0;
    calls = [];
    errors = [];
    const cwd = join(root, "workspace");
    const agentDir = join(root, "agent");
    await Promise.all([mkdir(cwd), mkdir(agentDir), writeFile(join(root, "dispatch.jsonl"), "")]);
    await writeFile(
      join(agentDir, "mcp.json"),
      JSON.stringify({
        mcpServers: {
          fixture: {
            command: process.execPath,
            args: [fixturePath, join(root, "dispatch.jsonl"), join(root, "fixture.pid")],
            exposure: "direct",
            timeout: 5,
          },
        },
      }),
    );
    const settingsManager = SettingsManager.inMemory({ defaultTools: ["+codemode"] });
    const resourceLoader = new DefaultResourceLoader({
      cwd,
      agentDir,
      settingsManager,
      noSkills: true,
      noPromptTemplates: true,
      noThemes: true,
      noContextFiles: true,
      extensionFactories: [
        // Unlike the CLI, SDK sessions must explicitly install these extensions.
        createCodemodeExtension({ mode: "on" }),
        createMcpExtension({
          // MCP defaults use getAgentDir(), not the session's agentDir.
          loadConfig: () => loadMcpConfig({ agentDir, cwd, projectTrusted: false }),
          credentials: new McpOAuthCredentialStore(new InMemoryAuthStorageBackend()),
          logPath: join(root, "mcp.log"),
        }),
        (pi) => {
          pi.on("tool_call", (event) => {
            calls.push(event);
          });
        },
        sqlGuard,
      ],
    });
    await resourceLoader.reload();
    const created = await createAgentSession({
      cwd,
      agentDir,
      settingsManager,
      resourceLoader,
      sessionManager: SessionManager.inMemory(cwd),
      noTools: "builtin",
    });
    session = created.session;
    expect(created.extensionsResult.errors).toEqual([]);
    // Fail closed if a test accidentally tries to request a model or use HTTP.
    session.agent.streamFunction = () => {
      throw new Error("Model requests forbidden in MCP regression");
    };
    vi.stubGlobal(
      "fetch",
      vi.fn(() => {
        throw new Error("Network forbidden in MCP regression");
      }),
    );
  });

  async function bindAndDiscover(uiContext?: ExtensionUIContext, abortHandler?: () => void) {
    if (!session) throw new Error("Session not initialized");
    await session.bindExtensions({
      uiContext,
      abortHandler,
      onError: (error) => {
        errors.push(error.error);
      },
    });
    // session_start connects asynchronously; bindExtensions is not a discovery barrier.
    await vi.waitFor(
      () => {
        expect(session?.getActiveToolNames()).toContain(mcpToolName("echo"));
      },
      { timeout: 10_000, interval: 25 },
    );
    // noTools: builtin suppresses the defaultTools selection; activate only the
    // registered orchestration tool without enabling filesystem/shell tools.
    session.setActiveToolsByName([...session.getActiveToolNames(), "codemode"]);
    expect(session.getActiveToolNames()).toContain("codemode");
  }

  afterEach(async () => {
    try {
      // dispose() alone does not emit session_shutdown in the SDK.
      if (session) await session.extensionRunner.emit({ type: "session_shutdown", reason: "quit" });
    } finally {
      session?.dispose();
      session = undefined;
      vi.unstubAllGlobals();
      if (root) {
        // Verify real transport shutdown, with a fallback for failed setup/tests.
        const pid = await readFile(join(root, "fixture.pid"), "utf8")
          .then(Number)
          .catch(() => undefined);
        try {
          if (pid)
            await vi.waitFor(
              () => {
                expect(() => process.kill(pid, 0)).toThrow();
              },
              { timeout: 5_000, interval: 25 },
            );
        } finally {
          if (pid) {
            try {
              process.kill(pid, "SIGKILL");
            } catch {
              /* Already reaped. */
            }
          }
          await rm(root, { recursive: true, force: true });
        }
      }
    }
  });

  it("discovers MCP tool names and leaves non-SQL echo unguarded", async () => {
    await bindAndDiscover();
    expect(VERSION).toBe("1.1.0");
    expect(
      session
        ?.getAllTools()
        .filter((tool) => tool.name.startsWith("mcp__"))
        .map((tool) => tool.name)
        .sort(),
    ).toEqual([...guardedTools.map((tool) => mcpToolName(tool.name)), mcpToolName("echo")].sort());
    const result = await invoke(mcpToolName("echo"), { text: "DROP TABLE is just echo text" });
    expect(result.isError).toBe(false);
    expect(resultText(result)).toContain("DROP TABLE is just echo text");
    expect(await dispatches()).toEqual([
      { name: "echo", args: { text: "DROP TABLE is just echo text" } },
    ]);
    expect(errors).toEqual([]);
  });

  it.each(guardedTools)(
    "allows read-only $name but blocks unsafe/missing SQL before stdio dispatch",
    async ({ name, key }) => {
      await bindAndDiscover();
      const args = { [key]: "SELECT 1 AS value" };
      const allowed = await invoke(mcpToolName(name), args);
      expect(allowed.isError).toBe(false);
      expect(resultText(allowed)).toContain("SELECT 1 AS value");
      expect(await dispatches()).toEqual([{ name, args }]);
      for (const input of [{ [key]: "DROP TABLE important" }, {}, { [key]: "" }]) {
        const blocked = await invoke(mcpToolName(name), input);
        expect(blocked.isError).toBe(true);
        expect(resultText(blocked)).toContain("SQL Guard:");
        expect(await dispatches()).toEqual([{ name, args }]);
      }
      expect(calls.map((call) => call.toolName)).toEqual(Array(4).fill(mcpToolName(name)));
      expect(calls.every((call) => call.parentToolCallId === undefined)).toBe(true);
      expect(errors).toEqual([]);
    },
  );

  it.each(guardedTools)(
    "codemode nested $name traverses the same gate and never dispatches blocked calls",
    async ({ name, key }) => {
      await bindAndDiscover();
      const args = { [key]: "SELECT 2 AS value" };
      const allowed = await invoke("codemode", {
        code: `return await tools.${mcpToolName(name)}(${JSON.stringify(args)});`,
      });
      expect(allowed.isError).toBe(false);
      expect(resultText(allowed)).toContain("Script completed");
      expect(resultText(allowed)).toContain("SELECT 2 AS value");
      for (const input of [{ [key]: "DELETE FROM important" }, {}]) {
        const blocked = await invoke("codemode", {
          code: `return await tools.${mcpToolName(name)}(${JSON.stringify(input)});`,
        });
        expect(resultText(blocked)).toContain("Script failed");
        expect(resultText(blocked)).toContain("SQL Guard:");
        expect(await dispatches()).toEqual([{ name, args }]);
      }
      const nested = calls.filter((call) => call.toolName === mcpToolName(name));
      expect(nested).toHaveLength(3);
      expect(nested.every((call) => call.parentToolCallId?.startsWith("regression-"))).toBe(true);
      expect(errors).toEqual([]);
    },
    20_000,
  );

  it.each([false, true])(
    "SDK UI confirmation=%s controls dangerous and missing-SQL dispatch",
    async (approved) => {
      if (!session) throw new Error("Session not initialized");
      const confirm = vi.fn(async () => approved);
      const abortHandler = vi.fn();
      // Bind once: rebinding emits session_start again and reconnects MCP servers.
      await bindAndDiscover(
        { ...session.extensionRunner.createContext().ui, confirm },
        abortHandler,
      );
      const inputs: JsonObject[] = [{ sql: "UPDATE important SET value = 1" }, {}];
      for (const args of inputs) {
        const outcome = await invoke(mcpToolName("sql_run"), args);
        expect(outcome.isError).toBe(!approved);
        if (!approved) expect(resultText(outcome)).toContain("SQL Guard:");
      }
      expect(confirm).toHaveBeenCalledTimes(2);
      expect(confirm.mock.calls[0]).toEqual(expect.arrayContaining(["⚠️ SQL Guard"]));
      expect(abortHandler).toHaveBeenCalledTimes(approved ? 0 : 2);
      expect(await dispatches()).toEqual(
        approved
          ? [
              { name: "sql_run", args: { sql: "UPDATE important SET value = 1" } },
              { name: "sql_run", args: {} },
            ]
          : [],
      );
      expect(errors).toEqual([]);
    },
  );
});
