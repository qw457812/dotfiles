import { CURSOR_MARKER } from "@earendil-works/pi-tui";

type CursorTUI = {
  getShowHardwareCursor?: () => boolean;
  setShowHardwareCursor: (enabled: boolean) => void;
  requestRender: (force?: boolean) => void;
  terminal: { write: (data: string) => void };
};

type CursorEditor = { getMode: () => string };

const CURSOR_STYLE_INSERT = "\x1b[6 q"; // steady bar
const CURSOR_STYLE_NORMAL = "\x1b[2 q"; // steady block
const CURSOR_STYLE_RESET = "\x1b[0 q";

function getCursorStyle(mode: string): string {
  return mode === "insert" ? CURSOR_STYLE_INSERT : CURSOR_STYLE_NORMAL;
}

/** Own cursor preference, focus and terminal shape without wrapping the renderer. */
export function createCursorController(
  writeReset: (data: string) => void = (data) => {
    process.stdout.write(data);
  },
) {
  let blurred = false;
  let hardware = true;
  let activeTui: CursorTUI | undefined;
  let activeEditor: CursorEditor | undefined;
  // Pi's stable Proxy method forwards to replacement renderers after TUI-mode switches.
  let setShowHardwareCursor: CursorTUI["setShowHardwareCursor"] | undefined;

  function applyVisibility(tui: CursorTUI): void {
    const effective = hardware && !blurred;
    if (tui.getShowHardwareCursor?.() !== effective) setShowHardwareCursor?.(effective);
  }

  function writeStyle(tui: CursorTUI, mode: string): void {
    tui.terminal.write(hardware && !blurred ? getCursorStyle(mode) : CURSOR_STYLE_RESET);
  }

  return {
    install(tui: CursorTUI, editor: CursorEditor): void {
      activeTui = tui;
      activeEditor = editor;
      hardware = tui.getShowHardwareCursor?.() ?? true;
      setShowHardwareCursor ??= tui.setShowHardwareCursor;
      // Set visibility outside render() to avoid re-entering the render path.
      applyVisibility(tui);
      if (hardware) writeStyle(tui, editor.getMode());
    },

    syncPreference(mode: string): void {
      // /settings updates the active renderer before rendering. On blur its
      // visibility is forced off, so it no longer reflects the user preference.
      if (blurred || !activeTui) return;
      const enabled = activeTui.getShowHardwareCursor?.();
      if (typeof enabled === "boolean" && enabled !== hardware) {
        hardware = enabled;
        writeStyle(activeTui, mode);
      }
    },

    setFocused(focused: boolean): void {
      blurred = !focused;
      if (!activeTui || !activeEditor) return;
      if (hardware) {
        applyVisibility(activeTui);
        writeStyle(activeTui, activeEditor.getMode());
      } else {
        // Re-render to strip or restore the software cursor's APC wrapper.
        activeTui.requestRender();
      }
    },

    modeChanged(mode: string): void {
      if (activeTui && hardware && !blurred) activeTui.terminal.write(getCursorStyle(mode));
    },

    render(lines: string[], bodyEnd: number): void {
      renderPromptCursor(lines, bodyEnd, { hardware, blurred });
    },

    shutdown(): void {
      blurred = false;
      hardware = true;
      activeTui = undefined;
      activeEditor = undefined;
      setShowHardwareCursor = undefined;
      writeReset(CURSOR_STYLE_RESET);
    },
  };
}

// Pi 1.2 wraps the cursor cell in APC markers, resolved by the TUI after render().
// These delimiters are not exported at the package root. Keep in sync with:
// https://github.com/earendil-works/pi/blob/06a466935536f8c9bcacb2d5efc0fc021be1bdff/packages/tui/src/tui.ts#L198-L206
// A width-clipped line can lose the closing marker, just as in resolveFakeCursors().
const FAKE_CURSOR = /\x1b_pi:fc\x07(.*?)(?:\x1b_pi:\/fc\x07|$)/s;

/** Keep prompt cursor ownership separate from reverse-video selections and labels. */
export function renderPromptCursor(
  lines: string[],
  bodyEnd: number,
  { hardware, blurred }: { hardware: boolean; blurred: boolean },
): void {
  if (!hardware && !blurred) return;

  const hasCursorMarker = lines.slice(1, bodyEnd).some((line) => line.includes(CURSOR_MARKER));
  for (let i = bodyEnd - 1; i >= 1; i--) {
    if (!FAKE_CURSOR.test(lines[i]!)) continue;
    // Only the editor body is ours: never touch the mode label or autocomplete.
    // On blur the TUI hardware cursor is disabled, so remove the APC wrapper too
    // or the TUI would turn it back into a visible software cursor.
    lines[i] = lines[i]!.replace(
      FAKE_CURSOR,
      (_match, cell: string) => `${hardware && !hasCursorMarker ? CURSOR_MARKER : ""}${cell}`,
    );
    return;
  }
}
