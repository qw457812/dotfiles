type VisualPasteEditorRuntime = {
  getMode: () => string;
  pendingOperator: string | null;
  prefixCount?: string;
  operatorCount?: string;
  pendingG?: boolean;
  pendingMotion?: string | null;
  pendingReplace?: boolean;
  pendingTextObject?: string | null;
  unnamedRegister?: string;
  preferRegisterForPut?: boolean;
  clipboardMirrorPolicy?: string;
  getPasteRegisterText?: () => string;
  getVisualAnchor?: () => { line: number; col: number };
  getCursor?: () => { line: number; col: number };
  getLines?: () => string[];
  getVisualCharwiseRange?: () => { startAbs: number; endAbs: number };
  moveCursorToAbsoluteIndex?: (absoluteIndex: number) => void;
  applyVisualOperator?: (operator: "d" | "y" | "c", linewise: boolean) => void;
  putAfter?: () => void;
  putBefore?: () => void;
  closeUndoWindow?: () => void;
  refreshPendingDispatchRestore?: () => void;
};

// Visual `p` replaces the selection and leaves its deleted text in the
// unnamed register. Visual `P` performs the same replacement without
// changing the register. pi-vim 0.14.1 intentionally swallows both keys.
export function handleVisualPaste(runtime: unknown, data: string): boolean {
  if (data !== "p" && data !== "P") return false;

  const editor = runtime as VisualPasteEditorRuntime;
  if (
    editor.pendingOperator !== null ||
    editor.pendingG ||
    editor.pendingMotion ||
    editor.pendingReplace ||
    editor.pendingTextObject
  ) {
    return false;
  }

  if (
    typeof editor.prefixCount !== "string" ||
    typeof editor.operatorCount !== "string" ||
    typeof editor.unnamedRegister !== "string" ||
    typeof editor.preferRegisterForPut !== "boolean" ||
    typeof editor.clipboardMirrorPolicy !== "string" ||
    !editor.getPasteRegisterText ||
    !editor.getVisualAnchor ||
    !editor.getCursor ||
    !editor.getLines ||
    !editor.getVisualCharwiseRange ||
    !editor.moveCursorToAbsoluteIndex ||
    !editor.applyVisualOperator ||
    !editor.putAfter ||
    !editor.putBefore ||
    !editor.closeUndoWindow ||
    !editor.refreshPendingDispatchRestore
  ) {
    throw new Error("prompt-editor: visual paste runtime is incompatible");
  }

  const putText = editor.getPasteRegisterText();
  if (!putText) {
    editor.prefixCount = "";
    editor.operatorCount = "";
    editor.refreshPendingDispatchRestore();
    return true;
  }

  const linewise = editor.getMode() === "visual-line";
  const charwiseStart = linewise ? null : editor.getVisualCharwiseRange().startAbs;
  const anchor = editor.getVisualAnchor();
  const cursor = editor.getCursor();
  const lines = editor.getLines();
  const selectionStartsAfterFirstLine = Math.min(anchor.line, cursor.line) > 0;
  const selectionEndsAtBufferEnd = Math.max(anchor.line, cursor.line) === lines.length - 1;
  // Deleting a final linewise selection leaves the cursor on the previous
  // line, so replacement must put after it. All other deletions leave the
  // cursor at the selection start and replace with put-before.
  const putAfter = linewise && selectionStartsAfterFirstLine && selectionEndsAtBufferEnd;

  // applyVisualOperator consumes the pending count even though a visual
  // deletion does not use it. Restore the raw count for the subsequent put.
  const putPrefixCount = editor.prefixCount;
  const putOperatorCount = editor.operatorCount;
  const originalRegister = editor.unnamedRegister;
  const originalPreferRegister = editor.preferRegisterForPut;
  const originalMirrorPolicy = editor.clipboardMirrorPolicy;
  let finalRegister = originalRegister;
  let finalPreferRegister = originalPreferRegister;

  // `P` must not mirror the deleted selection to the system clipboard.
  if (data === "P") editor.clipboardMirrorPolicy = "never";

  try {
    editor.applyVisualOperator("d", linewise);
    // Characterwise deletion through end-of-line clamps the cursor onto
    // the previous grapheme. Restore the actual selection start so the
    // replacement does not move before preceding whitespace.
    if (charwiseStart !== null) editor.moveCursorToAbsoluteIndex(charwiseStart);
    if (data === "p") {
      finalRegister = editor.unnamedRegister;
      finalPreferRegister = editor.preferRegisterForPut;
    }

    // Force this exact pre-delete payload for the replacement even when
    // the delete changed the register or launched an asynchronous mirror.
    editor.unnamedRegister = putText;
    editor.preferRegisterForPut = true;
    editor.prefixCount = putPrefixCount;
    editor.operatorCount = putOperatorCount;
    if (putAfter) editor.putAfter();
    else editor.putBefore();
  } finally {
    editor.unnamedRegister = finalRegister;
    editor.preferRegisterForPut = finalPreferRegister;
    editor.clipboardMirrorPolicy = originalMirrorPolicy;
    editor.closeUndoWindow();
    editor.refreshPendingDispatchRestore();
  }

  return true;
}
