import { CURSOR_MARKER } from "@earendil-works/pi-tui";

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
