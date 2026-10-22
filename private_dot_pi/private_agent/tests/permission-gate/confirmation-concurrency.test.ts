import type {
  ExtensionAPI,
  ExtensionContext,
  ExtensionHandler,
  ToolCallEvent,
  ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";
import { beforeAll, describe, expect, it, vi } from "vitest";
import permissionGate from "../../extensions/permission-gate/index.ts";
import { initializeBashParser } from "../../lib/bash-parser.ts";

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

async function flush() {
  for (let i = 0; i < 80; i++) await Promise.resolve();
}

function mockUI() {
  const confirm = vi.fn<ExtensionContext["ui"]["confirm"]>().mockResolvedValue(true);
  const notify = vi.fn<ExtensionContext["ui"]["notify"]>();
  return { confirm, notify };
}

type Guard = "gate" | "path" | "sql";
type ToolHandler = ExtensionHandler<ToolCallEvent, ToolCallEventResult>;
const GUARDS: Guard[] = ["gate", "path", "sql"];
const TITLES: Record<Guard, string> = {
  gate: "🔐 Allow this command?",
  path: "🛡️ Protected Path",
  sql: "⚠️ SQL Guard",
};
const INPUTS: Record<Guard, { toolName: string; input: Record<string, unknown> }> = {
  gate: { toolName: "bash", input: { command: "rm -rf /repo/confirmation-test" } },
  path: { toolName: "write", input: { path: "/repo/.env", content: "fixture-only" } },
  sql: { toolName: "mcp__db__execute_sql", input: { sql: "DROP TABLE confirmation_test" } },
};

// Register the unified index against a mock API and one shared UI.
// Only dispatch tool_call handlers: never create a process, write a file or call SQL/API tools.
function harness(ui = mockUI()) {
  const handlers: ToolHandler[] = [];
  const emits = {
    gate: vi.fn<ExtensionAPI["events"]["emit"]>(),
    path: vi.fn<ExtensionAPI["events"]["emit"]>(),
    sql: vi.fn<ExtensionAPI["events"]["emit"]>(),
  };
  const controller = new AbortController();
  const abort = vi.fn(() => controller.abort());
  const classify = vi.fn<ExtensionContext["modelRegistry"]["classify"]>();
  const appendEntry = vi.fn<ExtensionAPI["appendEntry"]>();
  const ctx = {
    cwd: "/repo",
    mode: "tui",
    hasUI: true,
    ui,
    signal: controller.signal,
    abort,
    sessionManager: { getBranch: () => [], getSessionId: () => "confirmation-test" },
    modelRegistry: { findOfType: vi.fn(() => undefined), classify },
  } as unknown as ExtensionContext;
  permissionGate({
    on(name: string, callback: ToolHandler) {
      if (name === "tool_call") handlers.push(callback);
      return () => {};
    },
    registerCommand: vi.fn(),
    appendEntry,
    events: {
      emit(name: string, data: { title: string }) {
        const guard: Guard =
          data.title === TITLES.gate ? "gate" : data.title === TITLES.path ? "path" : "sql";
        emits[guard](name, data);
      },
    },
  } as unknown as ExtensionAPI);
  expect(handlers).toHaveLength(3);
  let callId = 0;
  return {
    ctx,
    ui,
    emits,
    controller,
    abort,
    classify,
    appendEntry,
    run: async (guard: Guard, context = ctx) => {
      const fixture = INPUTS[guard];
      const event: ToolCallEvent = {
        type: "tool_call",
        toolCallId: `mock-${++callId}`,
        toolName: fixture.toolName,
        input: { ...fixture.input }, // Gate locks this per-call input, not the fixture.
      };
      for (const handler of handlers) {
        const outcome = await handler(event, context);
        if (outcome?.block) return outcome;
      }
    },
  };
}

beforeAll(async () => {
  await initializeBashParser();
});

describe("concurrent Gate/PathGuard/SQLGuard confirmations", () => {
  it.each([
    ["gate", "path", "sql"],
    ["path", "gate", "sql"],
    ["sql", "path", "gate"],
  ] as const)("%s, %s and %s open without waiting for another confirmation", async (a, b, c) => {
    const h = harness();
    const dialogs = [deferred<boolean>(), deferred<boolean>(), deferred<boolean>()];
    for (const dialog of dialogs) h.ui.confirm.mockReturnValueOnce(dialog.promise);
    const operations = [];
    for (const guard of [a, b, c]) {
      operations.push(h.run(guard));
      await flush();
    }
    expect(h.ui.confirm.mock.calls.map(([title]) => title)).toEqual([
      TITLES[a],
      TITLES[b],
      TITLES[c],
    ]);
    for (const guard of GUARDS) expect(h.emits[guard]).toHaveBeenCalledOnce();
    // Pi shows the newest dialog first; every result still belongs to its own call.
    for (const i of [2, 1, 0]) {
      dialogs[i].resolve(true);
      expect(await operations[i]).toBeUndefined();
    }
    expect(h.classify).not.toHaveBeenCalled();
    expect(h.abort).not.toHaveBeenCalled();
    for (const [, , options] of h.ui.confirm.mock.calls)
      expect(options?.signal).toBeInstanceOf(AbortSignal);
  });

  it("cancellation blocks every pending guard even if its UI returns a late approval", async () => {
    const h = harness();
    const dialog = deferred<boolean>();
    h.ui.confirm.mockReturnValue(dialog.promise);
    const operations = GUARDS.map((guard) => h.run(guard));
    await flush();
    expect(h.ui.confirm).toHaveBeenCalledTimes(3);
    h.controller.abort();
    for (const [, , options] of h.ui.confirm.mock.calls)
      expect(options?.signal?.aborted).toBe(true);
    dialog.resolve(true);
    for (const outcome of await Promise.all(operations))
      expect(outcome).toMatchObject({ block: true });
    expect(h.abort).not.toHaveBeenCalled();
  });

  it.each(GUARDS)(
    "denial by %s cancels sibling dialogs without authorizing their tools",
    async (denied) => {
      const h = harness();
      const dialogs = new Map<string, ReturnType<typeof deferred<boolean>>>();
      h.ui.confirm.mockImplementation((title, _message, options) => {
        const dialog = deferred<boolean>();
        dialogs.set(title, dialog);
        const onAbort = () => dialog.resolve(false);
        options?.signal?.addEventListener("abort", onAbort, { once: true });
        return dialog.promise.finally(() => options?.signal?.removeEventListener("abort", onAbort));
      });
      const operations = GUARDS.map((guard) => h.run(guard));
      await flush();
      expect(h.ui.confirm).toHaveBeenCalledTimes(3);
      dialogs.get(TITLES[denied])!.resolve(false);
      const outcomes = await Promise.all(operations);
      for (const outcome of outcomes) expect(outcome).toMatchObject({ block: true });
      expect(outcomes[GUARDS.indexOf(denied)]).toEqual({ block: true, reason: "Blocked by user" });
      expect(h.abort).toHaveBeenCalledOnce();
      expect(h.controller.signal.aborted).toBe(true);
      for (const [, , options] of h.ui.confirm.mock.calls)
        expect(options?.signal?.aborted).toBe(true);
    },
  );

  it.each(GUARDS)(
    "a failing %s dialog does not prevent other guards from completing",
    async (throwing) => {
      const h = harness();
      const dialog = deferred<boolean>();
      h.ui.confirm.mockReturnValueOnce(dialog.promise);
      const first = h.run(throwing);
      await flush();
      const others = GUARDS.filter((guard) => guard !== throwing).map((guard) => h.run(guard));
      expect(await Promise.all(others)).toEqual([undefined, undefined]);
      dialog.reject(new Error("private dialog failure"));
      expect(await first).toEqual({ block: true, reason: "User confirmation failed" });
      expect(h.ui.confirm).toHaveBeenCalledTimes(3);
      expect(h.abort).not.toHaveBeenCalled();
    },
  );

  it.each(["path", "sql"] as const)(
    "%s propagates parent cancellation to its confirmation",
    async (guard) => {
      const h = harness();
      await h.run(guard);
      const signal = h.ui.confirm.mock.calls[0][2]?.signal;
      expect(signal).toBeInstanceOf(AbortSignal);
      expect(signal?.aborted).toBe(false);
      h.controller.abort();
      expect(signal?.aborted).toBe(true);
    },
  );

  it.each(GUARDS)("an already-aborted %s call never opens or notifies a dialog", async (guard) => {
    const h = harness();
    h.controller.abort();
    expect(await h.run(guard)).toMatchObject({ block: true });
    expect(h.ui.confirm).not.toHaveBeenCalled();
    expect(h.emits[guard]).not.toHaveBeenCalled();
    expect(h.abort).not.toHaveBeenCalled();
  });

  it("cancelling a different context on the same UI leaves its peer confirmation active", async () => {
    const h = harness();
    const dialogs = [deferred<boolean>(), deferred<boolean>(), deferred<boolean>()];
    for (const dialog of dialogs) h.ui.confirm.mockReturnValueOnce(dialog.promise);
    const first = h.run("path");
    await flush();
    const controller = new AbortController();
    const ctx = { ...h.ctx, signal: controller.signal };
    const others = [h.run("gate", ctx), h.run("sql", ctx)];
    await flush();
    expect(h.ui.confirm).toHaveBeenCalledTimes(3);
    controller.abort();
    expect(h.controller.signal.aborted).toBe(false);
    dialogs[1].resolve(true);
    dialogs[2].resolve(true);
    for (const outcome of await Promise.all(others)) expect(outcome).toMatchObject({ block: true });
    dialogs[0].resolve(true);
    expect(await first).toBeUndefined();
    expect(h.abort).not.toHaveBeenCalled();
  });

  it("distinct extension instances can open confirmations on the same UI concurrently", async () => {
    const ui = mockUI();
    const a = harness(ui);
    const b = harness(ui);
    const dialogs = [deferred<boolean>(), deferred<boolean>()];
    for (const dialog of dialogs) ui.confirm.mockReturnValueOnce(dialog.promise);
    const first = a.run("path");
    await flush();
    const second = b.run("gate");
    await flush();
    expect(ui.confirm.mock.calls.map(([title]) => title)).toEqual([TITLES.path, TITLES.gate]);
    dialogs[1].resolve(true);
    expect(await second).toBeUndefined();
    dialogs[0].resolve(true);
    expect(await first).toBeUndefined();
  });

  it("different UI objects allow independent dialogs to complete", async () => {
    const a = harness();
    const b = harness();
    const dialogs = [deferred<boolean>(), deferred<boolean>()];
    a.ui.confirm.mockReturnValueOnce(dialogs[0].promise);
    b.ui.confirm.mockReturnValueOnce(dialogs[1].promise);
    const first = a.run("gate");
    await flush();
    const second = b.run("path");
    await flush();
    expect(a.ui.confirm).toHaveBeenCalledOnce();
    expect(b.ui.confirm).toHaveBeenCalledOnce();
    dialogs[1].resolve(true);
    expect(await second).toBeUndefined();
    expect(a.controller.signal.aborted).toBe(false);
    dialogs[0].resolve(true);
    expect(await first).toBeUndefined();
  });
});
