import { Editor, type TUI } from "@earendil-works/pi-tui";
import { describe, expect, it, vi } from "vitest";

import {
  handleNormalHorizontalMotion,
  handleVisualLineRemap,
} from "../extensions/prompt-editor/navigation.ts";

function fixture(lines = ["abc", "def"]) {
  const state = { lines, cursorLine: 0, cursorCol: 0 };
  return {
    state,
    getMode: vi.fn(() => "normal"),
    pendingOperator: null as string | null,
    pendingG: false,
    pendingMotion: null as string | null,
    pendingReplace: false,
    pendingTextObject: null as string | null,
    discardingBracketedPasteInNormalMode: false,
    prefixCount: "",
    operatorCount: "",
    lastWidth: 10,
    lastAction: "typing" as string | null,
    preferredVisualCol: 4 as number | null,
    snappedFromCursorCol: 2 as number | null,
    segment: vi.fn((text: string, _granularity: "grapheme") =>
      new Intl.Segmenter(undefined, { granularity: "grapheme" }).segment(text),
    ),
    setCursorCol: vi.fn((col: number) => {
      state.cursorCol = col;
    }),
    takeTotalCount: vi.fn(() => 1),
    updateAutocomplete: vi.fn(),
    refreshPendingDispatchRestore: vi.fn(),
    buildVisualLineMap: vi.fn((_width: number) =>
      lines.map((line, logicalLine) => ({ logicalLine, startCol: 0, length: line.length })),
    ),
    findCurrentVisualLine: vi.fn((_lines: unknown[]) => 0),
    moveToVisualLine: vi.fn((_lines: unknown[], _current: number, _target: number) => {}),
  };
}

const pendingStates = [
  { pendingOperator: "d" },
  { pendingG: true },
  { pendingMotion: "f" },
  { pendingReplace: true },
  { pendingTextObject: "i" },
];

describe("prompt-editor logical-line horizontal motions", () => {
  it.each(["j", "k", "H", "L", "x", "\x1b[200~"])("delegates %j", (key) => {
    expect(handleNormalHorizontalMotion({}, key)).toBe(false);
  });

  it.each([...pendingStates, { discardingBracketedPasteInNormalMode: true }])(
    "delegates pending input without consuming counts: %j",
    (pending) => {
      const editor = fixture();
      Object.assign(editor, pending);
      expect(handleNormalHorizontalMotion(editor, "h")).toBe(false);
      expect(handleNormalHorizontalMotion(editor, "l")).toBe(false);
      expect(editor.takeTotalCount).not.toHaveBeenCalled();
      expect(editor.refreshPendingDispatchRestore).not.toHaveBeenCalled();
    },
  );

  it.each([
    [0, 0, "h", 0],
    [0, 2, "l", 2],
    [1, 0, "h", 0],
    [1, 2, "l", 2],
    [1, 3, "l", 3],
    [1, 3, "h", 2],
  ] as const)("keeps line %i, col %i, key %s on its logical line", (line, col, key, target) => {
    const editor = fixture();
    Object.assign(editor.state, { cursorLine: line, cursorCol: col });
    expect(handleNormalHorizontalMotion(editor, key)).toBe(true);
    expect(editor.state).toMatchObject({ cursorLine: line, cursorCol: target });
  });

  it.each(["h", "l"])("consumes %s on an empty line", (key) => {
    const editor = fixture([""]);
    expect(handleNormalHorizontalMotion(editor, key)).toBe(true);
    expect(editor.state.cursorCol).toBe(0);
    expect(editor.refreshPendingDispatchRestore).toHaveBeenCalledOnce();
  });

  it("uses the total count and clamps at grapheme boundaries", () => {
    const editor = fixture(["a👩‍💻e\u0301中z"]);
    editor.prefixCount = "3";
    editor.takeTotalCount.mockReturnValue(3);
    expect(handleNormalHorizontalMotion(editor, "l")).toBe(true);
    expect(editor.state.cursorCol).toBe("a👩‍💻e\u0301".length);
    expect(editor.takeTotalCount).toHaveBeenCalledWith(1);
    editor.takeTotalCount.mockReturnValue(99);
    handleNormalHorizontalMotion(editor, "l");
    expect(editor.state.cursorCol).toBe("a👩‍💻e\u0301中".length);
    handleNormalHorizontalMotion(editor, "h");
    expect(editor.state.cursorCol).toBe(0);
  });

  it("handles a cursor inside a grapheme using the preceding start", () => {
    const editor = fixture(["a👩‍💻b"]);
    editor.state.cursorCol = 3;
    handleNormalHorizontalMotion(editor, "l");
    expect(editor.state.cursorCol).toBe("a👩‍💻".length);
  });

  it("updates autocomplete before refreshing asynchronous dispatch restoration", () => {
    const editor = fixture();
    handleNormalHorizontalMotion(editor, "l");
    expect(editor.lastAction).toBeNull();
    expect(editor.setCursorCol.mock.invocationCallOrder[0]).toBeLessThan(
      editor.updateAutocomplete.mock.invocationCallOrder[0]!,
    );
    expect(editor.updateAutocomplete.mock.invocationCallOrder[0]).toBeLessThan(
      editor.refreshPendingDispatchRestore.mock.invocationCallOrder[0]!,
    );
  });

  it.each([
    "state",
    "segment",
    "setCursorCol",
    "takeTotalCount",
    "updateAutocomplete",
    "refreshPendingDispatchRestore",
  ])("fails loudly when %s is unavailable", (member) => {
    const editor = { ...fixture(), [member]: undefined };
    expect(() => handleNormalHorizontalMotion(editor, "h")).toThrow(
      "horizontal motion runtime is incompatible",
    );
  });
});

describe("prompt-editor display-line remaps", () => {
  it.each(["h", "l", "x", "r", "\x1b[200~"])("delegates %j", (key) => {
    expect(handleVisualLineRemap({}, key)).toBe(false);
  });

  it.each([...pendingStates, { prefixCount: "2" }, { operatorCount: "3" }])(
    "delegates counted or pending input: %j",
    (pending) => {
      const editor = fixture();
      Object.assign(editor, pending);
      for (const key of ["j", "k", "H", "L"])
        expect(handleVisualLineRemap(editor, key)).toBe(false);
      expect(editor.buildVisualLineMap).not.toHaveBeenCalled();
      expect(editor.refreshPendingDispatchRestore).not.toHaveBeenCalled();
    },
  );

  it.each([
    ["j", 0, 1],
    ["k", 1, 0],
  ] as const)("moves %s through Pi's visual-line method", (key, current, target) => {
    const editor = fixture();
    editor.findCurrentVisualLine.mockReturnValue(current);
    expect(handleVisualLineRemap(editor, key)).toBe(true);
    expect(editor.buildVisualLineMap).toHaveBeenCalledWith(10);
    expect(editor.moveToVisualLine).toHaveBeenCalledWith(expect.any(Array), current, target);
    expect(editor.lastAction).toBeNull();
    expect(editor.refreshPendingDispatchRestore).toHaveBeenCalledOnce();
  });

  it.each([
    ["k", 0],
    ["j", 1],
  ] as const)("consumes %s at boundary %i without invoking history", (key, current) => {
    const editor = fixture();
    editor.findCurrentVisualLine.mockReturnValue(current);
    expect(handleVisualLineRemap(editor, key)).toBe(true);
    expect(editor.moveToVisualLine).not.toHaveBeenCalled();
    expect(editor.refreshPendingDispatchRestore).toHaveBeenCalledOnce();
  });

  it.each(["normal", "visual", "visual-line"])("handles H and final-segment L in %s", (mode) => {
    const editor = fixture(["prefix  中e\u0301"]);
    editor.getMode.mockReturnValue(mode);
    editor.buildVisualLineMap.mockReturnValue([
      { logicalLine: 0, startCol: 0, length: 6 },
      { logicalLine: 0, startCol: 6, length: 5 },
    ]);
    editor.findCurrentVisualLine.mockReturnValue(1);
    handleVisualLineRemap(editor, "H");
    expect(editor.state.cursorCol).toBe(8);
    expect(editor.preferredVisualCol).toBeNull();
    expect(editor.snappedFromCursorCol).toBeNull();
    handleVisualLineRemap(editor, "L");
    expect(editor.state.cursorCol).toBe(mode === "normal" ? 9 : 11);
    expect(editor.refreshPendingDispatchRestore).toHaveBeenCalledTimes(2);
  });

  it.each(["normal", "visual", "visual-line"])(
    "keeps L on the last grapheme of a non-final wrap in %s",
    (mode) => {
      const editor = fixture(["a👩‍💻bc"]);
      editor.getMode.mockReturnValue(mode);
      editor.buildVisualLineMap.mockReturnValue([
        { logicalLine: 0, startCol: 0, length: "a👩‍💻".length },
        { logicalLine: 0, startCol: "a👩‍💻".length, length: 2 },
      ]);
      handleVisualLineRemap(editor, "L");
      expect(editor.state.cursorCol).toBe(1);
    },
  );

  it("lets Visual L reach the end before a different logical line", () => {
    const editor = fixture();
    editor.getMode.mockReturnValue("visual");
    handleVisualLineRemap(editor, "L");
    expect(editor.state.cursorCol).toBe(3);
  });

  it.each(["H", "L"])("handles %s on an empty display line", (key) => {
    const editor = fixture([""]);
    expect(handleVisualLineRemap(editor, key)).toBe(true);
    expect(editor.state.cursorCol).toBe(0);
  });

  it("keeps H at the segment start when it contains only whitespace", () => {
    const editor = fixture(["abc   "]);
    editor.buildVisualLineMap.mockReturnValue([{ logicalLine: 0, startCol: 3, length: 3 }]);
    handleVisualLineRemap(editor, "H");
    expect(editor.state.cursorCol).toBe(3);
  });

  it.each([
    "state",
    "lastWidth",
    "buildVisualLineMap",
    "findCurrentVisualLine",
    "moveToVisualLine",
    "segment",
    "refreshPendingDispatchRestore",
  ])("fails loudly when %s is unavailable", (member) => {
    expect(() => handleVisualLineRemap({ ...fixture(), [member]: undefined }, "j")).toThrow(
      "display-line remap runtime is incompatible",
    );
  });

  it("fails loudly when Pi cannot locate the current visual line", () => {
    const editor = fixture();
    editor.findCurrentVisualLine.mockReturnValue(-1);
    expect(() => handleVisualLineRemap(editor, "j")).toThrow(
      "current Pi Editor visual line is unavailable",
    );
  });
});

// Exercise the installed host's private methods too: fixture-only tests cannot
// establish that segmentation, sticky columns and wrapping still match Pi.
describe("navigation against the installed Pi Editor", () => {
  function host(text: string, width = 8) {
    const plain = (value: string) => value;
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
    editor.setText(text);
    editor.render(width);
    const runtime = editor as unknown as ReturnType<typeof fixture>;
    Object.assign(runtime, {
      getMode: () => "normal",
      pendingOperator: null,
      takeTotalCount: vi.fn(() => 1),
      refreshPendingDispatchRestore: vi.fn(),
    });
    return { editor, runtime };
  }

  it("moves by grapheme, clears sticky columns and refreshes real autocomplete", () => {
    const { editor, runtime } = host("a👩‍💻e\u0301中");
    runtime.state.cursorCol = 0;
    runtime.preferredVisualCol = 3;
    runtime.snappedFromCursorCol = 1;
    const update = vi.spyOn(runtime, "updateAutocomplete");
    handleNormalHorizontalMotion(editor, "l");
    expect(editor.getCursor().col).toBe(1);
    expect(runtime.preferredVisualCol).toBeNull();
    expect(runtime.snappedFromCursorCol).toBeNull();
    handleNormalHorizontalMotion(editor, "l");
    expect(editor.getCursor().col).toBe("a👩‍💻".length);
    expect(update).toHaveBeenCalledTimes(2);
  });

  it("uses the host's wrapped-line layout and preserves text at display endpoints", () => {
    const text = "abcdefghijk\nxyz";
    const { editor, runtime } = host(text);
    runtime.state.cursorLine = 0;
    runtime.state.cursorCol = 0;
    const map = runtime.buildVisualLineMap(runtime.lastWidth);
    expect(map.length).toBeGreaterThan(2);
    const move = vi.spyOn(runtime, "moveToVisualLine");
    handleVisualLineRemap(editor, "j");
    expect(move).toHaveBeenCalledWith(map, 0, 1);
    handleVisualLineRemap(editor, "H");
    expect(editor.getCursor()).toEqual({ line: 0, col: map[1]!.startCol });
    handleVisualLineRemap(editor, "L");
    expect(editor.getCursor().col).toBe(map[1]!.startCol + map[1]!.length - 1);
    handleVisualLineRemap(editor, "k");
    expect(runtime.findCurrentVisualLine(map)).toBe(0);
    expect(editor.getText()).toBe(text);
  });
});
