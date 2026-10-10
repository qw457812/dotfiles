import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { describe, expect, it, vi } from "vitest";
import filesExtension from "../extensions/files.js";

async function listFiles(messages: unknown[]) {
  let command: Parameters<ExtensionAPI["registerCommand"]>[1] | undefined;
  filesExtension({
    registerCommand: (_name: string, options: typeof command) => {
      command = options;
    },
  } as unknown as ExtensionAPI);
  let output = "";
  const notify = vi.fn();
  const ctx = {
    mode: "tui",
    cwd: "/test",
    sessionManager: { getBranch: () => messages.map((message) => ({ type: "message", message })) },
    ui: {
      notify,
      custom: async (factory: (...args: unknown[]) => { render: (width: number) => string[] }) => {
        const color = (_name: string, value: string) => value;
        const component = factory(
          { requestRender: vi.fn() },
          { fg: color, bg: color, bold: (value: string) => value },
          {},
          vi.fn(),
        );
        output = component.render(120).join("\n");
      },
    },
  } as unknown as ExtensionCommandContext;
  await command!.handler("", ctx);
  return { output, notify };
}

const nested = (name: string, path: unknown, status = "ok") => ({
  id: `nested-${name}`,
  name,
  arguments: { path },
  status,
});

const result = (calls: unknown[], timestamp = 20) => ({
  role: "toolResult",
  toolName: "codemode",
  toolCallId: "script",
  timestamp,
  isError: true,
  content: [],
  nestedCalls: { calls, complete: false },
});

describe("/files nested calls", () => {
  it("includes codemode files even when the script failed and merges direct operations", async () => {
    const { output } = await listFiles([
      {
        role: "assistant",
        timestamp: 1,
        content: [{ type: "toolCall", id: "direct", name: "read", arguments: { path: "shared.ts" } }],
      },
      { role: "toolResult", toolCallId: "direct", timestamp: 2 },
      result([nested("write", "new.ts"), nested("edit", "shared.ts")]),
      result([nested("read", "latest.ts")], 30),
    ]);
    expect(output).toContain("W new.ts");
    expect(output).toContain("RE shared.ts");
    expect(output.match(/shared\.ts/g)).toHaveLength(1);
    expect(output.indexOf("latest.ts")).toBeLessThan(output.indexOf("new.ts"));
  });

  it("ignores unrelated tools, missing arguments, invalid paths and unfinished calls", async () => {
    const { output, notify } = await listFiles([
      result([
        nested("bash", "command.sh"),
        nested("read", 42),
        nested("write", ""),
        nested("edit", "pending.ts", "unfinished"),
        { name: "read", status: "ok" },
      ]),
    ]);
    expect(output).toBe("");
    expect(notify).toHaveBeenCalledWith("No files read/written/edited in this session", "info");
  });

  it("retains failed file operations consistently with direct tool results", async () => {
    const { output } = await listFiles([result([nested("read", "missing.ts", "error")])]);
    expect(output).toContain("R missing.ts");
  });
});
