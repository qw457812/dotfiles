import { readFileSync } from "node:fs";
import { join } from "node:path";
import { stripVTControlCharacters } from "node:util";

import type {
  ExtensionAPI,
  ExtensionContext,
  ExtensionUIContext,
} from "@earendil-works/pi-coding-agent";
import { CURSOR_MARKER, matchesKey, visibleWidth } from "@earendil-works/pi-tui";
import { afterEach, describe, expect, it, vi } from "vitest";

const config = vi.hoisted(() => ({
  settings: {
    clipboardMirror: "never",
    labelPosition: "top-left",
    cursorShape: { insert: "steady-bar", normal: "steady-block" },
  } as Record<string, unknown>,
}));

// Exercise the real entry point and real pinned pi-vim, without generating files
// in the source/deployed extension or reading the user's settings/history.
vi.mock("node:fs", async (original) => ({
  ...(await original<typeof import("node:fs")>()),
  writeFileSync: vi.fn(),
}));
vi.mock("../../extensions/prompt-editor/pi-vim.generated.ts", async (original) => ({
  ...(await original<typeof import("./fixtures/pi-vim.ts")>()),
  readPiVimSettings: () => config.settings,
}));

import promptEditor from "../../extensions/prompt-editor/index.ts";
import { ModalEditor } from "./fixtures/pi-vim.ts";

type Factory = NonNullable<Parameters<ExtensionUIContext["setEditorComponent"]>[0]>;
type Handler = (event: unknown, ctx: ExtensionContext) => unknown;
type Mode = ReturnType<ModalEditor["getMode"]>;
type Runtime = {
  state: { lines: string[]; cursorLine: number; cursorCol: number };
  lastWidth: number;
  displayLineWidth: number | null;
  pendingZ: boolean;
  history: string[];
  historyIndex: number;
  unnamedRegister: string;
  preferRegisterForPut: boolean;
  cursorShapeRuntime: unknown;
  tui: { setShowHardwareCursor: (enabled: boolean) => void };
  undo?: () => void;
  setMode: (mode: Mode) => void;
  buildVisualLineMap: (
    width: number,
  ) => Array<{ logicalLine: number; startCol: number; length: number }>;
};
const runtime = (editor: ModalEditor) => editor as unknown as Runtime;
const clean = (line: string) => stripVTControlCharacters(line.replace(/\x1b_pi:[^\x07]*\x07/g, ""));
const send = (editor: ModalEditor, ...keys: string[]) =>
  keys.forEach((key) => editor.handleInput(key));
const cleanups: Array<() => void> = [];

afterEach(() => {
  for (const cleanup of cleanups.splice(0)) cleanup();
  vi.restoreAllMocks();
});

async function host(hardware = true, labelPosition: "top-left" | "bottom-right" = "top-left") {
  config.settings.labelPosition = labelPosition;
  vi.spyOn(process.stdout, "write").mockImplementation(() => true);
  const handlers = new Map<string, Handler>();
  const focus = new Map<string, (data: unknown) => void>();
  const shutdown = vi.fn();
  let visible = hardware;
  const tui = {
    requestRender: vi.fn(),
    terminal: { rows: 24, columns: 80, cols: 80, write: vi.fn() },
    getShowHardwareCursor: () => visible,
    setShowHardwareCursor: vi.fn((value: boolean) => {
      visible = value;
    }),
  };
  const plain = (text: string) => text;
  const editorTheme = {
    borderColor: plain,
    selectList: {
      selectedPrefix: plain,
      selectedText: plain,
      description: plain,
      scrollInfo: plain,
      noMatch: plain,
    },
  };
  const bindings: Record<string, Array<Parameters<typeof matchesKey>[1]>> = {
    "tui.editor.cursorUp": ["up"],
    "tui.editor.cursorDown": ["down"],
    "tui.editor.cursorLeft": ["left", "ctrl+b"],
    "tui.editor.cursorRight": ["right", "ctrl+f"],
    "app.interrupt": ["escape", "ctrl+c"],
  };
  const kb = {
    getKeys: (action: string) => bindings[action] ?? [],
    matches: (data: string, action: string) =>
      (bindings[action] ?? []).some((key) => matchesKey(data, key)),
  };
  let current: ModalEditor;
  const notify = vi.fn();
  const onSubmit = vi.fn();
  const ctx = {
    cwd: "/nonexistent-prompt-editor-runtime-test",
    hasUI: true,
    sessionManager: { getSessionFile: () => undefined, getBranch: () => [] },
    shutdown,
    ui: {
      theme: {
        fg: (_token: string, text: string) => text,
        bg: (_token: string, text: string) => `\x1b[44m${text}\x1b[49m`,
        getThinkingBorderColor: () => plain,
      },
      notify,
      getEditorText: () => current?.getText() ?? "",
      setEditorComponent: (factory: Factory) => {
        const text = current?.getText() ?? "";
        current = factory(tui as never, editorTheme, kb as never) as ModalEditor;
        current.onSubmit = onSubmit;
        current.onChange = () => {};
        current.setText(text);
        current.focused = true;
      },
    },
  };
  await promptEditor({
    on: (name: string, handler: Handler) => handlers.set(name, handler),
    events: {
      on: (name: string, handler: (data: unknown) => void) => {
        focus.set(name, handler);
        return () => focus.delete(name);
      },
      emit: vi.fn(),
    },
    getCommands: () => [],
    getThinkingLevel: () => "medium",
    getSettings: () => ({ showHardwareCursor: hardware }),
  } as unknown as ExtensionAPI);
  handlers.get("session_start")!({}, ctx as unknown as ExtensionContext);
  cleanups.push(() => handlers.get("session_shutdown")!({}, ctx as unknown as ExtensionContext));
  const editor = current!;
  editor.setClipboardFn(() => {});
  editor.setClipboardReadFn(() => null);
  return {
    editor,
    tui,
    shutdown,
    notify,
    onSubmit,
    focus,
    theme: ctx.ui.theme,
    setVisible(value: boolean) {
      visible = value;
    },
    set(text = "abcdefghijklmno", mode: Mode = "normal", col = 0, line = 0, width = 14) {
      editor.setText(text);
      runtime(editor).setMode(mode);
      Object.assign(runtime(editor).state, { cursorCol: col, cursorLine: line });
      return editor.render(width);
    },
  };
}

describe("prompt-editor with real pi-vim 0.15.1 and Pi components", () => {
  it("runs on the reviewed target", () => {
    const root = join(import.meta.dirname, "../../node_modules/pi-vim/package.json");
    expect(JSON.parse(readFileSync(root, "utf8")).version).toBe("0.15.1");
  });

  it.each(["j", "\x1b[B"])(
    "delegates %j to upstream gj at the prefix-reduced width",
    async (key) => {
      const h = await host();
      h.set();
      const r = runtime(h.editor);
      expect(r.displayLineWidth).toBe(r.lastWidth);
      const rows = r.buildVisualLineMap(r.lastWidth);
      send(h.editor, key);
      expect(h.editor.getCursor()).toEqual({ line: 0, col: rows[1]!.startCol });
      send(h.editor, "k");
      expect(h.editor.getCursor()).toEqual({ line: 0, col: 0 });
      expect(h.editor.getText()).toBe("abcdefghijklmno");
    },
  );

  it.each(["gj", "J"])("joins the next logical line with %s", async (command) => {
    const h = await host();
    h.set("first\n  second\nthird");
    send(h.editor, ...command);
    expect(h.editor.getText()).toBe("first second\nthird");
    expect(h.editor.getMode()).toBe("normal");
    expect(h.editor.getCursor()).toEqual({ line: 0, col: 5 });
  });

  it("keeps gj joins repeatable and gives each join one undo unit", async () => {
    const h = await host();
    const original = "one\n two\nthree\nfour";
    h.set(original);
    send(h.editor, "g", "j");
    expect(h.editor.getText()).toBe("one two\nthree\nfour");
    send(h.editor, ".");
    expect(h.editor.getText()).toBe("one two three\nfour");
    send(h.editor, "u");
    expect(h.editor.getText()).toBe("one two\nthree\nfour");
    send(h.editor, "u");
    expect(h.editor.getText()).toBe(original);
    send(h.editor, "\x12");
    expect(h.editor.getText()).toBe("one two\nthree\nfour");
  });

  it("preserves prefix counts for gj and a count override on dot", async () => {
    const h = await host();
    h.set("one\ntwo\nthree\nfour\nfive\nsix");
    send(h.editor, "3", "g", "j");
    expect(h.editor.getText()).toBe("one two three\nfour\nfive\nsix");
    send(h.editor, "2", ".");
    expect(h.editor.getText()).toBe("one two three four\nfive\nsix");
  });

  it("keeps EOF gj a no-op without replacing the last repeatable change", async () => {
    const h = await host();
    h.set("abc\ndef");
    send(h.editor, "r", "X", "G", "g", "j");
    expect(h.editor.getText()).toBe("Xbc\ndef");
    send(h.editor, ".");
    expect(h.editor.getText()).toBe("Xbc\nXef");
  });

  it.each(["visual", "visual-line"] as const)(
    "keeps explicit gj as a display motion in %s",
    async (mode) => {
      const h = await host();
      h.set("abcdefghijklmnopqrstuvwxyz".repeat(3), mode);
      const r = runtime(h.editor);
      const rows = r.buildVisualLineMap(r.lastWidth);
      send(h.editor, "g", "j");
      expect(h.editor.getCursor()).toEqual({ line: 0, col: rows[1]!.startCol });
      expect(h.editor.getMode()).toBe(mode);
      expect(h.editor.getText()).toBe("abcdefghijklmnopqrstuvwxyz".repeat(3));
    },
  );

  it.each(["dgj", "cgj", "ygj", "gJ", "gk", "g2j"])(
    "retains upstream semantics for %s",
    async (command) => {
      const h = await host();
      const baseline = await host();
      const text = "abcdefghijklmnopqrstuvwxyz".repeat(4) + "\nnext";
      h.set(text);
      baseline.set(text);
      send(h.editor, ...command);
      for (const key of command) ModalEditor.prototype.handleInput.call(baseline.editor, key);
      expect(h.editor.getText()).toBe(baseline.editor.getText());
      expect(h.editor.getMode()).toBe(baseline.editor.getMode());
      expect(h.editor.getCursor()).toEqual(baseline.editor.getCursor());
      expect(runtime(h.editor).unnamedRegister).toBe(runtime(baseline.editor).unnamedRegister);
    },
  );

  it("keeps gj literal in Ex and Insert, and ignores it in bracketed paste", async () => {
    const h = await host();
    h.set("one\ntwo");
    send(h.editor, ":", "g", "j");
    expect(h.editor.getText()).toBe("one\ntwo");
    expect(h.editor.render(40).map(clean)[0]).toContain("EX :gj_");
    h.set("one\ntwo", "insert");
    send(h.editor, "g", "j");
    expect(h.editor.getText()).toBe("gjone\ntwo");
    h.set("one\ntwo");
    send(h.editor, "g", "\x1b[200~", "j", "\x1b[201~");
    expect(h.editor.getText()).toBe("one\ntwo");
    expect(h.editor.getMode()).toBe("normal");
  });

  it.each(["h", "l", "H", "L"])(
    "resets upstream's wanted display column after local %s",
    async (key) => {
      const h = await host();
      h.set("abcdefghijklmnopqrstuvwxyz".repeat(5), "normal", 4);
      send(h.editor, "j", key);
      const r = runtime(h.editor);
      const rows = r.buildVisualLineMap(r.lastWidth);
      const column = h.editor.getCursor().col - rows[1]!.startCol;
      send(h.editor, "j");
      expect(h.editor.getCursor()).toEqual({ line: 0, col: rows[2]!.startCol + column });
    },
  );

  it.each(["normal", "visual", "visual-line"] as const)(
    "keeps j/k buffer-local at display edges in %s",
    async (mode) => {
      const h = await host();
      h.set("abc", mode);
      runtime(h.editor).history = ["older prompt"];
      send(h.editor, "k", "j");
      expect(h.editor.getText()).toBe("abc");
      expect(runtime(h.editor).historyIndex).toBe(-1);
    },
  );

  it.each(["h", "l", "j", "k", "H", "L"])(
    "lets pending Z consume %s, preventing an accidental quit",
    async (key) => {
      const h = await host();
      h.set("abcdef");
      send(h.editor, "Z", key, "Q");
      expect(h.shutdown).not.toHaveBeenCalled();
      expect(runtime(h.editor).pendingZ).toBe(false);
      expect(h.editor.getCursor()).toEqual({ line: 0, col: 0 });
    },
  );

  it.each(["j", "k", "H", "L"])("keeps replacement argument r%s literal", async (key) => {
    const h = await host();
    h.set("abcdef");
    send(h.editor, "r", key);
    expect(h.editor.getText()).toBe(`${key}bcdef`);
  });

  it("preserves cl, Y and U customizations", async () => {
    const h = await host();
    h.set("abcdef");
    send(h.editor, "c", "l", "X", "\x1b");
    expect(h.editor.getText()).toBe("Xbcdef");
    send(h.editor, "u");
    expect(h.editor.getText()).toBe("abcdef");
    send(h.editor, "U");
    expect(h.editor.getText()).toBe("Xbcdef");
    send(h.editor, "Y");
    expect(runtime(h.editor).unnamedRegister).toBe("Xbcdef");
  });

  it("isolates split bracketed paste from every local remap", async () => {
    const h = await host();
    h.set("abcdef");
    send(h.editor, "\x1b[200~", "j", "H", "Y", "\x1b[201~");
    expect(h.editor.getText()).toBe("abcdef");
    expect(h.editor.getCursor()).toEqual({ line: 0, col: 0 });
  });

  it("keeps Ex text and Ex history in upstream's state machine", async () => {
    const h = await host();
    h.set("draft");
    send(h.editor, ":", ..."unknown", "\r", ":", "\x10");
    expect(h.editor.render(40).map(clean)[0]).toContain("EX :unknown_");
    expect(h.editor.getText()).toBe("draft");
    expect(h.onSubmit).not.toHaveBeenCalled();
  });

  it("uses upstream selection paint while preserving the prefix and top-left label", async () => {
    const h = await host();
    h.set("abcdef");
    send(h.editor, "v", "l");
    const lines = h.editor.render(40);
    expect(clean(lines[0]!)).toMatch(/^ VISUAL /);
    expect(lines[1]).toContain("\x1b[44m");
    expect(clean(lines[1]!)).toMatch(/^❮ abcdef/);
    expect(lines[1]).toContain(CURSOR_MARKER);
    expect(lines[1]).not.toContain("\x1b_pi:fc\x07");
    expect(lines.map(clean).at(-1)).not.toContain("VISUAL");
  });

  it("falls back to reverse-video selection when a theme has no selected background", async () => {
    const h = await host();
    h.set("abcdef");
    send(h.editor, "v", "l");
    h.theme.bg = (_token, text) => `\x1b[49m${text}\x1b[49m`;
    const lines = h.editor.render(40);
    expect(lines[1]).toContain("\x1b[7ma\x1b[27m");
    expect(lines[1]).not.toContain("\x1b[44m");
  });

  it.each([1, 2, 3, 8, 20, 80])(
    "keeps upstream labels, cursor markers and lines bounded at width %i",
    async (width) => {
      const h = await host();
      const lines = h.set(width < 4 ? "ab" : "中文👩‍💻e\u0301 wrapped text", "normal", 0, 0, width);
      for (const line of lines) expect(visibleWidth(line)).toBeLessThanOrEqual(width);
      expect(lines.join("\n")).toContain(CURSOR_MARKER);
      h.editor.render(40);
      expect(runtime(h.editor).displayLineWidth).toBe(runtime(h.editor).lastWidth);
    },
  );

  it("preserves the accepted trailing border after a bottom-right label", async () => {
    const h = await host(true, "bottom-right");
    const lines = h.set("draft", "normal", 0, 0, 40).map(clean);
    expect(lines[0]).not.toContain("NORMAL");
    expect(lines.at(-1)).toMatch(/ NORMAL ──$/);
    expect(lines[1]).toMatch(/^❮ draft/);
  });

  it("retains upstream's bottom-right label on the last autocomplete row", async () => {
    const h = await host(true, "bottom-right");
    h.set("/mo", "insert", 3, 0, 40);
    h.editor.setAutocompleteProvider({
      getSuggestions: async () => ({
        prefix: "/mo",
        items: [{ value: "/model", label: "model" }],
      }),
      applyCompletion: (lines, line, col) => ({ lines, cursorLine: line, cursorCol: col }),
    });
    send(h.editor, "d");
    await vi.waitFor(() => {
      const lines = h.editor.render(40).map(clean);
      expect(lines.at(-1)).toContain("model");
      expect(lines.at(-1)).toContain("INSERT");
    });
    const lines = h.editor.render(40).map(clean);
    expect(lines.at(-2)).toMatch(/^─+$/);
    expect(lines.at(-2)).not.toContain("INSERT");
    expect(h.editor.getText()).toBe("/mod");
    expect(h.onSubmit).not.toHaveBeenCalled();
  });

  it("keeps autocomplete outside the prefix, selection and mode label", async () => {
    const h = await host();
    h.set("/mo", "insert", 3, 0, 40);
    h.editor.setAutocompleteProvider({
      getSuggestions: async () => ({ prefix: "/mo", items: [{ value: "/model", label: "model" }] }),
      applyCompletion: (lines, line, col) => ({ lines, cursorLine: line, cursorCol: col }),
    });
    send(h.editor, "d");
    await new Promise((resolve) => setTimeout(resolve, 100));
    const lines = h.editor.render(40).map(clean);
    expect(lines[0]).toMatch(/^ INSERT /);
    const suggestion = lines.find((line) => line.includes("model"));
    expect(suggestion).toBeDefined();
    expect(suggestion).not.toMatch(/^❮|^❯/);
    expect(suggestion).not.toContain("INSERT");
  });

  it.each([
    ["/mo", 0, ""],
    ["keep\n/mo", 1, "keep\n"],
  ] as const)(
    "dismisses autocomplete when cc clears %j at logical line %i",
    async (text, line, expected) => {
      const h = await host();
      h.set(text, "insert", 3, line, 40);
      h.editor.setAutocompleteProvider({
        getSuggestions: async () => ({
          prefix: "/mo",
          items: [
            { value: "/model", label: "model" },
            { value: "/models", label: "models" },
          ],
        }),
        applyCompletion: (lines, line, col) => ({ lines, cursorLine: line, cursorCol: col }),
      });
      send(h.editor, "d");
      if (line > 0) send(h.editor, "\t");
      await vi.waitFor(() => expect(h.editor.render(40).map(clean).join("\n")).toContain("model"));
      send(h.editor, "\x1b", "c");
      expect(h.editor.render(40).map(clean).join("\n")).toContain("model");
      send(h.editor, "c");
      expect(h.editor.getText()).toBe(expected);
      expect(h.editor.getMode()).toBe("insert");
      expect(h.editor.render(40).map(clean).join("\n")).not.toContain("model");
      expect(h.onSubmit).not.toHaveBeenCalled();
      send(h.editor, "\x1b", "u");
      expect(h.editor.getText()).toBe(`${text}d`);
    },
  );

  it("cancels in-flight suggestions so cc cannot reopen stale autocomplete", async () => {
    const h = await host();
    h.set("/mo", "insert", 3, 0, 40);
    let complete!: (value: {
      prefix: string;
      items: Array<{ value: string; label: string }>;
    }) => void;
    const suggestions = new Promise<{
      prefix: string;
      items: Array<{ value: string; label: string }>;
    }>((resolve) => {
      complete = resolve;
    });
    let signal: AbortSignal | undefined;
    const getSuggestions = vi.fn(
      (_lines: string[], _line: number, _col: number, options?: { signal?: AbortSignal }) => {
        signal = options?.signal;
        return suggestions;
      },
    );
    h.editor.setAutocompleteProvider({
      getSuggestions,
      applyCompletion: (lines, line, col) => ({ lines, cursorLine: line, cursorCol: col }),
    });
    send(h.editor, "d");
    await vi.waitFor(() => expect(getSuggestions).toHaveBeenCalledOnce());
    send(h.editor, "\x1b", "c", "c");
    expect(signal?.aborted).toBe(true);
    complete({ prefix: "/mo", items: [{ value: "/model", label: "model" }] });
    await suggestions;
    await new Promise((resolve) => setTimeout(resolve, 100));
    expect(h.editor.getText()).toBe("");
    expect(h.editor.getMode()).toBe("insert");
    expect(h.editor.render(40).map(clean).join("\n")).not.toContain("model");
  });

  it.each(["p", "P"])(
    "leaves the selection untouched when the effective %s payload is empty",
    async (key) => {
      const h = await host();
      h.set("abcdef");
      runtime(h.editor).unnamedRegister = "\x1b\x00\x7f\x9b";
      runtime(h.editor).preferRegisterForPut = true;
      send(h.editor, "v", key);
      expect(h.editor.getText()).toBe("abcdef");
      expect(h.editor.getMode()).toBe("visual");
      expect(runtime(h.editor).unnamedRegister).toBe("\x1b\x00\x7f\x9b");
    },
  );

  it.each(["p", "P"])(
    "reuses upstream normalization for Visual %s without changing its register policy",
    async (key) => {
      const h = await host();
      h.set("abcdef");
      const raw = "X\tY\r\nZ\x00";
      runtime(h.editor).unnamedRegister = raw;
      runtime(h.editor).preferRegisterForPut = true;
      send(h.editor, "v", key);
      expect(h.editor.getText()).toBe("X    Y\nZbcdef");
      expect(runtime(h.editor).unnamedRegister).toBe(key === "P" ? raw : "a");
      send(h.editor, "u");
      expect(h.editor.getText()).toBe("abcdef");
    },
  );

  it.each(["p", "P"])("keeps a linewise Visual %s replacement in one undo unit", async (key) => {
    const h = await host();
    h.set("first\nsecond\nlast", "normal", 0, 2);
    runtime(h.editor).unnamedRegister = "replacement\n";
    runtime(h.editor).preferRegisterForPut = true;
    send(h.editor, "V", key);
    expect(h.editor.getText()).toBe("first\nsecond\nreplacement");
    send(h.editor, "u");
    expect(h.editor.getText()).toBe("first\nsecond\nlast");
  });

  it.each([true, false])(
    "preserves hardware=%s and hides the cursor on blur without erasing selection paint",
    async (hardware) => {
      const h = await host(hardware);
      h.set("abcdef");
      send(h.editor, "v", "l");
      h.focus.get("my:focus_change")!({ focused: false });
      const blurred = h.editor.render(40);
      expect(h.tui.getShowHardwareCursor()).toBe(false);
      expect(blurred[1]).not.toContain("\x1b_pi:fc\x07");
      expect(blurred[1]).toContain("\x1b[44m");
      h.focus.get("my:focus_change")!({ focused: true });
      const focused = h.editor.render(40);
      expect(h.tui.getShowHardwareCursor()).toBe(hardware);
      expect(focused[1]!.includes("\x1b_pi:fc\x07")).toBe(!hardware);
    },
  );

  it("restores the software-cursor preference when the real installation fails preflight", async () => {
    const preflight = ModalEditor.prototype.preflightHost;
    let forced = false;
    vi.spyOn(ModalEditor.prototype, "preflightHost").mockImplementation(
      function (this: ModalEditor) {
        if (!forced) {
          // Reproduce an upstream factory's cursor side effect on an incompatible host.
          runtime(this).tui.setShowHardwareCursor(true);
          runtime(this).undo = undefined;
          forced = true;
        }
        return preflight.call(this);
      },
    );
    const h = await host(false);
    expect(h.tui.setShowHardwareCursor.mock.calls).toEqual([[true], [false]]);
    expect(h.tui.getShowHardwareCursor()).toBe(false);
    send(h.editor, ..."plain text");
    expect(h.editor.getText()).toBe("plain text");
    const lines = h.editor.render(40).map(clean).join("\n");
    expect(lines).not.toContain("❯");
    expect(lines).not.toContain("INSERT");
    expect(h.tui.getShowHardwareCursor()).toBe(false);
    expect(h.tui.terminal.write).not.toHaveBeenCalled();
    expect(h.notify).toHaveBeenCalledOnce();
    h.focus.get("my:focus_change")!({ focused: true });
    expect(h.tui.getShowHardwareCursor()).toBe(false);
  });

  it("uses stock input/rendering before local remaps when preflight fails", async () => {
    const h = await host();
    // Preflight is normally cached during installation. Recreate an unchecked
    // instance from the real local constructor, then remove one host operation.
    const Local = h.editor.constructor as typeof ModalEditor;
    const plain = (text: string) => text;
    const args = [
      h.tui,
      { borderColor: plain },
      { getKeys: () => [], matches: () => false },
      null,
      null,
      null,
      null,
      null,
      plain,
      {},
      "top-left",
      plain,
    ];
    const editor = Reflect.construct(Local, args) as ModalEditor;
    runtime(editor).undo = undefined;
    editor.setText("abc");
    editor.setNotifyFn(h.notify);
    editor.handleInput("h");
    expect(editor.getText()).toBe("abch");
    const lines = editor.render(40).map(clean);
    expect(lines.join("\n")).not.toContain("❯");
    expect(lines.join("\n")).not.toContain("INSERT");
    expect(h.notify).toHaveBeenCalledOnce();
  });
});
