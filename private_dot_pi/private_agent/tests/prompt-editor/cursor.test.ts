import { CURSOR_MARKER, Editor, renderFakeCursor, type TUI } from "@earendil-works/pi-tui";
import { describe, expect, it, vi } from "vitest";

import {
  createCursorController,
  renderPromptCursor,
} from "../../extensions/prompt-editor/cursor.ts";

describe("prompt-editor cursor controller", () => {
  function setup(initial = true) {
    let enabled = initial;
    let mode = "insert";
    const tui = {
      getShowHardwareCursor: vi.fn(() => enabled),
      setShowHardwareCursor: vi.fn((value: boolean) => {
        enabled = value;
      }),
      requestRender: vi.fn(),
      terminal: { write: vi.fn() },
    };
    const editor = { getMode: () => mode };
    const writeReset = vi.fn();
    const controller = createCursorController(writeReset);
    return {
      tui,
      editor,
      controller,
      writeReset,
      setPreference(value: boolean) {
        enabled = value;
      },
      setMode(value: string) {
        mode = value;
      },
    };
  }

  it.each(["insert", "normal", "visual", "visual-line"])("installs the shape for %s", (mode) => {
    const { tui, editor, controller, setMode } = setup();
    setMode(mode);
    controller.install(tui, editor);
    expect(tui.setShowHardwareCursor).not.toHaveBeenCalled();
    expect(tui.terminal.write).toHaveBeenCalledWith(mode === "insert" ? "\x1b[6 q" : "\x1b[2 q");
  });

  it("hides on blur without mistaking forced visibility for a setting change", () => {
    const { tui, editor, controller, setMode } = setup();
    controller.install(tui, editor);
    controller.setFocused(false);
    controller.syncPreference("insert");
    controller.modeChanged("normal");
    expect(tui.terminal.write.mock.calls).toEqual([["\x1b[6 q"], ["\x1b[0 q"]]);
    setMode("normal");
    controller.setFocused(true);
    expect(tui.setShowHardwareCursor.mock.calls).toEqual([[false], [true]]);
    expect(tui.terminal.write).toHaveBeenLastCalledWith("\x1b[2 q");
    expect(tui.requestRender).not.toHaveBeenCalled();
    const lines = ["──", renderFakeCursor("x"), "──"];
    controller.render(lines, 2);
    expect(lines[1]).toBe(`${CURSOR_MARKER}x`);
  });

  it("keeps software mode free of shape changes and rerenders on focus changes", () => {
    const { tui, editor, controller } = setup(false);
    controller.install(tui, editor);
    const body = `${CURSOR_MARKER}${renderFakeCursor("x")}`;
    const focused = ["──", body, "──"];
    controller.render(focused, 2);
    expect(focused[1]).toBe(body);
    controller.setFocused(false);
    const blurred = ["──", body, "──"];
    controller.render(blurred, 2);
    expect(blurred[1]).toBe(`${CURSOR_MARKER}x`);
    controller.modeChanged("normal");
    controller.setFocused(true);
    const restored = ["──", body, "──"];
    controller.render(restored, 2);
    expect(restored[1]).toBe(body);
    expect(tui.requestRender).toHaveBeenCalledTimes(2);
    expect(tui.setShowHardwareCursor).not.toHaveBeenCalled();
    expect(tui.terminal.write).not.toHaveBeenCalled();
  });

  it("syncs live settings without setting visibility or requesting another render", () => {
    const { tui, editor, controller, setPreference } = setup();
    controller.install(tui, editor);
    setPreference(false);
    controller.syncPreference("normal");
    controller.modeChanged("insert");
    controller.syncPreference("normal");
    setPreference(true);
    controller.syncPreference("normal");
    controller.modeChanged("insert");
    expect(tui.terminal.write.mock.calls).toEqual([
      ["\x1b[6 q"],
      ["\x1b[0 q"],
      ["\x1b[2 q"],
      ["\x1b[6 q"],
    ]);
    expect(tui.setShowHardwareCursor).not.toHaveBeenCalled();
    expect(tui.requestRender).not.toHaveBeenCalled();
  });

  it("remembers focus before installation", () => {
    const { tui, editor, controller } = setup();
    controller.setFocused(false);
    controller.install(tui, editor);
    expect(tui.setShowHardwareCursor).toHaveBeenCalledWith(false);
    expect(tui.terminal.write).toHaveBeenCalledWith("\x1b[0 q");
  });

  it("retains the stable Proxy setter across editor reinstallation", () => {
    const { tui, editor, controller } = setup();
    controller.install(tui, editor);
    const original = tui.setShowHardwareCursor;
    tui.setShowHardwareCursor = vi.fn();
    controller.install(tui, editor);
    controller.setFocused(false);
    expect(original).toHaveBeenCalledWith(false);
    expect(tui.setShowHardwareCursor).not.toHaveBeenCalled();
  });

  it("defaults to hardware mode when the getter is unavailable", () => {
    const { tui, editor, controller } = setup();
    controller.install({ ...tui, getShowHardwareCursor: undefined }, editor);
    controller.syncPreference("normal");
    expect(tui.setShowHardwareCursor).toHaveBeenCalledWith(true);
    expect(tui.terminal.write.mock.calls).toEqual([["\x1b[6 q"]]);
  });

  it("resets on shutdown, releases old references, and starts clean on reuse", () => {
    const first = setup();
    const { controller, writeReset } = first;
    controller.install(first.tui, first.editor);
    controller.setFocused(false);
    controller.shutdown();
    controller.modeChanged("normal");
    controller.syncPreference("normal");
    expect(writeReset).toHaveBeenCalledWith("\x1b[0 q");
    expect(first.tui.terminal.write).toHaveBeenCalledTimes(2);
    const next = setup();
    controller.install(next.tui, next.editor);
    controller.setFocused(false);
    expect(next.tui.setShowHardwareCursor).toHaveBeenCalledWith(false);
    expect(first.tui.setShowHardwareCursor).toHaveBeenCalledTimes(1);
    controller.shutdown();
    controller.shutdown();
    expect(writeReset).toHaveBeenCalledTimes(3);
  });
});

const inverse = (text: string) => `\x1b[7m${text}\x1b[27m`;

function renderBody(body: string, hardware: boolean, blurred: boolean): string {
  const lines = ["──", body, inverse(" NORMAL ")];
  renderPromptCursor(lines, 2, { hardware, blurred });
  expect(lines[0]).toBe("──");
  expect(lines[2]).toBe(inverse(" NORMAL "));
  return lines[1]!;
}

describe("prompt-editor APC cursor ownership (Pi 1.2)", () => {
  it.each([" ", "中", "👩‍💻", "e\u0301"])("preserves cursor grapheme %j", (cell) => {
    const line = `before${CURSOR_MARKER}${renderFakeCursor(cell)}after`;
    expect(renderBody(line, true, false)).toBe(`before${CURSOR_MARKER}${cell}after`);
  });

  it.each([false, true])("hides the cursor on blur with hardware=%s", (hardware) => {
    const line = `before${CURSOR_MARKER}${renderFakeCursor("中")}after`;
    expect(renderBody(line, hardware, true)).toBe(`before${CURSOR_MARKER}中after`);
  });

  it("leaves the software cursor to the TUI when focused", () => {
    const line = `${CURSOR_MARKER}${renderFakeCursor("x")}`;
    expect(renderBody(line, false, false)).toBe(line);
    expect(renderBody(line, false, true)).toBe(`${CURSOR_MARKER}x`);
    expect(renderBody(line, false, false)).toBe(line);
  });

  it("restores a missing hardware marker at the APC cursor, not a selection", () => {
    const line = `${inverse("selected")} ${renderFakeCursor("中")}${inverse("tail")}`;
    expect(renderBody(line, true, false)).toBe(
      `${inverse("selected")} ${CURSOR_MARKER}中${inverse("tail")}`,
    );
  });

  it("hides an unfocused component's software cursor without adding a hardware marker", () => {
    expect(renderBody(`before${renderFakeCursor("x")}after`, false, true)).toBe("beforexafter");
  });

  it("preserves SGR styling within and around the cursor", () => {
    const cell = `\x1b[31m${inverse("中")}\x1b[0m`;
    const selection = inverse("selected");
    const line = `${selection}${CURSOR_MARKER}${renderFakeCursor(cell)}${selection}`;
    expect(renderBody(line, true, false)).toBe(`${selection}${CURSOR_MARKER}${cell}${selection}`);
  });

  it("handles a cursor whose closing APC marker was clipped at the line edge", () => {
    const clipped = renderFakeCursor("x").replace(/\x1b_pi:\/fc\x07$/, "");
    expect(renderBody(`${CURSOR_MARKER}${clipped}`, false, true)).toBe(`${CURSOR_MARKER}x`);
  });

  it("does not treat ordinary reverse video as a cursor", () => {
    const line = `${CURSOR_MARKER}${inverse("selected")}`;
    expect(renderBody(line, true, false)).toBe(line);
    expect(renderBody(inverse("selected"), true, false)).toBe(inverse("selected"));
  });

  it("does not touch borders, mode labels, or autocomplete rows", () => {
    const lines = [
      renderFakeCursor("top"),
      "first line",
      `  ${CURSOR_MARKER}${renderFakeCursor("中")}`,
      inverse(" V-LINE "),
      renderFakeCursor("autocomplete"),
    ];
    const expected = [...lines];
    expected[2] = `  ${CURSOR_MARKER}中`;
    renderPromptCursor(lines, 3, { hardware: true, blurred: true });
    expect(lines).toEqual(expected);
  });

  it("does not duplicate an existing body cursor marker", () => {
    const lines = ["──", `${CURSOR_MARKER}first`, renderFakeCursor("x"), "──"];
    renderPromptCursor(lines, 3, { hardware: true, blurred: false });
    expect(lines).toEqual(["──", `${CURSOR_MARKER}first`, "x", "──"]);
  });

  it("tolerates an empty body", () => {
    const lines = ["──"];
    renderPromptCursor(lines, 0, { hardware: true, blurred: true });
    expect(lines).toEqual(["──"]);
  });

  it.each([2, 3, 12, 80])("handles actual Editor output at width %i", (width) => {
    const plain = (text: string) => text;
    const tui = { terminal: { rows: 24, columns: width }, requestRender() {} } as unknown as TUI;
    const editor = new Editor(tui, {
      borderColor: plain,
      selectList: {
        selectedPrefix: plain,
        selectedText: plain,
        description: plain,
        scrollInfo: plain,
        noMatch: plain,
      },
    });
    editor.focused = true;
    // Editor reserves one column for the cursor; width 2 only fits narrow glyphs.
    editor.setText(width === 2 ? "a\nb" : "中文👩‍💻e\u0301\nwrapped line");
    const lines = editor.render(width);
    const before = [...lines];
    expect(lines.some((line) => line.includes(renderFakeCursor(" ")))).toBe(true);
    renderPromptCursor(lines, lines.length - 1, { hardware: false, blurred: true });
    expect(lines.join("\n")).not.toContain("\x1b_pi:fc\x07");
    expect(lines.join("\n")).not.toContain("\x1b_pi:/fc\x07");
    expect(lines.join("\n")).toContain(CURSOR_MARKER);
    // Rendering is derived from state: refocusing must restore the original cursor.
    expect(editor.render(width)).toEqual(before);
  });
});
