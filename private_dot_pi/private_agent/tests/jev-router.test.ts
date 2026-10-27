import type { Message, ToolResultMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { describe, expect, it, vi } from "vitest";
import jevRouter from "../extensions/jev-router.js";

const user: Message = { role: "user", content: "Fix this", timestamp: 1 };

function result(
  toolName: string,
  isError = false,
  calls?: NonNullable<ToolResultMessage["nestedCalls"]>["calls"],
): ToolResultMessage {
  return {
    role: "toolResult",
    toolCallId: "test",
    toolName,
    isError,
    content: [],
    timestamp: 2,
    ...(calls ? { nestedCalls: { calls, complete: false } } : {}),
  };
}

async function route(messages: Message[]) {
  type Definition = Parameters<ExtensionAPI["registerVirtualModel"]>[0];
  let definition: Definition | undefined;
  jevRouter({
    registerVirtualModel: (value: Definition) => {
      definition = value;
    },
  } as unknown as ExtensionAPI);
  const planning = { provider: "openai-codex", model: "gpt-6.1-sol", thinkingLevel: "low" };
  const ctx = {
    modelRegistry: { find: vi.fn((provider, id) => ({ provider, id })) },
  } as unknown as ExtensionContext;
  return definition!.route(
    {
      model: { provider: "jev", id: "auto" },
      reason: "continuation",
      thinkingLevel: "off",
      messages,
      state: { phase: "planning", route: planning },
    } as unknown as Parameters<NonNullable<typeof definition>["route"]>[0],
    ctx,
  );
}

const nested = (name: string, status: "ok" | "error" | "unfinished" = "ok") => ({
  id: `script/${name}`,
  name,
  status,
});

describe("Jev implementation routing", () => {
  it.each(["edit", "write"])("switches after a successful direct %s", async (name) => {
    const routed = await route([user, result(name)]);
    expect(routed.model.id).toBe("gpt-6.1-terra");
    expect(routed.thinkingLevel).toBe("medium");
  });

  it.each(["edit", "write"])("switches after a nested %s even if the outer script failed", async (name) => {
    for (const isError of [false, true]) {
      const routed = await route([user, result("codemode", isError, [nested(name)])]);
      expect(routed.model.id).toBe("gpt-6.1-terra");
      expect(routed.thinkingLevel).toBe("medium");
      expect(routed.state).toMatchObject({ phase: "implementation" });
    }
  });

  it("ignores failed, unfinished and read-only calls", async () => {
    const routed = await route([
      user,
      result("edit", true),
      result("write", true),
      result("codemode", false, [nested("edit", "error"), nested("write", "unfinished"), nested("read")]),
    ]);
    expect(routed.model.id).toBe("gpt-6.1-sol");
    expect(routed.state).toBeUndefined();
  });

  it("does not count edits before the latest user message", async () => {
    const routed = await route([result("write"), result("codemode", false, [nested("edit")]), user]);
    expect(routed.model.id).toBe("gpt-6.1-sol");
  });

  it("does not infer edits from script text or result content", async () => {
    const message = result("codemode");
    message.content = [{ type: "text", text: 'await tools.edit({ path: "file.ts" })' }];
    expect((await route([user, message])).model.id).toBe("gpt-6.1-sol");
  });
});
