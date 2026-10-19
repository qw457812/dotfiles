import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => {
  const construct = vi.fn();
  class ModalEditor {
    private text = "";
    borderColor = (text: string) => text;
    history: string[] = [];
    historyIndex = -1;
    onSubmit?: (text: string) => void;
    onChange?: (text: string) => void;
    setClipboardMirrorPolicy = vi.fn();
    setQuitFn = vi.fn<(fn: () => void) => void>();
    setNotifyFn = vi.fn<(fn: (message: string) => void) => void>();
    setModeChangeFn = vi.fn<(fn: (event: unknown) => void) => void>();
    setExCommandSettings = vi.fn();
    setCommandNamesFn = vi.fn<(fn: () => ReadonlySet<string>) => void>();
    constructor(...args: unknown[]) {
      construct(...args);
    }
    getMode() {
      return "insert";
    }
    getText() {
      return this.text;
    }
    setText(text: string) {
      this.text = text;
    }
    addToHistory(text: string) {
      const trimmed = text.trim();
      if (trimmed && this.history[0] !== trimmed) this.history.unshift(trimmed);
    }
  }
  return {
    ModalEditor,
    construct,
    readdir: vi.fn(),
    stat: vi.fn(),
    open: vi.fn(),
    writeFileSync: vi.fn(),
    readSettings: vi.fn(),
    cancelModeChangeCommands: vi.fn(),
    clipboard: vi.fn(),
    cursor: {
      install: vi.fn(),
      syncPreference: vi.fn(),
      render: vi.fn(),
      setFocused: vi.fn(),
      modeChanged: vi.fn(),
      shutdown: vi.fn(),
    },
  };
});

// Isolate wrapper generation and history IO: no writes to source or the user's
// agent directory. Keep the real entry point and prompt-history implementation.
vi.mock("node:fs", async (original) => ({
  ...(await original<typeof import("node:fs")>()),
  existsSync: () => true,
  readFileSync: () => "test wrapper",
  writeFileSync: mocks.writeFileSync,
}));
vi.mock("node:fs/promises", async (original) => {
  const actual = await original<typeof import("node:fs/promises")>();
  return {
    ...actual,
    default: { ...actual, readdir: mocks.readdir, stat: mocks.stat, open: mocks.open },
  };
});
vi.mock("@earendil-works/pi-coding-agent", () => ({
  CONFIG_DIR_NAME: ".pi",
  getAgentDir: () => "/test/agent",
  CustomEditor: mocks.ModalEditor,
}));
vi.mock("../../extensions/prompt-editor/pi-vim.generated.ts", () => ({
  ModalEditor: mocks.ModalEditor,
  readPiVimSettings: mocks.readSettings,
  resolveClipboardMirrorPolicy: (policy: string) => ({ policy }),
  resolveExCommandSettings: (settings: unknown) => ({ settings }),
  resolveModeColors: () => ({}),
  resolveSurfaceSyncMaps: () => ({ borderSync: {}, labelSync: {} }),
  buildModeColorizers: () =>
    Object.fromEntries(
      ["insert", "normal", "visual", "ex"].map((mode) => [mode, (text: string) => text]),
    ),
  buildOffBorderColor: () => (text: string) => text,
  createModeChangeHandler: (_settings: unknown, emit: (event: unknown) => void) => emit,
  cancelModeChangeCommands: mocks.cancelModeChangeCommands,
}));
vi.mock("../../extensions/prompt-editor/clipboard.ts", () => ({
  installClipboardBridge: mocks.clipboard,
}));
vi.mock("../../extensions/prompt-editor/cursor.ts", () => ({
  createCursorController: () => mocks.cursor,
}));

import promptEditor from "../../extensions/prompt-editor/index.ts";

type Editor = InstanceType<typeof mocks.ModalEditor>;
type Factory = (...args: unknown[]) => Editor;
type Handler = (event: unknown, ctx: ExtensionContext) => unknown;

function host(initialText = "draft") {
  const defaultEditor = new mocks.ModalEditor();
  defaultEditor.setText(initialText);
  const callbacks = { onSubmit: vi.fn(), onChange: vi.fn() };
  Object.assign(defaultEditor, callbacks);
  let current = defaultEditor;
  const tui = {};
  const editorTheme = {};
  const keybindings = {};
  const defaultBorder = (text: string) => `default:${text}`;
  const thinkingBorder = (text: string) => `thinking:${text}`;
  const ui = {
    theme: { getThinkingBorderColor: vi.fn(() => thinkingBorder) },
    notify: vi.fn(),
    getEditorText: () => current.getText(),
    setEditorComponent: vi.fn(function (this: unknown, factory: Factory | undefined) {
      expect(this).toBe(ui);
      // Model the host contract, not extension behavior: Pi copies text and
      // onSubmit/onChange, then overwrites borderColor AFTER invoking the factory.
      const text = current.getText();
      current = factory ? factory(tui, editorTheme, keybindings) : defaultEditor;
      current.setText(text);
      Object.assign(current, callbacks);
      current.borderColor = defaultBorder;
    }),
  };
  const originalSetEditorComponent = ui.setEditorComponent;
  return {
    ui,
    tui,
    callbacks,
    thinkingBorder,
    originalSetEditorComponent,
    get editor() {
      return current;
    },
    competitor: () => new mocks.ModalEditor(),
  };
}

function context(h: ReturnType<typeof host>, prompts = ["first", "second"]) {
  return {
    cwd: "/test/project",
    ui: h.ui,
    shutdown: vi.fn(),
    sessionManager: {
      getSessionFile: () => "/test/current.jsonl",
      getBranch: () =>
        prompts.map((text, i) => ({
          type: "message",
          message: {
            role: "user",
            timestamp: i + 100,
            content: [{ type: "text", text }],
          },
        })),
    },
  };
}

async function extension() {
  const handlers = new Map<string, Handler>();
  const focus = new Map<string, (event: unknown) => void>();
  const offFocus = vi.fn(() => focus.delete("my:focus_change"));
  const commands = [{ name: "initial-command" }];
  const api = {
    on: (event: string, handler: Handler) => {
      handlers.set(event, handler);
    },
    events: {
      on: (event: string, handler: (data: unknown) => void) => {
        focus.set(event, handler);
        return offFocus;
      },
      emit: vi.fn(),
    },
    getCommands: () => commands,
    getThinkingLevel: () => "medium",
  };
  await promptEditor(api as unknown as ExtensionAPI);
  return {
    commands,
    api,
    focus,
    offFocus,
    start(ctx: ReturnType<typeof context>) {
      return handlers.get("session_start")!({}, ctx as unknown as ExtensionContext);
    },
    shutdown() {
      return handlers.get("session_shutdown")!({}, {} as ExtensionContext);
    },
  };
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

function previousHistory() {
  const directory = deferred<unknown[]>();
  mocks.readdir.mockReturnValueOnce(directory.promise);
  const text =
    JSON.stringify({
      type: "message",
      message: {
        role: "user",
        timestamp: 1,
        content: [{ type: "text", text: "previous session" }],
      },
    }) + "\n";
  mocks.stat.mockResolvedValue({ size: Buffer.byteLength(text), mtimeMs: 1 });
  mocks.open.mockResolvedValue({
    read: async (buffer: Buffer) => ({ bytesRead: buffer.write(text) }),
    close: vi.fn(),
  });
  return () => directory.resolve([{ name: "previous.jsonl", isFile: () => true }]);
}

beforeEach(() => {
  vi.useFakeTimers();
  vi.clearAllMocks();
  vi.stubEnv("PI_CODING_AGENT_DIR", "/test/agent");
  mocks.readdir.mockReset().mockResolvedValue([]);
  mocks.stat.mockReset();
  mocks.open.mockReset();
  mocks.readSettings.mockReturnValue({ clipboardMirror: "never", exCommand: { enabled: true } });
});
afterEach(() => {
  vi.restoreAllMocks();
  vi.clearAllTimers();
  vi.useRealTimers();
  vi.unstubAllEnvs();
});

describe("prompt-editor installation lifecycle (host-contract integration)", () => {
  it("does not install an editor or schedule work until session_start", async () => {
    await extension();
    expect(mocks.construct).not.toHaveBeenCalled();
    expect(mocks.readdir).not.toHaveBeenCalled();
    expect(mocks.cursor.install).not.toHaveBeenCalled();
    expect(vi.getTimerCount()).toBe(0);
  });

  it("installs PromptEditor with session history and applies the border after the host swap", async () => {
    const e = await extension();
    const h = host("中文 draft\nsecond line");
    e.start(context(h));
    expect(h.editor.constructor.name).toBe("PromptEditor");
    expect(h.editor.getText()).toBe("中文 draft\nsecond line");
    expect(h.editor.history).toEqual(["second", "first"]);
    expect(h.editor.onSubmit).toBe(h.callbacks.onSubmit);
    expect(h.editor.onChange).toBe(h.callbacks.onChange);
    expect(h.editor.borderColor).toBe(h.thinkingBorder);
    expect(h.ui.theme.getThinkingBorderColor).toHaveBeenCalledWith("medium");
    expect(mocks.clipboard).toHaveBeenCalledWith(h.editor);
    expect(mocks.cursor.install).toHaveBeenCalledWith(h.tui, h.editor);
    expect(vi.getTimerCount()).toBe(0);
  });

  it("wins over a late editor install even after an earlier async handler yields to timers", async () => {
    const e = await extension();
    const h = host();
    e.start(context(h));
    await vi.runAllTimersAsync();
    h.ui.setEditorComponent(h.competitor);
    expect(h.editor.constructor.name).toBe("ModalEditor");
    expect(vi.getTimerCount()).toBe(1);
    await vi.runAllTimersAsync();
    expect(h.editor.constructor.name).toBe("PromptEditor");
    expect(h.originalSetEditorComponent).toHaveBeenCalledTimes(3);
    expect(vi.getTimerCount()).toBe(0);
  });

  it("coalesces later swaps, preserves the latest draft, and rehydrates history and callbacks", async () => {
    const e = await extension();
    const h = host();
    const ctx = context(h);
    e.start(ctx);
    const first = h.editor;
    h.ui.setEditorComponent(h.competitor);
    h.ui.setEditorComponent(h.competitor);
    h.editor.setText("edited after competing install");
    expect(vi.getTimerCount()).toBe(1);
    await vi.runAllTimersAsync();
    expect(h.editor).not.toBe(first);
    expect(h.editor.constructor.name).toBe("PromptEditor");
    expect(h.editor.getText()).toBe("edited after competing install");
    expect(h.editor.history).toEqual(["second", "first"]);
    expect(h.editor.onSubmit).toBe(h.callbacks.onSubmit);
    expect(h.editor.onChange).toBe(h.callbacks.onChange);
    expect(h.editor.setClipboardMirrorPolicy).toHaveBeenCalledWith("never");
    expect(h.editor.setExCommandSettings).toHaveBeenCalledWith({ enabled: true });
    h.editor.setQuitFn.mock.lastCall![0]();
    expect(ctx.shutdown).toHaveBeenCalledOnce();
    h.editor.setNotifyFn.mock.lastCall![0]("test warning");
    expect(h.ui.notify).toHaveBeenCalledWith("test warning", "warning");
    h.editor.setModeChangeFn.mock.lastCall![0]({ mode: "normal", previousMode: "insert" });
    expect(e.api.events.emit).toHaveBeenCalledWith("pi-vim:mode-change", {
      mode: "normal",
      previousMode: "insert",
    });
    expect(mocks.cursor.modeChanged).toHaveBeenCalledWith("normal");
    const names = h.editor.setCommandNamesFn.mock.lastCall![0];
    expect(names()).toContain("settings");
    expect(names()).toContain("initial-command");
    e.commands.push({ name: "registered-later" });
    expect(names()).toContain("registered-later");
    expect(vi.getTimerCount()).toBe(0);
  });

  it("preserves prompts added since startup across an editor reinstall", async () => {
    const e = await extension();
    const h = host();
    e.start(context(h));
    h.editor.addToHistory("submitted since startup");
    h.editor.historyIndex = 1;
    const previousHistory = h.editor.history;
    h.ui.setEditorComponent(h.competitor);
    await vi.runAllTimersAsync();
    expect(h.editor.history).toEqual(["submitted since startup", "second", "first"]);
    expect(h.editor.history).not.toBe(previousHistory);
    expect(h.editor.historyIndex).toBe(-1);
    h.editor.addToHistory("another prompt");
    expect(previousHistory).toEqual(["submitted since startup", "second", "first"]);
    h.ui.setEditorComponent(h.competitor);
    await vi.runAllTimersAsync();
    expect(h.editor.history).toEqual([
      "another prompt",
      "submitted since startup",
      "second",
      "first",
    ]);
  });

  it("preserves an explicitly emptied history instead of restoring the startup snapshot", async () => {
    const e = await extension();
    const h = host();
    e.start(context(h));
    h.editor.history = [];
    h.ui.setEditorComponent(h.competitor);
    await vi.runAllTimersAsync();
    expect(h.editor.history).toEqual([]);
  });

  it("reinstalls after a caller requests the default editor", async () => {
    const e = await extension();
    const h = host();
    e.start(context(h));
    h.ui.setEditorComponent(undefined);
    expect(h.editor.constructor.name).toBe("ModalEditor");
    await vi.runAllTimersAsync();
    expect(h.editor.constructor.name).toBe("PromptEditor");
    expect(h.editor.getText()).toBe("draft");
  });

  it.each([false, true])(
    "invalidates a queued old-session reinstall with sameUI=%s",
    async (sameUI) => {
      const e = await extension();
      const old = host();
      e.start(context(old, ["old session"]));
      old.ui.setEditorComponent(old.competitor);
      const next = sameUI ? old : host("new draft");
      e.start(context(next, ["new session"]));
      const active = next.editor;
      const installs = mocks.cursor.install.mock.calls.length;
      await vi.runAllTimersAsync();
      expect(next.editor).toBe(active);
      expect(next.editor.history).toEqual(["new session"]);
      expect(mocks.cursor.install).toHaveBeenCalledTimes(installs);
      expect(vi.getTimerCount()).toBe(0);
    },
  );

  it("ignores an old timer callback even if it was already dequeued before session replacement", async () => {
    const e = await extension();
    const h = host();
    e.start(context(h));
    const timer = vi.spyOn(globalThis, "setTimeout");
    h.ui.setEditorComponent(h.competitor);
    const staleCallback = timer.mock.lastCall![0] as () => void;
    e.start(context(h, ["new session"]));
    const active = h.editor;
    staleCallback();
    expect(h.editor).toBe(active);
    expect(h.editor.history).toEqual(["new session"]);
    timer.mockRestore();
  });

  it("updates late-loaded history without reinstalling or overwriting the draft", async () => {
    const complete = previousHistory();
    const e = await extension();
    const h = host();
    e.start(context(h));
    const active = h.editor;
    active.historyIndex = 2;
    complete();
    await vi.waitFor(() => expect(active.history).toEqual(["second", "first", "previous session"]));
    expect(h.editor).toBe(active);
    expect(active.historyIndex).toBe(-1);
    expect(active.getText()).toBe("draft");
    expect(h.originalSetEditorComponent).toHaveBeenCalledOnce();
  });

  it("preserves late-loaded history across a subsequent editor reinstall", async () => {
    const complete = previousHistory();
    const e = await extension();
    const h = host();
    e.start(context(h));
    complete();
    await vi.waitFor(() =>
      expect(h.editor.history).toEqual(["second", "first", "previous session"]),
    );
    h.ui.setEditorComponent(h.competitor);
    await vi.runAllTimersAsync();
    expect(h.editor.history).toEqual(["second", "first", "previous session"]);
  });

  it("retains history loaded after a reinstall when another reinstall follows", async () => {
    const complete = previousHistory();
    const e = await extension();
    const h = host();
    e.start(context(h));
    h.ui.setEditorComponent(h.competitor);
    await vi.runAllTimersAsync();
    complete();
    await vi.waitFor(() =>
      expect(h.editor.history).toEqual(["second", "first", "previous session"]),
    );
    h.ui.setEditorComponent(h.competitor);
    h.editor.setText("draft changed during replacement");
    await vi.runAllTimersAsync();
    expect(h.editor.history).toEqual(["second", "first", "previous session"]);
    expect(h.editor.getText()).toBe("draft changed during replacement");
  });

  it("discards late history when the user has edited the draft", async () => {
    const complete = previousHistory();
    const e = await extension();
    const h = host();
    e.start(context(h));
    h.editor.setText("user is typing");
    complete();
    await vi.runAllTimersAsync();
    expect(h.editor.getText()).toBe("user is typing");
    expect(h.editor.history).toEqual(["second", "first"]);
  });

  it("discards old-session history when a new session starts before IO finishes", async () => {
    const complete = previousHistory();
    const e = await extension();
    const old = host();
    e.start(context(old, ["old session"]));
    const next = host();
    e.start(context(next, ["new session"]));
    complete();
    await vi.runAllTimersAsync();
    expect(next.editor.history).toEqual(["new session"]);
    expect(old.editor.history).toEqual(["old session"]);
  });

  it("cancels pending work and restores an unwrapped, correctly bound setter on shutdown", async () => {
    const e = await extension();
    const h = host();
    e.start(context(h));
    const wrapped = h.ui.setEditorComponent;
    h.ui.setEditorComponent(h.competitor);
    expect(vi.getTimerCount()).toBe(1);
    e.shutdown();
    expect(vi.getTimerCount()).toBe(0);
    expect(h.ui.setEditorComponent).not.toBe(wrapped);
    h.ui.setEditorComponent(h.competitor);
    const active = h.editor;
    await vi.runAllTimersAsync();
    expect(h.editor).toBe(active);
    expect(vi.getTimerCount()).toBe(0);
    expect(e.offFocus).toHaveBeenCalledOnce();
    expect(e.focus.size).toBe(0);
    expect(mocks.cancelModeChangeCommands).toHaveBeenCalledOnce();
    expect(mocks.cursor.shutdown).toHaveBeenCalledOnce();
  });

  it("ignores an already-dequeued reinstall callback after shutdown", async () => {
    const e = await extension();
    const h = host();
    e.start(context(h));
    const timer = vi.spyOn(globalThis, "setTimeout");
    h.ui.setEditorComponent(h.competitor);
    const staleCallback = timer.mock.lastCall![0] as () => void;
    const active = h.editor;
    const installs = mocks.cursor.install.mock.calls.length;
    e.shutdown();
    staleCallback();
    expect(h.editor).toBe(active);
    expect(mocks.cursor.install).toHaveBeenCalledTimes(installs);
    expect(vi.getTimerCount()).toBe(0);
  });

  it("can shut down safely before any session has started", async () => {
    const e = await extension();
    expect(() => {
      e.shutdown();
      e.shutdown();
    }).not.toThrow();
    expect(vi.getTimerCount()).toBe(0);
    expect(mocks.cursor.install).not.toHaveBeenCalled();
  });
});
