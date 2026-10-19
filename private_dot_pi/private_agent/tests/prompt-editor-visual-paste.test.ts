import { describe, expect, it, vi } from "vitest";

import { handleVisualPaste } from "../extensions/prompt-editor/visual-paste.ts";

function fixture() {
  const editor = {
    getMode: vi.fn(() => "visual"),
    pendingOperator: null as string | null,
    pendingG: false,
    pendingMotion: null as string | null,
    pendingReplace: false,
    pendingTextObject: null as string | null,
    prefixCount: "2",
    operatorCount: "3",
    unnamedRegister: "original register",
    preferRegisterForPut: false,
    clipboardMirrorPolicy: "always",
    getPasteRegisterText: vi.fn(() => "clipboard payload"),
    getVisualAnchor: vi.fn(() => ({ line: 0, col: 2 })),
    getCursor: vi.fn(() => ({ line: 0, col: 4 })),
    getLines: vi.fn(() => ["abcdef", "second", "last"]),
    getVisualCharwiseRange: vi.fn(() => ({ startAbs: 2, endAbs: 5 })),
    moveCursorToAbsoluteIndex: vi.fn((_index: number) => {}),
    applyVisualOperator: vi.fn((_operator: "d" | "y" | "c", _linewise: boolean) => {
      editor.prefixCount = "";
      editor.operatorCount = "";
      editor.unnamedRegister = "deleted selection";
      editor.preferRegisterForPut = true;
    }),
    putAfter: vi.fn(),
    putBefore: vi.fn(),
    closeUndoWindow: vi.fn(),
    refreshPendingDispatchRestore: vi.fn(),
  };
  return editor;
}

describe("prompt-editor visual paste", () => {
  it.each(["j", "k", "v", "fp", "tp", "\x1b[200~"])(
    "delegates %j without accessing the runtime",
    (key) => {
      expect(handleVisualPaste({}, key)).toBe(false);
    },
  );

  it.each([
    { pendingOperator: "d" },
    { pendingG: true },
    { pendingMotion: "f" },
    { pendingMotion: "t" },
    { pendingReplace: true },
    { pendingTextObject: "i" },
  ])("delegates pending input: %j", (pending) => {
    const editor = fixture();
    Object.assign(editor, pending);
    for (const key of ["p", "P"]) expect(handleVisualPaste(editor, key)).toBe(false);
    expect(editor.getPasteRegisterText).not.toHaveBeenCalled();
    expect(editor.prefixCount).toBe("2");
    expect(editor.operatorCount).toBe("3");
  });

  it.each(["p", "P"])("resolves the pre-delete payload and restores counts for %s", (key) => {
    const editor = fixture();
    editor.putBefore.mockImplementation(() => {
      expect(editor.unnamedRegister).toBe("clipboard payload");
      expect(editor.preferRegisterForPut).toBe(true);
      expect(editor.prefixCount).toBe("2");
      expect(editor.operatorCount).toBe("3");
      editor.prefixCount = "";
      editor.operatorCount = "";
    });
    expect(handleVisualPaste(editor, key)).toBe(true);
    expect(editor.getPasteRegisterText).toHaveBeenCalledOnce();
    expect(editor.getPasteRegisterText.mock.invocationCallOrder[0]).toBeLessThan(
      editor.applyVisualOperator.mock.invocationCallOrder[0]!,
    );
    expect(editor.applyVisualOperator).toHaveBeenCalledWith("d", false);
    expect(editor.moveCursorToAbsoluteIndex).toHaveBeenCalledWith(2);
    expect(editor.moveCursorToAbsoluteIndex.mock.invocationCallOrder[0]).toBeLessThan(
      editor.putBefore.mock.invocationCallOrder[0]!,
    );
    expect(editor.putAfter).not.toHaveBeenCalled();
    expect(editor.prefixCount).toBe("");
    expect(editor.operatorCount).toBe("");
    expect(editor.closeUndoWindow).toHaveBeenCalledOnce();
    expect(editor.refreshPendingDispatchRestore).toHaveBeenCalledOnce();
    expect(editor.closeUndoWindow.mock.invocationCallOrder[0]).toBeLessThan(
      editor.refreshPendingDispatchRestore.mock.invocationCallOrder[0]!,
    );
  });

  it("keeps the deleted selection and upstream register preference after p", () => {
    const editor = fixture();
    editor.applyVisualOperator.mockImplementation(() => {
      editor.unnamedRegister = "deleted selection";
      editor.preferRegisterForPut = false;
      expect(editor.clipboardMirrorPolicy).toBe("always");
    });
    handleVisualPaste(editor, "p");
    expect(editor.unnamedRegister).toBe("deleted selection");
    expect(editor.preferRegisterForPut).toBe(false);
    expect(editor.clipboardMirrorPolicy).toBe("always");
  });

  it.each([false, true])(
    "preserves the original register and preference %s after P",
    (preference) => {
      const editor = fixture();
      editor.preferRegisterForPut = preference;
      editor.applyVisualOperator.mockImplementation(() => {
        expect(editor.clipboardMirrorPolicy).toBe("never");
        editor.unnamedRegister = "deleted selection";
        editor.preferRegisterForPut = !preference;
      });
      handleVisualPaste(editor, "P");
      expect(editor.unnamedRegister).toBe("original register");
      expect(editor.preferRegisterForPut).toBe(preference);
      expect(editor.clipboardMirrorPolicy).toBe("always");
    },
  );

  it.each(["p", "P"])(
    "consumes an empty payload without deleting or changing mode for %s",
    (key) => {
      const editor = fixture();
      editor.getPasteRegisterText.mockReturnValue("");
      expect(handleVisualPaste(editor, key)).toBe(true);
      expect(editor.prefixCount).toBe("");
      expect(editor.operatorCount).toBe("");
      expect(editor.applyVisualOperator).not.toHaveBeenCalled();
      expect(editor.closeUndoWindow).not.toHaveBeenCalled();
      expect(editor.getMode).not.toHaveBeenCalled();
      expect(editor.refreshPendingDispatchRestore).toHaveBeenCalledOnce();
      expect(editor.unnamedRegister).toBe("original register");
      expect(editor.clipboardMirrorPolicy).toBe("always");
    },
  );

  it.each([
    [0, 0, false],
    [0, 2, false],
    [2, 0, false],
    [1, 1, false],
    [1, 2, true],
    [2, 1, true],
    [2, 2, true],
  ] as const)("replaces linewise selection %i..%i with putAfter=%s", (anchor, cursor, after) => {
    const editor = fixture();
    editor.getMode.mockReturnValue("visual-line");
    editor.getVisualAnchor.mockReturnValue({ line: anchor, col: 0 });
    editor.getCursor.mockReturnValue({ line: cursor, col: 0 });
    handleVisualPaste(editor, "p");
    expect(editor.applyVisualOperator).toHaveBeenCalledWith("d", true);
    expect(editor.getVisualCharwiseRange).not.toHaveBeenCalled();
    expect(editor.moveCursorToAbsoluteIndex).not.toHaveBeenCalled();
    expect(after ? editor.putAfter : editor.putBefore).toHaveBeenCalledOnce();
    expect(after ? editor.putBefore : editor.putAfter).not.toHaveBeenCalled();
  });

  it("puts before when a linewise selection replaces the entire one-line buffer", () => {
    const editor = fixture();
    editor.getMode.mockReturnValue("visual-line");
    editor.getLines.mockReturnValue(["only"]);
    handleVisualPaste(editor, "P");
    expect(editor.putBefore).toHaveBeenCalledOnce();
    expect(editor.putAfter).not.toHaveBeenCalled();
  });

  it("restores the absolute start of a characterwise selection at buffer end", () => {
    const editor = fixture();
    editor.getVisualAnchor.mockReturnValue({ line: 2, col: 3 });
    editor.getCursor.mockReturnValue({ line: 2, col: 0 });
    editor.getVisualCharwiseRange.mockReturnValue({ startAbs: 14, endAbs: 18 });
    handleVisualPaste(editor, "p");
    expect(editor.moveCursorToAbsoluteIndex).toHaveBeenCalledWith(14);
    expect(editor.putBefore).toHaveBeenCalledOnce();
    expect(editor.putAfter).not.toHaveBeenCalled();
  });

  it.each(["p", "P"])("restores register state and mirror policy when put throws for %s", (key) => {
    const editor = fixture();
    const failure = new Error("put failed");
    editor.putBefore.mockImplementation(() => {
      throw failure;
    });
    expect(() => handleVisualPaste(editor, key)).toThrow(failure);
    expect(editor.unnamedRegister).toBe(key === "p" ? "deleted selection" : "original register");
    expect(editor.preferRegisterForPut).toBe(key === "p");
    expect(editor.clipboardMirrorPolicy).toBe("always");
    expect(editor.closeUndoWindow).toHaveBeenCalledOnce();
    expect(editor.refreshPendingDispatchRestore).toHaveBeenCalledOnce();
  });

  it.each(["p", "P"])("restores original state when deletion throws for %s", (key) => {
    const editor = fixture();
    const failure = new Error("delete failed");
    editor.applyVisualOperator.mockImplementation(() => {
      editor.unnamedRegister = "partial deletion";
      throw failure;
    });
    expect(() => handleVisualPaste(editor, key)).toThrow(failure);
    expect(editor.unnamedRegister).toBe("original register");
    expect(editor.preferRegisterForPut).toBe(false);
    expect(editor.clipboardMirrorPolicy).toBe("always");
    expect(editor.putBefore).not.toHaveBeenCalled();
    expect(editor.closeUndoWindow).toHaveBeenCalledOnce();
    expect(editor.refreshPendingDispatchRestore).toHaveBeenCalledOnce();
  });

  it("leaves state untouched when resolving the payload throws", () => {
    const editor = fixture();
    const failure = new Error("read failed");
    editor.getPasteRegisterText.mockImplementation(() => {
      throw failure;
    });
    expect(() => handleVisualPaste(editor, "P")).toThrow(failure);
    expect(editor.clipboardMirrorPolicy).toBe("always");
    expect(editor.applyVisualOperator).not.toHaveBeenCalled();
    expect(editor.closeUndoWindow).not.toHaveBeenCalled();
  });

  it.each([
    "prefixCount",
    "operatorCount",
    "unnamedRegister",
    "preferRegisterForPut",
    "clipboardMirrorPolicy",
    "getPasteRegisterText",
    "getVisualAnchor",
    "getCursor",
    "getLines",
    "getVisualCharwiseRange",
    "moveCursorToAbsoluteIndex",
    "applyVisualOperator",
    "putAfter",
    "putBefore",
    "closeUndoWindow",
    "refreshPendingDispatchRestore",
  ])("fails loudly before mutation when %s is unavailable", (member) => {
    const original = fixture();
    const editor = { ...original, [member]: undefined };
    expect(() => handleVisualPaste(editor, "p")).toThrow("visual paste runtime is incompatible");
    expect(original.getPasteRegisterText).not.toHaveBeenCalled();
  });
});
