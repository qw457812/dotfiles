// Pi keeps cursor/layout navigation private. Mirror only the runtime
// surface needed by the horizontal and display-line remaps below:
// https://github.com/earendil-works/pi/blob/845d6ff1f6643aba440341cce877ce1c43ebbc39/packages/tui/src/components/editor.ts#L1371-L1455
// https://github.com/earendil-works/pi/blob/845d6ff1f6643aba440341cce877ce1c43ebbc39/packages/tui/src/components/editor.ts#L1725-L1801
type VisualLine = { logicalLine: number; startCol: number; length: number };
type NavigationEditorRuntime = {
  getMode: () => string;
  pendingOperator: string | null;
  state?: { lines?: string[]; cursorLine?: number; cursorCol?: number };
  lastWidth?: number;
  lastAction?: string | null;
  preferredVisualCol?: number | null;
  snappedFromCursorCol?: number | null;
  prefixCount?: string;
  operatorCount?: string;
  pendingG?: boolean;
  pendingMotion?: string | null;
  pendingReplace?: boolean;
  pendingTextObject?: string | null;
  discardingBracketedPasteInNormalMode?: boolean;
  buildVisualLineMap?: (width: number) => VisualLine[];
  findCurrentVisualLine?: (visualLines: VisualLine[]) => number;
  moveToVisualLine?: (
    visualLines: VisualLine[],
    currentVisualLine: number,
    targetVisualLine: number,
  ) => void;
  segment?: (text: string, granularity: "grapheme") => Iterable<{ index: number; segment: string }>;
  setCursorCol?: (col: number) => void;
  takeTotalCount?: (defaultValue?: number) => number;
  updateAutocomplete?: () => void;
  refreshPendingDispatchRestore?: () => void;
};

// Keep standalone Normal-mode h/l motions on the current logical line.
// pi-vim falls back to Pi's Left/Right handling when a motion reaches a
// boundary, and Pi intentionally wraps those keys across logical lines.
export function handleNormalHorizontalMotion(runtime: unknown, data: string): boolean {
  if (data !== "h" && data !== "l") return false;

  const editor = runtime as NavigationEditorRuntime;
  if (
    editor.pendingOperator !== null ||
    editor.pendingG ||
    editor.pendingMotion ||
    editor.pendingReplace ||
    editor.pendingTextObject ||
    editor.discardingBracketedPasteInNormalMode
  ) {
    return false;
  }

  const state = editor.state;
  if (
    !state ||
    !Array.isArray(state.lines) ||
    typeof state.cursorLine !== "number" ||
    typeof state.cursorCol !== "number" ||
    !editor.segment ||
    !editor.setCursorCol ||
    !editor.takeTotalCount ||
    !editor.updateAutocomplete ||
    !editor.refreshPendingDispatchRestore
  ) {
    throw new Error("prompt-editor: horizontal motion runtime is incompatible");
  }

  const line = state.lines[state.cursorLine] ?? "";
  const cursorCol = state.cursorCol;
  const graphemeStarts = Array.from(editor.segment(line, "grapheme"), ({ index }) => index);
  const positions = [...graphemeStarts, line.length];
  let currentIndex = positions.findIndex((position) => position === cursorCol);
  if (currentIndex === -1) {
    currentIndex = positions.findLastIndex((position) => position < cursorCol);
  }
  currentIndex = Math.max(0, currentIndex);

  const count = editor.takeTotalCount(1);
  const lastNormalIndex = Math.max(0, graphemeStarts.length - 1);
  const targetIndex =
    data === "h"
      ? Math.max(0, currentIndex - count)
      : Math.min(lastNormalIndex, currentIndex + count);
  // Visual mode and vertical movement can leave a Normal-mode cursor at
  // line.length. At that right-hand sentinel, `l` must be a no-op rather
  // than clamping backward onto the final grapheme.
  const targetCol =
    data === "l" && currentIndex > lastNormalIndex ? cursorCol : (positions[targetIndex] ?? 0);

  editor.lastAction = null;
  editor.setCursorCol(targetCol);
  editor.updateAutocomplete();
  editor.refreshPendingDispatchRestore();
  return true;
}

// Display-line remaps in Normal, Visual, and Visual-line modes:
// - j -> gj
// - k -> gk
// - H -> g^
// - L -> g$
export function handleVisualLineRemap(runtime: unknown, data: string): boolean {
  if (data !== "j" && data !== "k" && data !== "H" && data !== "L") return false;

  const editor = runtime as NavigationEditorRuntime;
  if (
    editor.pendingOperator !== null ||
    editor.prefixCount ||
    editor.operatorCount ||
    editor.pendingG ||
    editor.pendingMotion ||
    editor.pendingReplace ||
    editor.pendingTextObject
  ) {
    return false;
  }

  const state = editor.state;
  const width = editor.lastWidth;
  if (
    !state ||
    !Array.isArray(state.lines) ||
    typeof state.cursorLine !== "number" ||
    typeof state.cursorCol !== "number" ||
    typeof width !== "number" ||
    !editor.buildVisualLineMap ||
    !editor.findCurrentVisualLine ||
    !editor.moveToVisualLine ||
    !editor.segment ||
    !editor.refreshPendingDispatchRestore
  ) {
    throw new Error("prompt-editor: display-line remap runtime is incompatible");
  }

  const visualLines = editor.buildVisualLineMap(width);
  const currentVisualLine = editor.findCurrentVisualLine(visualLines);
  const current = visualLines[currentVisualLine];
  if (!current) {
    throw new Error("prompt-editor: current Pi Editor visual line is unavailable");
  }

  editor.lastAction = null;
  if (data === "j" || data === "k") {
    // Do not forward j/k as Up/Down: Pi's arrow handling navigates prompt
    // history at visual-line boundaries, while Vim's gj/gk are no-ops.
    // https://github.com/earendil-works/pi/blob/845d6ff1f6643aba440341cce877ce1c43ebbc39/packages/tui/src/components/editor.ts#L820-L845
    const targetVisualLine = currentVisualLine + (data === "j" ? 1 : -1);
    if (targetVisualLine >= 0 && targetVisualLine < visualLines.length) {
      editor.moveToVisualLine(visualLines, currentVisualLine, targetVisualLine);
    }
    editor.refreshPendingDispatchRestore();
    return true;
  }

  const line = state.lines[current.logicalLine] ?? "";
  const segmentStart = current.startCol;
  const segmentEnd = Math.min(segmentStart + current.length, line.length);
  let targetCol = segmentStart;

  if (data === "H") {
    const firstNonWhitespace = line.slice(segmentStart, segmentEnd).search(/\S/u);
    if (firstNonWhitespace !== -1) targetCol += firstNonWhitespace;
  } else {
    const isLastSegment =
      currentVisualLine === visualLines.length - 1 ||
      visualLines[currentVisualLine + 1]?.logicalLine !== current.logicalLine;
    if ((editor.getMode() === "visual" || editor.getMode() === "visual-line") && isLastSegment) {
      targetCol = segmentEnd;
    } else {
      for (const grapheme of editor.segment(line, "grapheme")) {
        if (grapheme.index >= segmentEnd) break;
        if (grapheme.index >= segmentStart) targetCol = grapheme.index;
      }
    }
  }

  state.cursorLine = current.logicalLine;
  state.cursorCol = targetCol;
  editor.preferredVisualCol = null;
  editor.snappedFromCursorCol = null;
  editor.refreshPendingDispatchRestore();
  return true;
}
