import { CURSOR_MARKER, Editor, renderFakeCursor, type TUI } from "@earendil-works/pi-tui";
import { describe, expect, it } from "vitest";

import { renderPromptCursor } from "../extensions/prompt-editor/cursor.ts";

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
