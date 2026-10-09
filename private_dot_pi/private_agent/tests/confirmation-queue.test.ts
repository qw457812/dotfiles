import type {
  ExtensionAPI,
  ExtensionContext,
  ExtensionHandler,
  ToolCallEvent,
  ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";
import { beforeAll, describe, expect, it, vi } from "vitest";
import permissionGate from "../extensions/permission-gate/index.ts";
import safeGuard from "../extensions/safe-guard.ts";
import sqlGuard from "../extensions/sql-guard.ts";
import { initializeBashParser } from "../lib/bash-parser.ts";
import { withConfirmationQueue } from "../lib/confirmation-queue.ts";

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

type Guard = "gate" | "safe" | "sql";
type ToolHandler = ExtensionHandler<ToolCallEvent, ToolCallEventResult>;
const GUARDS: Guard[] = ["gate", "safe", "sql"];
const TITLES: Record<Guard, string> = {
  gate: "🔐 Allow this command?",
  safe: "🛡️ Protected Path",
  sql: "⚠️ SQL Guard",
};
const INPUTS: Record<Guard, { toolName: string; input: Record<string, unknown> }> = {
  gate: { toolName: "bash", input: { command: "rm -rf /repo/queue-test" } },
  safe: { toolName: "write", input: { path: "/repo/.env", content: "fixture-only" } },
  sql: { toolName: "mcp__db__execute_sql", input: { sql: "DROP TABLE queue_test" } },
};

// Register all three real extensions against mock APIs and one shared UI.
// Only dispatch tool_call handlers: never create a process, write a file or call SQL/API tools.
function harness(ui = mockUI()) {
  const handlers: ToolHandler[] = [];
  const emits = {
    gate: vi.fn<ExtensionAPI["events"]["emit"]>(),
    safe: vi.fn<ExtensionAPI["events"]["emit"]>(),
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
    sessionManager: { getBranch: () => [], getSessionId: () => "queue-test" },
    modelRegistry: { findOfType: vi.fn(() => undefined), classify },
  } as unknown as ExtensionContext;
  for (const [kind, extension] of [
    ["gate", permissionGate],
    ["safe", safeGuard],
    ["sql", sqlGuard],
  ] as const) {
    extension({
      on(name: string, callback: ToolHandler) {
        if (name === "tool_call") handlers.push(callback);
        return () => {};
      },
      registerCommand: vi.fn(),
      appendEntry,
      events: { emit: emits[kind] },
    } as unknown as ExtensionAPI);
  }
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

describe("withConfirmationQueue", () => {
  it("preserves FIFO and callback return values without starting overlapping work", async () => {
    const ui = mockUI() as unknown as ExtensionContext["ui"];
    const head = deferred<string>();
    const order: string[] = [];
    const first = withConfirmationQueue(ui, async () => {
      order.push("first");
      return head.promise;
    });
    const second = withConfirmationQueue(ui, async () => {
      order.push("second");
      return "second-result";
    });
    const third = withConfirmationQueue(ui, async () => {
      order.push("third");
      return "third-result";
    });
    await flush();
    expect(order).toEqual(["first"]);
    head.resolve("first-result");
    expect(await Promise.all([first, second, third])).toEqual([
      "first-result",
      "second-result",
      "third-result",
    ]);
    expect(order).toEqual(["first", "second", "third"]);
  });

  it("propagates a throw but releases queued work and permits later reuse", async () => {
    const ui = mockUI() as unknown as ExtensionContext["ui"];
    const head = deferred<void>();
    const error = new Error("mock queue failure");
    const first = withConfirmationQueue(ui, async () => {
      await head.promise;
      throw error;
    });
    const failed = expect(first).rejects.toBe(error);
    const next = vi.fn(async () => "next");
    const second = withConfirmationQueue(ui, next);
    await flush();
    expect(next).not.toHaveBeenCalled();
    head.resolve();
    await failed;
    expect(await second).toBe("next");
    expect(await withConfirmationQueue(ui, async () => "reused")).toBe("reused");
  });

  it("uses UI identity rather than confirm-function identity", async () => {
    const sharedConfirm = vi.fn<ExtensionContext["ui"]["confirm"]>();
    const a = { ...mockUI(), confirm: sharedConfirm } as unknown as ExtensionContext["ui"];
    const b = { ...mockUI(), confirm: sharedConfirm } as unknown as ExtensionContext["ui"];
    const head = deferred<void>();
    const first = withConfirmationQueue(a, async () => head.promise);
    const independent = vi.fn(async () => "independent");
    expect(await withConfirmationQueue(b, independent)).toBe("independent");
    expect(independent).toHaveBeenCalledOnce();
    head.resolve();
    await first;
  });
});

describe("real Gate/SafeGuard/SQLGuard shared confirmation scheduling", () => {
  it.each([
    ["gate", "safe", "sql"],
    ["safe", "gate", "sql"],
    ["sql", "safe", "gate"],
  ] as const)("%s holds the dialog while %s and %s wait in FIFO order", async (a, b, c) => {
    const h = harness();
    const dialogs = [deferred<boolean>(), deferred<boolean>(), deferred<boolean>()];
    for (const dialog of dialogs) h.ui.confirm.mockReturnValueOnce(dialog.promise);
    const first = h.run(a);
    await flush();
    expect(h.ui.confirm).toHaveBeenCalledOnce();
    const second = h.run(b);
    await flush(); // Gate may parse before reaching the shared queue.
    const third = h.run(c);
    await flush();
    expect(h.ui.confirm.mock.calls.map(([title]) => title)).toEqual([TITLES[a]]);
    expect(h.emits[a]).toHaveBeenCalledOnce();
    expect(h.emits[b]).not.toHaveBeenCalled();
    expect(h.emits[c]).not.toHaveBeenCalled();
    dialogs[0].resolve(true);
    expect(await first).toBeUndefined();
    await flush();
    expect(h.ui.confirm.mock.calls.map(([title]) => title)).toEqual([TITLES[a], TITLES[b]]);
    expect(h.emits[b]).toHaveBeenCalledOnce();
    expect(h.emits[c]).not.toHaveBeenCalled();
    dialogs[1].resolve(true);
    expect(await second).toBeUndefined();
    await flush();
    expect(h.ui.confirm.mock.calls.map(([title]) => title)).toEqual([
      TITLES[a],
      TITLES[b],
      TITLES[c],
    ]);
    dialogs[2].resolve(true);
    expect(await third).toBeUndefined();
    expect(h.emits[c]).toHaveBeenCalledOnce();
    expect(h.classify).not.toHaveBeenCalled();
    for (const [, , options] of h.ui.confirm.mock.calls)
      expect(options?.signal).toBeInstanceOf(AbortSignal);
  });

  it.each(GUARDS)("cancellation suppresses queued dialogs behind active %s", async (active) => {
    const h = harness();
    const dialog = deferred<boolean>();
    h.ui.confirm.mockReturnValueOnce(dialog.promise);
    const first = h.run(active);
    await flush();
    const queuedGuards = GUARDS.filter((guard) => guard !== active);
    const queued = queuedGuards.map((guard) => h.run(guard));
    await flush();
    expect(h.ui.confirm).toHaveBeenCalledOnce();
    const signal = h.ui.confirm.mock.calls[0][2]?.signal;
    h.controller.abort();
    expect(signal?.aborted).toBe(true);
    dialog.resolve(true); // A late accept must not authorize a cancelled tool call.
    const outcomes = await Promise.all([first, ...queued]);
    for (const outcome of outcomes) expect(outcome).toMatchObject({ block: true });
    expect(h.abort).not.toHaveBeenCalled();
    expect(h.ui.confirm).toHaveBeenCalledOnce();
    for (const guard of queuedGuards) expect(h.emits[guard]).not.toHaveBeenCalled();
  });

  it.each(GUARDS)(
    "denial by %s aborts once and suppresses other guards' queued dialogs",
    async (denied) => {
      const h = harness();
      const dialog = deferred<boolean>();
      h.ui.confirm.mockReturnValueOnce(dialog.promise);
      const first = h.run(denied);
      await flush();
      const queuedGuards = GUARDS.filter((guard) => guard !== denied);
      const queued = queuedGuards.map((guard) => h.run(guard));
      await flush();
      expect(h.ui.confirm).toHaveBeenCalledOnce();
      dialog.resolve(false);
      const outcomes = await Promise.all([first, ...queued]);
      for (const outcome of outcomes) expect(outcome).toMatchObject({ block: true });
      expect(h.abort).toHaveBeenCalledOnce();
      expect(h.controller.signal.aborted).toBe(true);
      expect(h.ui.confirm).toHaveBeenCalledOnce();
      for (const guard of queuedGuards) expect(h.emits[guard]).not.toHaveBeenCalled();
      if (denied === "gate")
        expect(outcomes[0]).toEqual({ block: true, reason: "Blocked by user" });
    },
  );

  it.each(GUARDS)(
    "a throwing %s dialog releases the shared queue for both other guards",
    async (throwing) => {
      const h = harness();
      const dialog = deferred<boolean>();
      const error = new Error("mock dialog failure");
      h.ui.confirm.mockReturnValueOnce(dialog.promise);
      const first = h.run(throwing);
      // Safe/SQL propagate to Pi's pre-execution error boundary; Gate returns a block.
      const failed =
        throwing === "gate"
          ? expect(first).resolves.toEqual({ block: true, reason: "User confirmation failed" })
          : expect(first).rejects.toBe(error);
      await flush();
      const otherGuards = GUARDS.filter((guard) => guard !== throwing);
      const queued = otherGuards.map((guard) => h.run(guard));
      await flush();
      expect(h.ui.confirm).toHaveBeenCalledOnce();
      dialog.reject(error);
      await failed;
      expect(await Promise.all(queued)).toEqual([undefined, undefined]);
      expect(h.ui.confirm).toHaveBeenCalledTimes(3);
      expect(h.ui.confirm.mock.calls[0][0]).toBe(TITLES[throwing]);
      expect(
        h.ui.confirm.mock.calls
          .slice(1)
          .map(([title]) => title)
          .sort(),
      ).toEqual(otherGuards.map((guard) => TITLES[guard]).sort());
      expect(h.abort).not.toHaveBeenCalled();
      for (const guard of GUARDS) expect(h.emits[guard]).toHaveBeenCalledOnce();
    },
  );

  it.each(["safe", "sql"] as const)(
    "%s passes ctx.signal unchanged to its active confirmation",
    async (guard) => {
      const h = harness();
      await h.run(guard);
      expect(h.ui.confirm).toHaveBeenCalledExactlyOnceWith(TITLES[guard], expect.any(String), {
        signal: h.controller.signal,
      });
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

  it("cancelling a queued guard's context does not cancel the active guard's different context", async () => {
    const h = harness();
    const dialog = deferred<boolean>();
    h.ui.confirm.mockReturnValueOnce(dialog.promise);
    const first = h.run("safe");
    await flush();
    const queuedController = new AbortController();
    const queuedCtx = { ...h.ctx, signal: queuedController.signal };
    const second = h.run("gate", queuedCtx);
    const third = h.run("sql", queuedCtx);
    await flush();
    queuedController.abort();
    expect(h.controller.signal.aborted).toBe(false);
    dialog.resolve(true);
    expect(await first).toBeUndefined();
    for (const outcome of await Promise.all([second, third]))
      expect(outcome).toMatchObject({ block: true });
    expect(h.ui.confirm).toHaveBeenCalledOnce();
    expect(h.emits.gate).not.toHaveBeenCalled();
    expect(h.emits.sql).not.toHaveBeenCalled();
    expect(h.abort).not.toHaveBeenCalled();
  });

  it("distinct extension instances still serialize on the same UI", async () => {
    const ui = mockUI();
    const a = harness(ui);
    const b = harness(ui);
    const dialog = deferred<boolean>();
    ui.confirm.mockReturnValueOnce(dialog.promise);
    const first = a.run("safe");
    await flush();
    const second = b.run("gate");
    await flush();
    expect(ui.confirm).toHaveBeenCalledOnce();
    dialog.resolve(true);
    expect(await Promise.all([first, second])).toEqual([undefined, undefined]);
    expect(ui.confirm.mock.calls.map(([title]) => title)).toEqual([TITLES.safe, TITLES.gate]);
  });

  it("different UI objects allow independent dialogs to progress concurrently", async () => {
    const a = harness();
    const b = harness();
    const dialogs = [deferred<boolean>(), deferred<boolean>()];
    a.ui.confirm.mockReturnValueOnce(dialogs[0].promise);
    b.ui.confirm.mockReturnValueOnce(dialogs[1].promise);
    const first = a.run("gate");
    await flush();
    const second = b.run("safe");
    await flush();
    expect(a.ui.confirm).toHaveBeenCalledOnce();
    expect(b.ui.confirm).toHaveBeenCalledOnce();
    dialogs[1].resolve(true);
    expect(await second).toBeUndefined(); // The Gate dialog on the other UI is still pending.
    expect(a.controller.signal.aborted).toBe(false);
    dialogs[0].resolve(true);
    expect(await first).toBeUndefined();
  });
});
