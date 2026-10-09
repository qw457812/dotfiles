import type {
  ClassifierModel,
  ClassifierResult,
  UserMessage,
  AssistantMessage,
  ToolResultMessage,
} from "@earendil-works/pi-ai";
import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ExtensionContext,
  ExtensionHandler,
  RegisteredCommand,
  SessionEntry,
  ToolCallEvent,
  ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import permissionGate, { GATE_ENTRY } from "../../extensions/permission-gate/index.ts";
import { initializeBashParser } from "../../lib/bash-parser.ts";
import {
  CLASSIFY_TIMEOUT,
  COMMAND_LIMIT,
  GATE_QUESTIONS,
  INTENT_LIMIT,
  QUESTION_VERSION,
  type GateJudgment,
} from "../../extensions/permission-gate/jev.ts";
import { latestUserIntent } from "../../extensions/permission-gate/intent.ts";
import { RULE_LABELS, type GateRule } from "../../extensions/permission-gate/policy.ts";

const MODEL: ClassifierModel<"typesafe-classifier"> = {
  type: "classifier",
  id: "jev-latest",
  name: "Mock Jev",
  provider: "typesafe",
  api: "typesafe-classifier",
  baseUrl: "https://never-called.invalid",
  input: ["text"],
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
  contextWindow: 100_000,
};
const TIMESTAMP = "2026-01-01T00:00:00.000Z";
const SECRET = "secret-token-DO-NOT-LOG";
const COMMAND = `rm -rf /repo/${SECRET}`;
const INTENT = `Delete /repo/${SECRET}, including all its files.`;
const USAGE = "Usage: /gate git [on|off] | jev [on|off] | log";
const CANCELLED = { block: true, reason: "Permission Gate: operation cancelled" };

function result(intent = 0.99, scope = 0.99, harm = 0.01): ClassifierResult {
  return {
    api: MODEL.api,
    provider: MODEL.provider,
    model: MODEL.id,
    answers: {
      intent_covered: { type: "bool", probability: intent },
      scope_covered: { type: "bool", probability: scope },
      unexpected_harm: { type: "bool", probability: harm },
    },
    stopReason: "stop",
    timestamp: 0,
  };
}

function user(id = "user-1", content: UserMessage["content"] = INTENT): SessionEntry {
  return {
    type: "message",
    id,
    parentId: null,
    timestamp: TIMESTAMP,
    message: { role: "user", content, timestamp: 0 },
  };
}

function message(id: string, value: AssistantMessage | ToolResultMessage): SessionEntry {
  return { type: "message", id, parentId: "user-1", timestamp: TIMESTAMP, message: value };
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

// Only microtasks: parser is initialized before tests, and no fixture command is executed.
async function flush() {
  for (let i = 0; i < 40; i++) await Promise.resolve();
}

type ToolHandler = ExtensionHandler<ToolCallEvent, ToolCallEventResult>;
type LifecycleName =
  | "session_start"
  | "session_before_switch"
  | "session_before_tree"
  | "session_shutdown";
type LifecycleHandler = (event: { type: LifecycleName }, ctx: ExtensionContext) => unknown;
type GateCommand = Omit<RegisteredCommand, "name" | "sourceInfo">;
interface Decision {
  version: 1;
  questionVersion: number;
  timestamp: string;
  model: string;
  rules: GateRule[];
  judgment: GateJudgment;
  durationMs: number;
  outcome: string;
}

function harness(options: { hasUI?: boolean; branch?: SessionEntry[] } = {}) {
  let branch = options.branch ?? [user()];
  let sessionId = "session-1";
  const tools: ToolHandler[] = [];
  const laterTools: ToolHandler[] = [];
  let command: GateCommand | undefined;
  let entryId = 0;
  let callId = 0;
  const lifecycle = new Map<LifecycleName, LifecycleHandler>();
  const controller = new AbortController();
  const classify = vi
    .fn<ExtensionContext["modelRegistry"]["classify"]>()
    .mockResolvedValue(result());
  const findOfType = vi.fn((): ClassifierModel<"typesafe-classifier"> | undefined => MODEL);
  const registry = { findOfType, classify };
  const confirm = vi.fn<ExtensionContext["ui"]["confirm"]>().mockResolvedValue(true);
  const notify = vi.fn<ExtensionContext["ui"]["notify"]>();
  const abort = vi.fn(() => controller.abort());
  const emit = vi.fn<ExtensionAPI["events"]["emit"]>();
  const sendMessage = vi.fn<ExtensionAPI["sendMessage"]>();
  const sendUserMessage = vi.fn<ExtensionAPI["sendUserMessage"]>();
  const getBranch = vi.fn(() => branch);
  const getSessionId = vi.fn(() => sessionId);
  // The API is intentionally narrow; all exercised signatures use Pi's exported types.
  // Cast only at framework boundaries for unused UI/session/registry/API members.
  const ctx = {
    cwd: "/repo",
    mode: "tui",
    hasUI: options.hasUI ?? true,
    ui: { confirm, notify } as unknown as ExtensionContext["ui"],
    sessionManager: { getBranch, getSessionId } as unknown as ExtensionContext["sessionManager"],
    modelRegistry: registry as unknown as ExtensionContext["modelRegistry"],
    model: undefined,
    scopedModels: [],
    signal: controller.signal,
    abort,
    isIdle: vi.fn(() => false),
    isProjectTrusted: vi.fn(() => true),
    hasPendingMessages: vi.fn(() => false),
    shutdown: vi.fn(),
    getContextUsage: vi.fn(() => undefined),
    compact: vi.fn(),
    getSystemPrompt: vi.fn(() => ""),
  } satisfies ExtensionContext;
  const commandCtx = {
    ...ctx,
    getSystemPromptOptions: vi.fn(() => ({ cwd: ctx.cwd })),
    waitForIdle: vi.fn(async () => {}),
    newSession: vi.fn(async () => ({ cancelled: false })),
    fork: vi.fn(async () => ({ cancelled: false })),
    navigateTree: vi.fn(async () => ({ cancelled: false })),
    switchSession: vi.fn(async () => ({ cancelled: false })),
    reload: vi.fn(async () => {}),
  } satisfies ExtensionCommandContext;
  const appendEntry = vi.fn<ExtensionAPI["appendEntry"]>((customType, data) => {
    branch.push({
      type: "custom",
      customType,
      data,
      id: `gate-${++entryId}`,
      parentId: branch.at(-1)?.id ?? null,
      timestamp: TIMESTAMP,
    });
  });
  permissionGate({
    on(name: string, handler: ToolHandler | LifecycleHandler) {
      if (name === "tool_call") tools.push(handler as ToolHandler);
      else lifecycle.set(name as LifecycleName, handler as LifecycleHandler);
      return () => {};
    },
    registerCommand(name: string, registered: GateCommand) {
      expect(name).toBe("gate");
      command = registered;
    },
    appendEntry,
    events: { emit },
    sendMessage,
    sendUserMessage,
  } as unknown as ExtensionAPI);
  if (tools.length !== 3 || !command) throw new Error("Permission Gate registration missing");
  const gateCommand = command;
  const dispatchTool = async (event: ToolCallEvent) => {
    // Match Pi's registration-order dispatch: exceptions escape before execution.
    for (const callback of [...tools, ...laterTools]) {
      const outcome = await callback(event, ctx);
      if (outcome?.block) return outcome;
    }
  };
  return {
    ctx,
    controller,
    classify,
    findOfType,
    confirm,
    notify,
    abort,
    emit,
    appendEntry,
    sendMessage,
    sendUserMessage,
    getBranch,
    getSessionId,
    gateCommand,
    gate: (args: string) => gateCommand.handler(args, commandCtx),
    registerToolCall: (callback: ToolHandler) => laterTools.push(callback),
    runInput: (value: Record<string, unknown>, toolName = "bash") =>
      dispatchTool({ type: "tool_call", toolCallId: `call-${++callId}`, toolName, input: value }),
    // Calling a nested event exercises the same gate without running codemode or Bash.
    run: (text = COMMAND, toolName = "bash", nested = false) =>
      dispatchTool({
        type: "tool_call",
        toolCallId: nested ? `codemode/${++callId}` : `call-${++callId}`,
        ...(nested ? { parentToolCallId: "codemode" } : {}),
        toolName,
        input: { command: text },
      }),
    fire: async (name: LifecycleName) => {
      const callback = lifecycle.get(name);
      if (!callback) throw new Error(`Unregistered ${name}`);
      await callback({ type: name }, ctx);
    },
    replaceSession: (id: string, entries: SessionEntry[] = [user()]) => {
      sessionId = id;
      branch = entries;
    },
    replaceBranch: (entries: SessionEntry[]) => {
      branch = entries;
    },
    decisions: () =>
      branch
        .filter((entry) => entry.type === "custom" && entry.customType === GATE_ENTRY)
        .map((entry) => (entry.type === "custom" ? entry.data : undefined) as Decision),
    branch: () => branch,
  };
}

beforeAll(async () => {
  await initializeBashParser();
});
afterEach(() => {
  vi.restoreAllMocks();
  vi.useRealTimers();
});

describe("Permission Gate latest ordinary user intent", () => {
  it("accepts legacy and sendUserMessage-style ordinary user entries without provenance", async () => {
    const h = harness({
      branch: [user("older", "Only delete /repo/old-target"), user("injected")],
    });
    expect(latestUserIntent(h.branch())).toEqual({ id: "injected", text: INTENT });
    expect(await h.run()).toBeUndefined();
    expect(h.classify.mock.calls[0][1].state.user_intent).toBe(INTENT);
    expect(h.confirm).not.toHaveBeenCalled();
    expect(h.decisions()[0].outcome).toBe("auto-approved");
    expect(JSON.stringify(h.appendEntry.mock.calls)).not.toContain(INTENT);
  });

  it("reconstructs latest intent after reload and follows current branch selection", async () => {
    const saved = JSON.parse(JSON.stringify([user()])) as SessionEntry[];
    const h = harness({ branch: saved });
    await h.fire("session_start");
    await h.run();
    h.replaceBranch([user("other", "different authorization")]);
    await h.run();
    expect(h.classify.mock.calls.at(-1)?.[1].state.user_intent).toBe("different authorization");
    h.replaceBranch(saved);
    await h.run();
    expect(h.classify.mock.calls.at(-1)?.[1].state.user_intent).toBe(INTENT);
    expect(h.confirm).not.toHaveBeenCalled();
  });
});

describe("Permission Gate integrated manual path and SQL guards", () => {
  it.each(["write", "edit"])("protects %s paths without asking Jev", async (toolName) => {
    const h = harness();
    h.confirm.mockResolvedValue(false);
    expect(await h.runInput({ path: "/repo/.env" }, toolName)).toEqual({
      block: true,
      reason: "Protected path: .env",
    });
    expect(h.confirm).toHaveBeenCalledOnce();
    expect(h.confirm.mock.calls[0][0]).toBe("🛡️ Protected Path");
    expect(h.classify).not.toHaveBeenCalled();
    expect(h.abort).toHaveBeenCalledOnce();
  });

  it.each(["on", "off"])("keeps SQL/path manual with Jev %s", async (setting) => {
    const h = harness();
    await h.gate(`jev ${setting}`);
    expect(await h.runInput({ sql: "SELECT 1" }, "mcp__db__execute_sql")).toBeUndefined();
    expect(h.confirm).not.toHaveBeenCalled();
    expect(
      await h.runInput({ sql: "UPDATE data SET value = 1" }, "mcp__db__execute_sql"),
    ).toBeUndefined();
    expect(h.confirm).toHaveBeenCalledOnce();
    expect(h.confirm.mock.calls[0][0]).toBe("⚠️ SQL Guard");
    expect(await h.runInput({ path: "/repo/.env" }, "write")).toBeUndefined();
    expect(h.confirm).toHaveBeenCalledTimes(2);
    expect(h.classify).not.toHaveBeenCalled();
    expect(h.appendEntry).not.toHaveBeenCalled();
  });
});

describe("Permission Gate command integrity before tool execution", () => {
  it.each([COMMAND, "echo harmless", "env rm -rf /repo/dir", "", "  "])(
    "locks every Bash command descriptor without freezing other options: %s",
    async (command) => {
      const h = harness();
      const input = { command, timeout: 10 };
      h.registerToolCall((event) => {
        expect(Object.getOwnPropertyDescriptor(event.input, "command")).toEqual({
          value: command,
          writable: false,
          configurable: false,
          enumerable: true,
        });
        (event.input as Record<string, unknown>).timeout = 20;
      });
      expect(await h.runInput(input)).toBeUndefined();
      expect(input).toEqual({ command, timeout: 20 });
      expect(() => Object.defineProperty(input, "command", { value: "sudo true" })).toThrow(
        TypeError,
      );
      if (command !== COMMAND) {
        expect(h.classify).not.toHaveBeenCalled();
        expect(h.confirm).not.toHaveBeenCalled();
      }
    },
  );

  it.each([COMMAND, "echo harmless", "env rm -rf /repo/dir"])(
    "a later dangerous command mutator throws and blocks before simulated execution: %s",
    async (command) => {
      const h = harness();
      const execute = vi.fn(); // No Bash process is ever created.
      const input = { command, timeout: 10 };
      h.registerToolCall((event) => {
        (event.input as Record<string, unknown>).command = "rm -rf /repo/extra-target; sudo true";
      });
      const executeAfterHandlers = async () => {
        try {
          const outcome = await h.runInput(input);
          if (outcome?.block) return outcome;
          execute(input);
        } catch (error) {
          // Pi's tool execution layer treats tool_call exceptions as a pre-execution failure.
          expect(error).toBeInstanceOf(TypeError);
          return { block: true, reason: "tool_call handler failed" };
        }
      };
      expect(await executeAfterHandlers()).toMatchObject({ block: true });
      expect(execute).not.toHaveBeenCalled();
      expect(input.command).toBe(command);
      expect(h.classify).toHaveBeenCalledTimes(command === COMMAND ? 1 : 0);
      if (command === COMMAND) expect(h.classify.mock.calls[0][1].state.command).toBe(command);
    },
  );

  it("does not freeze unrelated non-Bash tool inputs", async () => {
    const h = harness();
    const input = { command: "echo harmless" };
    h.registerToolCall((event) => {
      (event.input as Record<string, unknown>).command = "changed";
    });
    await h.runInput(input, "codemode");
    expect(input.command).toBe("changed");
    expect(Object.getOwnPropertyDescriptor(input, "command")?.writable).toBe(true);
    expect(h.classify).not.toHaveBeenCalled();
  });
});

describe("Permission Gate Jev local matching and switches", () => {
  it("enables Jev and Git silently by default and resets on a new extension instance", async () => {
    const h = harness();
    await h.gate("");
    expect(h.notify).toHaveBeenLastCalledWith(
      expect.stringContaining("Git approval: ON; Jev auto-approval: ON"),
      "info",
    );
    await h.fire("session_start");
    await h.run();
    await h.run("git reset --hard");
    expect(h.classify).toHaveBeenCalledTimes(2);
    expect(h.confirm).not.toHaveBeenCalled();
    expect(h.notify).toHaveBeenCalledOnce(); // Only the explicit /gate status query.
    await h.gate("jev on");
    expect(h.notify).toHaveBeenLastCalledWith("Jev auto-approval: ON", "info");
    await h.gate("git off");
    await h.gate("jev off");
    const reloaded = harness({ branch: h.branch() });
    await reloaded.gate("");
    expect(reloaded.notify).toHaveBeenLastCalledWith(
      expect.stringContaining("Git approval: ON; Jev auto-approval: ON"),
      "info",
    );
    await reloaded.run("git push");
    expect(reloaded.classify).toHaveBeenCalledOnce();
  });

  it.each([
    ["sudo true", "sudo"],
    ["dd if=source of=target", "dd"],
    ["mkfs.ext4 /dev/sda", "mkfs"],
    ["rm -rf /repo/dir", "rm"],
    ["chmod 777 /repo/file", "chmod"],
    ["chown -R root /repo/dir", "chown"],
    ["chgrp -R root /repo/dir", "chgrp"],
    ["echo data >/dev/sda", "device-write"],
    ["git reset --hard", "git"],
  ] as const)("can auto-approve %s (%s), including nested tool calls", async (text, rule) => {
    const h = harness();
    expect(await h.run(text, "bash", true)).toBeUndefined();
    expect(h.classify).toHaveBeenCalledOnce();
    expect(h.classify.mock.calls[0][1].state.matched_rules).toEqual([rule]);
    expect(h.decisions()[0]).toMatchObject({ rules: [rule], outcome: "auto-approved" });
    expect(h.confirm).not.toHaveBeenCalled();
    expect(h.abort).not.toHaveBeenCalled();
  });

  it.each([
    "echo harmless",
    "git status",
    "rm -f file",
    "rm -rf /tmp/jev-test",
    "rm -rf /var/tmp/jev-test",
    "env rm -rf /repo/dir",
    "",
    "  ",
  ])("does not classify unmatched commands or temporary deletion: %s", async (text) => {
    const h = harness();
    expect(await h.run(text)).toBeUndefined();
    expect(h.classify).not.toHaveBeenCalled();
    expect(h.findOfType).not.toHaveBeenCalled();
    expect(h.confirm).not.toHaveBeenCalled();
    expect(h.appendEntry).not.toHaveBeenCalled();
    expect(h.notify).not.toHaveBeenCalled();
  });

  it.each(["read", "write", "edit", "codemode", "user_bash"])(
    "ignores tool_call for %s",
    async (name) => {
      const h = harness();
      expect(await h.run(COMMAND, name)).toBeUndefined();
      expect(h.classify).not.toHaveBeenCalled();
      expect(h.confirm).not.toHaveBeenCalled();
    },
  );

  it.each([true, false])("still allows parser failure with hasUI=%s", async (hasUI) => {
    const parser = await initializeBashParser();
    vi.spyOn(parser, "parse").mockImplementation(() => {
      throw new Error(SECRET);
    });
    const h = harness({ hasUI });
    expect(await h.run()).toBeUndefined();
    expect(h.classify).not.toHaveBeenCalled();
    expect(h.confirm).not.toHaveBeenCalled();
    expect(h.appendEntry).not.toHaveBeenCalled();
    if (hasUI)
      expect(h.notify).toHaveBeenCalledExactlyOnceWith(
        "Permission Gate: command checks skipped (parser failure)",
        "warning",
      );
    else expect(h.notify).not.toHaveBeenCalled();
    expect(JSON.stringify(h.notify.mock.calls)).not.toContain(SECRET);
  });

  it("allows a missing parser tree without classifying", async () => {
    const parser = await initializeBashParser();
    vi.spyOn(parser, "parse").mockReturnValue(null);
    const h = harness();
    expect(await h.run()).toBeUndefined();
    expect(h.classify).not.toHaveBeenCalled();
    expect(h.confirm).not.toHaveBeenCalled();
  });

  it("git off removes only Git matches, while Jev off asks manually without decision entries", async () => {
    const h = harness();
    await h.gate("git off");
    await h.run("git reset --hard");
    expect(h.classify).not.toHaveBeenCalled();
    await h.run("git reset --hard; rm -rf /repo/dir");
    expect(h.classify.mock.calls[0][1].state.matched_rules).toEqual(["rm"]);
    await h.gate("jev off");
    const count = h.appendEntry.mock.calls.length;
    await h.run();
    expect(h.classify).toHaveBeenCalledOnce();
    expect(h.confirm).toHaveBeenCalledExactlyOnceWith(
      "🔐 Allow this command?",
      expect.stringContaining(COMMAND),
      { signal: expect.any(AbortSignal) },
    );
    expect(h.appendEntry).toHaveBeenCalledTimes(count);
    await h.gate("jev on");
    await h.run();
    expect(h.classify).toHaveBeenCalledTimes(2);
    await h.gate("git on");
    await h.run("git push");
    expect(h.classify).toHaveBeenCalledTimes(3);
  });
});

describe("Permission Gate Jev classifier results", () => {
  it.each([
    [0.8, 0.9, 0.1, "allow"],
    [1, 1, 0, "allow"],
    [0.800001, 0.900001, 0.099999, "allow"],
    [0.799999, 1, 0, "ask"],
    [0.81, 0.94, 0.04, "allow"],
    [0.81, 0.89, 0.04, "ask"],
    [0.81, 0.94, 0.11, "ask"],
    [1, 0.899999, 0, "ask"],
    [1, 1, 0.100001, "ask"],
    [0, 1, 0, "ask"],
    [1, 0, 0, "ask"],
    [1, 1, 1, "ask"],
  ] as const)(
    "thresholds intent=%s scope=%s harm=%s => %s",
    async (intent, scope, harm, action) => {
      const h = harness();
      h.classify.mockResolvedValue(result(intent, scope, harm));
      expect(await h.run()).toBeUndefined();
      expect(h.confirm).toHaveBeenCalledTimes(action === "ask" ? 1 : 0);
      expect(h.decisions()[0].judgment).toEqual({
        action,
        reason: action === "allow" ? "approved" : "uncertain",
        probabilities: { intent_covered: intent, scope_covered: scope, unexpected_harm: harm },
      });
    },
  );

  const malformed = [
    ["missing", undefined],
    ["null", null],
    ["non-bool", { type: "score", score: 1, confidence: 1 }],
    ["missing probability", { type: "bool" }],
    ["NaN", { type: "bool", probability: NaN }],
    ["Infinity", { type: "bool", probability: Infinity }],
    ["-Infinity", { type: "bool", probability: -Infinity }],
    ["negative", { type: "bool", probability: -0.001 }],
    ["above one", { type: "bool", probability: 1.001 }],
    ["string", { type: "bool", probability: "0.99" }],
    ["boolean", { type: "bool", probability: true }],
  ] as const;
  for (const key of ["intent_covered", "scope_covered", "unexpected_harm"] as const) {
    it.each(malformed)(`asks for malformed ${key}: %s`, async (_label, answer) => {
      const h = harness();
      const response = result();
      // Deliberately emulate invalid wire data; only this fixture escapes ClassifierResult.
      response.answers[key] = answer as unknown as ClassifierResult["answers"][string];
      h.classify.mockResolvedValue(response);
      expect(await h.run()).toBeUndefined();
      expect(h.confirm).toHaveBeenCalledOnce();
      expect(h.decisions()[0].judgment).toEqual({ action: "ask", reason: "invalid-response" });
    });
  }

  it.each([undefined, null, {}])(
    "asks when the answers container is missing/empty: %j",
    async (answers) => {
      const h = harness();
      h.classify.mockResolvedValue({ ...result(), answers } as unknown as ClassifierResult);
      await h.run();
      expect(h.confirm).toHaveBeenCalledOnce();
      expect(h.decisions()[0].judgment.reason).toBe("invalid-response");
    },
  );

  it.each(["error", "aborted"] as const)(
    "provider stopReason=%s cannot auto-approve even with high probabilities",
    async (stopReason) => {
      const h = harness();
      h.classify.mockResolvedValue({ ...result(), stopReason, errorMessage: SECRET });
      await h.run();
      expect(h.confirm).toHaveBeenCalledOnce();
      expect(h.decisions()[0]).toMatchObject({
        judgment: { action: "ask", reason: "unavailable" },
        outcome: "user-approved",
      });
      expect(JSON.stringify(h.appendEntry.mock.calls)).not.toContain(SECRET);
    },
  );

  it.each(["missing model", "lookup error", "request error", "missing credentials"])(
    "asks safely for registry %s",
    async (failure) => {
      const h = harness();
      if (failure === "missing model") h.findOfType.mockReturnValue(undefined);
      if (failure === "lookup error")
        h.findOfType.mockImplementation(() => {
          throw new Error(SECRET);
        });
      if (failure === "request error") h.classify.mockRejectedValue(new Error(SECRET));
      if (failure === "missing credentials")
        h.classify.mockResolvedValue({
          ...result(),
          stopReason: "error",
          errorMessage: `No API key: ${SECRET}`,
        });
      await h.run();
      expect(h.findOfType).toHaveBeenCalledExactlyOnceWith("classifier", "typesafe", "jev-latest");
      expect(h.classify).toHaveBeenCalledTimes(
        failure === "missing model" || failure === "lookup error" ? 0 : 1,
      );
      expect(h.confirm).toHaveBeenCalledOnce();
      expect(h.decisions()[0].judgment).toEqual({ action: "ask", reason: "unavailable" });
      expect(JSON.stringify(h.appendEntry.mock.calls)).not.toContain(SECRET);
      expect(JSON.stringify(h.notify.mock.calls)).not.toContain(SECRET);
    },
  );
});

describe("Permission Gate Jev branch authorization and full input", () => {
  it("uses only the most recent ordinary user on the current branch, never assistant/tool/custom messages", async () => {
    const usage: AssistantMessage["usage"] = {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    };
    const branch: SessionEntry[] = [
      user("older", "older authorization must not be combined"),
      user("latest", [
        { type: "text", text: "Only this" },
        { type: "image", data: "fake-image", mimeType: "image/png" },
        { type: "text", text: "real user text" },
      ]),
      message("assistant", {
        role: "assistant",
        content: [{ type: "text", text: "assistant authorization" }],
        api: "openai-completions",
        provider: "openai",
        model: "mock",
        usage,
        stopReason: "stop",
        timestamp: 0,
      }),
      message("tool", {
        role: "toolResult",
        toolCallId: "call",
        toolName: "bash",
        content: [{ type: "text", text: "tool authorization" }],
        details: undefined,
        isError: false,
        timestamp: 0,
      }),
      {
        type: "custom_message",
        id: "custom",
        parentId: "tool",
        timestamp: TIMESTAMP,
        customType: "notice",
        content: "custom authorization",
        display: false,
      },
      // A user-shaped custom message must not provide ordinary user authorization.
      {
        ...user("injected", "injected authorization"),
        message: {
          role: "user",
          content: "injected authorization",
          customType: "notice",
          timestamp: 0,
        },
      } as unknown as SessionEntry,
    ];
    const h = harness({ branch });
    await h.run();
    expect(h.classify.mock.calls[0][1].state.user_intent).toBe("Only this\nreal user text");
    h.replaceBranch([user("other-branch", "other branch authorization")]);
    await h.run();
    expect(h.classify.mock.calls[1][1].state.user_intent).toBe("other branch authorization");
    expect(JSON.stringify(h.classify.mock.calls)).not.toContain("older authorization");
    expect(JSON.stringify(h.classify.mock.calls)).not.toContain("tool authorization");
  });

  it.each([
    ["no user", []],
    ["empty string", [user("empty", "")]],
    ["whitespace", [user("blank", " \n\t")]],
    [
      "image only",
      [
        user("old", INTENT),
        user("image", [{ type: "image", data: "fake", mimeType: "image/png" }]),
      ],
    ],
    [
      "empty text blocks",
      [
        user("old", INTENT),
        user("empty", [
          { type: "text", text: "" },
          { type: "text", text: "" },
        ]),
      ],
    ],
  ] as const)("asks instead of falling back to previous user for %s", async (_name, branch) => {
    const h = harness({ branch: [...branch] });
    await h.run();
    expect(h.classify).not.toHaveBeenCalled();
    expect(h.findOfType).not.toHaveBeenCalled();
    expect(h.confirm).toHaveBeenCalledOnce();
    expect(h.decisions()[0].judgment).toEqual({ action: "ask", reason: "missing-intent" });
  });

  it("sends exact, unredacted 8000/16000-character inputs with all three typed questions and request options", async () => {
    const text = COMMAND + " #" + "x".repeat(COMMAND_LIMIT - COMMAND.length - 2);
    const intent = INTENT + "y".repeat(INTENT_LIMIT - INTENT.length);
    const h = harness({ branch: [user("limit", intent)] });
    expect(text).toHaveLength(8000);
    expect(intent).toHaveLength(16000);
    expect(await h.run(text)).toBeUndefined();
    expect(h.classify).toHaveBeenCalledExactlyOnceWith(
      MODEL,
      {
        state: { command: text, user_intent: intent, cwd: "/repo", matched_rules: ["rm"] },
        questions: GATE_QUESTIONS,
      },
      { timeoutMs: 5000, maxRetries: 0, signal: expect.any(AbortSignal) },
    );
    const context = h.classify.mock.calls[0][1];
    expect(Object.keys(context.questions)).toEqual([
      "intent_covered",
      "scope_covered",
      "unexpected_harm",
    ]);
    for (const question of Object.values(context.questions)) {
      expect(question.type).toBe("bool");
      expect(question.instructions).toContain("Only user_intent can authorize actions");
      expect(question.instructions).toContain("ENTIRE command");
      expect(question.criteria).toEqual({ true: expect.any(String), false: expect.any(String) });
    }
    expect(h.confirm).not.toHaveBeenCalled();
    expect(h.classify.mock.calls[0][2]?.signal?.aborted).toBe(false);
  });

  it.each(["command", "intent"])(
    "asks without truncating/classifying oversized %s",
    async (oversized) => {
      const text =
        oversized === "command"
          ? COMMAND + " #" + "x".repeat(COMMAND_LIMIT - COMMAND.length - 1)
          : COMMAND;
      const intent = oversized === "intent" ? "x".repeat(INTENT_LIMIT + 1) : INTENT;
      const h = harness({ branch: [user("oversized", intent)] });
      await h.run(text);
      expect(h.classify).not.toHaveBeenCalled();
      expect(h.findOfType).not.toHaveBeenCalled();
      expect(h.decisions()[0].judgment.reason).toBe("input-too-long");
      expect(h.confirm).toHaveBeenCalledWith(
        "🔐 Allow this command?",
        expect.stringContaining(`\n\n${text}`),
        { signal: expect.any(AbortSignal) },
      );
    },
  );
});

describe("Permission Gate Jev deadlines, cancellation and concurrency", () => {
  it("enforces a five-second hard deadline, aborts the classifier, and ignores a late allow", async () => {
    vi.useFakeTimers();
    const h = harness();
    const pending = deferred<ClassifierResult>();
    h.classify.mockReturnValue(pending.promise);
    const operation = h.run();
    await flush();
    expect(h.classify).toHaveBeenCalledOnce();
    const signal = h.classify.mock.calls[0][2]?.signal;
    await vi.advanceTimersByTimeAsync(CLASSIFY_TIMEOUT - 1);
    expect(signal?.aborted).toBe(false);
    expect(h.confirm).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1);
    expect(signal?.aborted).toBe(true);
    expect(await operation).toBeUndefined();
    expect(h.confirm).toHaveBeenCalledOnce();
    expect(h.decisions()[0]).toMatchObject({
      judgment: { action: "ask", reason: "timeout" },
      durationMs: 5000,
      outcome: "user-approved",
    });
    pending.resolve(result());
    await flush();
    expect(h.appendEntry).toHaveBeenCalledOnce();
    expect(h.decisions()[0].outcome).not.toBe("auto-approved");
    expect(vi.getTimerCount()).toBe(0);
  });

  it("a timed-out headless operation stays blocked even after a late allow", async () => {
    vi.useFakeTimers();
    const h = harness({ hasUI: false });
    const pending = deferred<ClassifierResult>();
    h.classify.mockReturnValue(pending.promise);
    const operation = h.run();
    await flush();
    await vi.advanceTimersByTimeAsync(CLASSIFY_TIMEOUT);
    expect(await operation).toEqual({ block: true, reason: "Command requires user confirmation" });
    expect(h.classify.mock.calls[0][2]?.signal?.aborted).toBe(true);
    pending.resolve(result());
    await flush();
    expect(h.decisions()).toHaveLength(1);
    expect(h.decisions()[0]).toMatchObject({
      judgment: { action: "ask", reason: "timeout" },
      outcome: "no-ui",
    });
    expect(h.confirm).not.toHaveBeenCalled();
    expect(vi.getTimerCount()).toBe(0);
  });

  it("cleans the deadline timer after an immediate classifier result", async () => {
    vi.useFakeTimers();
    const h = harness();
    await h.run();
    expect(vi.getTimerCount()).toBe(0);
    await vi.advanceTimersByTimeAsync(CLASSIFY_TIMEOUT);
    expect(h.classify.mock.calls[0][2]?.signal?.aborted).toBe(false);
  });

  it.each([
    "context",
    "session-id",
    "session_before_switch",
    "session_before_tree",
    "session_shutdown",
    "session_start",
  ] as const)(
    "blocks a late allow after %s invalidation without logging into a replacement session/branch",
    async (cause) => {
      const h = harness();
      const pending = deferred<ClassifierResult>();
      h.classify.mockReturnValue(pending.promise);
      const operation = h.run();
      await flush();
      const signal = h.classify.mock.calls[0][2]?.signal;
      if (cause === "context") h.controller.abort();
      else if (cause === "session-id") h.replaceSession("session-2");
      else {
        await h.fire(cause);
        if (cause === "session_before_tree") h.replaceBranch([user("new-branch")]);
        else h.replaceSession("session-2");
      }
      pending.resolve(result());
      expect(await operation).toEqual(CANCELLED);
      expect(h.confirm).not.toHaveBeenCalled();
      expect(h.abort).not.toHaveBeenCalled();
      if (cause === "context") {
        expect(signal?.aborted).toBe(true);
        expect(h.decisions()[0]).toMatchObject({
          judgment: { action: "cancelled", reason: "cancelled" },
          outcome: "cancelled",
        });
      } else {
        expect(h.appendEntry).not.toHaveBeenCalled();
        expect(h.decisions()).toEqual([]);
        if (cause !== "session-id") expect(signal?.aborted).toBe(true);
      }
    },
  );

  it("cancels a running classification immediately even if the provider ignores its signal", async () => {
    vi.useFakeTimers();
    const h = harness();
    const pending = deferred<ClassifierResult>();
    h.classify.mockReturnValue(pending.promise);
    const operation = h.run();
    await flush();
    h.controller.abort();
    expect(await operation).toEqual(CANCELLED);
    expect(h.classify.mock.calls[0][2]?.signal?.aborted).toBe(true);
    expect(vi.getTimerCount()).toBe(0);
    pending.reject(new Error(SECRET));
    await flush();
    expect(h.confirm).not.toHaveBeenCalled();
    expect(h.appendEntry).toHaveBeenCalledOnce();
  });

  it("blocks an already-cancelled context without making a classifier request", async () => {
    const h = harness();
    h.controller.abort();
    expect(await h.run()).toEqual(CANCELLED);
    expect(h.classify).not.toHaveBeenCalled();
    expect(h.confirm).not.toHaveBeenCalled();
  });

  it("does not approve after the latest user message changes during classification", async () => {
    const h = harness();
    const pending = deferred<ClassifierResult>();
    h.classify.mockReturnValue(pending.promise);
    const operation = h.run();
    await flush();
    h.branch().push(user("new-user", "Do not delete anything"));
    pending.resolve(result());
    expect(await operation).toEqual(CANCELLED);
    expect(h.confirm).not.toHaveBeenCalled();
  });

  it("classifies in parallel but serializes confirmation dialogs", async () => {
    const h = harness();
    const a = deferred<ClassifierResult>();
    const b = deferred<ClassifierResult>();
    const dialog = deferred<boolean>();
    h.classify.mockReturnValueOnce(a.promise).mockReturnValueOnce(b.promise);
    h.confirm.mockReturnValueOnce(dialog.promise);
    const first = h.run("rm -rf /repo/first");
    const second = h.run("rm -rf /repo/second");
    await flush();
    expect(h.classify).toHaveBeenCalledTimes(2);
    expect(h.confirm).not.toHaveBeenCalled();
    a.resolve(result(0.5));
    await flush();
    b.resolve(result(0.5));
    await flush();
    expect(h.confirm).toHaveBeenCalledOnce();
    expect(h.emit).toHaveBeenCalledOnce();
    dialog.resolve(true);
    expect(await first).toBeUndefined();
    expect(await second).toBeUndefined();
    expect(h.confirm).toHaveBeenCalledTimes(2);
    expect(h.confirm.mock.calls[0][1]).toContain("/repo/first");
    expect(h.confirm.mock.calls[1][1]).toContain("/repo/second");
    expect(h.decisions().map((decision) => decision.outcome)).toEqual([
      "user-approved",
      "user-approved",
    ]);
  });

  it("denial aborts the operation and suppresses queued confirmations", async () => {
    const h = harness();
    const dialog = deferred<boolean>();
    h.classify.mockResolvedValue(result(0.5));
    h.confirm.mockReturnValueOnce(dialog.promise);
    const first = h.run("rm -rf /repo/first");
    const second = h.run("rm -rf /repo/second");
    await flush();
    expect(h.classify).toHaveBeenCalledTimes(2);
    expect(h.confirm).toHaveBeenCalledOnce();
    dialog.resolve(false);
    expect(await first).toEqual({ block: true, reason: "Blocked by user" });
    expect(await second).toEqual(CANCELLED);
    expect(h.abort).toHaveBeenCalledOnce();
    expect(h.controller.signal.aborted).toBe(true);
    expect(h.confirm).toHaveBeenCalledOnce();
    expect(h.emit).toHaveBeenCalledOnce();
    expect(h.decisions().map((decision) => decision.outcome)).toEqual(["user-denied", "cancelled"]);
  });

  it.each(["false", "throw"])(
    "confirmation cancellation (%s) is not a user denial",
    async (completion) => {
      const h = harness();
      const dialog = deferred<boolean>();
      h.classify.mockResolvedValue(result(0.5));
      h.confirm.mockReturnValue(dialog.promise);
      const operation = h.run();
      await flush();
      expect(h.confirm).toHaveBeenCalledOnce();
      h.controller.abort();
      if (completion === "false") dialog.resolve(false);
      else dialog.reject(new Error(SECRET));
      expect(await operation).toEqual(CANCELLED);
      expect(h.abort).not.toHaveBeenCalled();
      expect(h.decisions()[0].outcome).toBe("cancelled");
      expect(h.decisions()[0].outcome).not.toBe("user-denied");
    },
  );

  it.each(["session_before_switch", "session_before_tree"] as const)(
    "invalidates active and queued dialogs on %s without appending old decisions",
    async (event) => {
      const h = harness();
      const dialog = deferred<boolean>();
      h.classify.mockResolvedValue(result(0.5));
      h.confirm.mockReturnValueOnce(dialog.promise);
      const first = h.run("rm -rf /repo/first");
      const second = h.run("rm -rf /repo/second");
      await flush();
      expect(h.confirm).toHaveBeenCalledOnce();
      const signal = h.confirm.mock.calls[0][2]?.signal;
      await h.fire(event);
      if (event === "session_before_switch") h.replaceSession("session-2");
      else h.replaceBranch([user("replacement-branch")]);
      expect(signal?.aborted).toBe(true);
      dialog.resolve(true);
      expect(await first).toEqual(CANCELLED);
      expect(await second).toEqual(CANCELLED);
      expect(h.confirm).toHaveBeenCalledOnce();
      expect(h.appendEntry).not.toHaveBeenCalled();
      expect(h.abort).not.toHaveBeenCalled();
      // A new lifecycle can still classify and confirm on the replacement branch.
      expect(await h.run("rm -rf /repo/new-operation")).toBeUndefined();
      expect(h.confirm).toHaveBeenCalledTimes(2);
      expect(h.decisions()[0].outcome).toBe("user-approved");
    },
  );

  it("an auto-approval is not held behind another call's confirmation dialog", async () => {
    const h = harness();
    const dialog = deferred<boolean>();
    h.classify.mockResolvedValueOnce(result(0.5)).mockResolvedValueOnce(result());
    h.confirm.mockReturnValueOnce(dialog.promise);
    const first = h.run("rm -rf /repo/first");
    await flush();
    expect(h.confirm).toHaveBeenCalledOnce();
    expect(await h.run("rm -rf /repo/second")).toBeUndefined();
    expect(h.decisions()[0].outcome).toBe("auto-approved");
    expect(h.confirm).toHaveBeenCalledOnce();
    dialog.resolve(true);
    expect(await first).toBeUndefined();
    expect(h.decisions()[1].outcome).toBe("user-approved");
  });

  it("a confirmation error blocks safely and releases the queue for the next dialog", async () => {
    const h = harness();
    h.classify.mockResolvedValue(result(0.5));
    h.confirm.mockRejectedValueOnce(new Error(SECRET));
    const first = h.run("rm -rf /repo/first");
    const second = h.run("rm -rf /repo/second");
    expect(await first).toEqual({ block: true, reason: "User confirmation failed" });
    expect(await second).toBeUndefined();
    expect(h.confirm).toHaveBeenCalledTimes(2);
    expect(h.abort).not.toHaveBeenCalled();
    expect(h.decisions().map((decision) => decision.outcome)).toEqual([
      "confirmation-failed",
      "user-approved",
    ]);
    expect(JSON.stringify(h.appendEntry.mock.calls)).not.toContain(SECRET);
  });
});

describe("Permission Gate Jev logs, commands and headless behavior", () => {
  it("merges/deduplicates rules and sends the complete compound command; stores only bounded summaries", async () => {
    const text = `${COMMAND}; rm -rf /repo/second; sudo true; dd if=a of=b; mkfs /dev/sdb; chmod 777 f; chown -R root dir; chgrp -R root dir; git push; echo '${SECRET}' >/dev/sda`;
    const h = harness();
    await h.run(text);
    const rules = h.classify.mock.calls[0][1].state.matched_rules;
    expect(rules).toHaveLength(9);
    expect(rules).toEqual(expect.arrayContaining(Object.keys(RULE_LABELS)));
    expect(h.classify.mock.calls[0][1].state.command).toBe(text);
    expect(h.classify.mock.calls[0][1].state.user_intent).toBe(INTENT);
    expect(h.appendEntry).toHaveBeenCalledExactlyOnceWith(GATE_ENTRY, {
      version: 1,
      questionVersion: QUESTION_VERSION,
      timestamp: expect.any(String),
      model: "typesafe/jev-latest",
      rules,
      judgment: {
        action: "allow",
        reason: "approved",
        probabilities: { intent_covered: 0.99, scope_covered: 0.99, unexpected_harm: 0.01 },
      },
      durationMs: expect.any(Number),
      outcome: "auto-approved",
    });
    expect(Number.isNaN(Date.parse(h.decisions()[0].timestamp))).toBe(false);
    expect(h.decisions()[0].durationMs).toBeGreaterThanOrEqual(0);
    const logged = JSON.stringify(h.appendEntry.mock.calls);
    expect(logged).not.toContain(SECRET);
    expect(logged).not.toContain(text);
    expect(logged).not.toContain(INTENT);
    expect(h.sendMessage).not.toHaveBeenCalled();
    expect(h.sendUserMessage).not.toHaveBeenCalled();
  });

  it.each(["auto", "manual"])(
    "never caches %s approvals for identical commands",
    async (approval) => {
      const h = harness();
      if (approval === "manual") h.classify.mockResolvedValue(result(0.5));
      await h.run();
      await h.run();
      expect(h.classify).toHaveBeenCalledTimes(2);
      expect(h.confirm).toHaveBeenCalledTimes(approval === "manual" ? 2 : 0);
      expect(h.appendEntry).toHaveBeenCalledTimes(2);
    },
  );

  it("/gate log reads only the current branch's latest 20 summaries without model messages or classification", async () => {
    const h = harness();
    await h.run();
    const record = h.decisions()[0];
    const records: SessionEntry[] = Array.from({ length: 25 }, (_, index) => ({
      type: "custom",
      id: `record-${index}`,
      parentId: null,
      timestamp: TIMESTAMP,
      customType: GATE_ENTRY,
      data: { ...record, timestamp: `decision-${index.toString().padStart(2, "0")}` },
    }));
    h.replaceBranch([
      user(),
      ...records,
      {
        type: "custom",
        id: "foreign",
        parentId: null,
        timestamp: TIMESTAMP,
        customType: "other-extension",
        data: { ...record, timestamp: "FOREIGN" },
      },
      {
        type: "custom",
        id: "old-version",
        parentId: null,
        timestamp: TIMESTAMP,
        customType: GATE_ENTRY,
        data: { ...record, version: 2, timestamp: "UNSUPPORTED" },
      },
    ]);
    h.classify.mockClear();
    h.notify.mockClear();
    const count = h.appendEntry.mock.calls.length;
    await h.gate("log");
    expect(h.notify).toHaveBeenCalledOnce();
    const output = h.notify.mock.calls[0][0];
    expect(output.match(/decision-\d+/g)).toHaveLength(20);
    expect(output).toContain("decision-05");
    expect(output).toContain("decision-24");
    expect(output).not.toContain("decision-04");
    expect(output).not.toContain("FOREIGN");
    expect(output).not.toContain("UNSUPPORTED");
    expect(output).toContain("intent=0.990 scope=0.990 unexpected_harm=0.010");
    expect(output).toContain("typesafe/jev-latest");
    expect(output).toContain(`questions v${QUESTION_VERSION}`);
    expect(output).not.toContain(SECRET);
    h.replaceBranch([user("different")]);
    await h.gate("log");
    expect(h.notify).toHaveBeenLastCalledWith("No Jev decisions on this branch.", "info");
    expect(h.classify).not.toHaveBeenCalled();
    expect(h.sendMessage).not.toHaveBeenCalled();
    expect(h.sendUserMessage).not.toHaveBeenCalled();
    expect(h.appendEntry).toHaveBeenCalledTimes(count);
  });

  it("formats an unavailable decision without probability scores", async () => {
    const h = harness();
    h.findOfType.mockReturnValue(undefined);
    await h.run();
    await h.gate("log");
    expect(h.notify).toHaveBeenLastCalledWith(expect.stringContaining("Jev unavailable"), "info");
    expect(h.notify.mock.calls.at(-1)?.[0]).not.toContain("intent=");
  });

  it.each([
    "on",
    "off",
    "all off",
    "git invalid",
    "git off extra",
    "jev invalid",
    "jev off extra",
    "log extra",
    "log on",
  ])("rejects invalid /gate %s without changing state", async (args) => {
    const h = harness();
    await h.gate(args);
    expect(h.notify).toHaveBeenLastCalledWith(USAGE, "error");
    await h.gate("");
    expect(h.notify).toHaveBeenLastCalledWith(
      expect.stringContaining("Git approval: ON; Jev auto-approval: ON"),
      "info",
    );
    await h.run("git push");
    expect(h.classify).toHaveBeenCalledOnce();
    expect(h.confirm).not.toHaveBeenCalled();
  });

  it("reports each toggle, normalizes case/whitespace, and completes Jev/Git/log arguments", async () => {
    const h = harness();
    await h.gate(" JEV  OFF ");
    expect(h.notify).toHaveBeenLastCalledWith("Jev auto-approval: OFF", "info");
    await h.gate("jev");
    expect(h.notify).toHaveBeenLastCalledWith("Jev auto-approval: OFF", "info");
    await h.gate("git off");
    await h.gate("");
    expect(h.notify).toHaveBeenLastCalledWith(
      expect.stringContaining("Git approval: OFF; Jev auto-approval: OFF"),
      "info",
    );
    const completions = h.gateCommand.getArgumentCompletions!;
    expect(await completions("")).toEqual(
      ["git", "jev", "log"].map((value) => ({ value, label: value })),
    );
    expect(await completions("j")).toEqual([{ value: "jev", label: "jev" }]);
    expect(await completions("jev ")).toEqual(
      ["jev on", "jev off"].map((value) => ({ value, label: value })),
    );
    expect(await completions("git ")).toEqual(
      ["git on", "git off"].map((value) => ({ value, label: value })),
    );
    expect(await completions(" JEV ON")).toEqual([{ value: "jev on", label: "jev on" }]);
    expect(await completions("lo")).toEqual([{ value: "log", label: "log" }]);
    expect(await completions("unknown")).toBeNull();
    expect(await completions("jev invalid")).toBeNull();
  });

  it("auto-approves without UI but blocks an ask without prompting or aborting", async () => {
    const h = harness({ hasUI: false });
    expect(await h.run()).toBeUndefined();
    expect(h.decisions()[0].outcome).toBe("auto-approved");
    h.classify.mockResolvedValue(result(0.5));
    expect(await h.run()).toEqual({ block: true, reason: "Command requires user confirmation" });
    expect(h.decisions()[1]).toMatchObject({
      judgment: { action: "ask", reason: "uncertain" },
      outcome: "no-ui",
    });
    expect(h.confirm).not.toHaveBeenCalled();
    expect(h.notify).not.toHaveBeenCalled();
    expect(h.emit).not.toHaveBeenCalled();
    expect(h.abort).not.toHaveBeenCalled();
    await h.gate("jev off");
    expect(await h.run()).toEqual({ block: true, reason: "Command requires user confirmation" });
    expect(h.classify).toHaveBeenCalledTimes(2);
    expect(h.decisions()).toHaveLength(2);
  });
});
