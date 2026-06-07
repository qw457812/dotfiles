# Adapt pi-vim — Reference

## 1. Resolve pi-vim path

Pi manages packages at `<agent-dir>/npm/node_modules/`.
Use `getAgentDir()` from `@earendil-works/pi-coding-agent`:

```ts
import { getAgentDir } from "@earendil-works/pi-coding-agent";

function findPiVimEntry(): string {
  const entry = join(getAgentDir(), "npm", "node_modules", "pi-vim", "index.ts");
  if (existsSync(entry)) return entry;
  throw new Error("...");
}
```

Do NOT use `execSync("npm root -g")` — that returns the system global root, not pi's managed location.
Do NOT run `npm install` directly under `npm/` — use `pi update --extension npm:pi-vim` to upgrade.

## 2. Constructor signature changes

pi-vim 0.10.0 replaced the positional `labelColorizers` parameter with an options bag:

```ts
// v0.9.0 — positional
super(tui, theme, kb, labelColorizers);

// v0.10.0 — options bag
super(tui, theme, kb, { labelColorizers, borderColorizers: null });
```

Always check the `ModalEditor` constructor in the installed `pi-vim/index.ts` for the current
signature after an upgrade. If the 4th argument changed, update your subclass `super()` call
and the constructor parameter list accordingly.

## 3. labelColorizers / borderColorizers type changes

### labelColorizers

Newer pi-vim may add required fields to `labelColorizers` (e.g., `ex` for ex-command mode).
Always add the new field even if your render override bypasses `ModalEditor.render()`;
the narrow-terminal fallback still calls `super.render()`.

```ts
type ModeColorizers = Record<"insert" | "normal" | "ex", (s: string) => string>;

const colorizers: ModeColorizers = {
  insert: (s: string) => theme.fg("borderMuted", reverseVideo(s)),
  normal: (s: string) => theme.fg("borderAccent", reverseVideo(s)),
  ex:     (s: string) => theme.fg("warning",      reverseVideo(s)),
};
```

### borderColorizers

pi-vim 0.10.0 added `borderColorizers` to the constructor options. When the extension
manages its own border color (e.g., thinking-level coloring), pass `null` to disable
pi-vim's mode-aware border colorizer so it doesn't conflict:

```ts
super(tui, theme, kb, { labelColorizers, borderColorizers: null });
```

If you *do* want mode-synced borders, pass matching colorizers and remove any manual
`borderColor` assignment in your code — pi-vim's `installModeBorderColorizer()` will
intercept subsequent `.borderColor` assignments and use them as the fallback.

## 4. Disable pi-vim's built-in cursor shape

If pi-vim adds a `cursorShapeRuntime` field and calls `syncCursorShapeForRender` inside `render()`,
null it out in your subclass constructor when you manage DECSCUSR shapes independently:

```ts
class PromptEditor extends ModalEditor {
  constructor(tui: any, theme: any, kb: any, opts?: ModalEditorOptions) {
    super(tui, theme, kb, opts);
    // Prevent double-writes and conflicting shape sequences.
    (this as any).cursorShapeRuntime = null;
  }
}
```

## 5. Ex-command mode

If pi-vim adds `pendingExCommand: string | null` for `:q`, `:wq`, etc:

**handleInput bypass** — prevent custom remaps from interfering with ex-command typing:
```ts
override handleInput(data: string): void {
  if ((this as unknown as ModalEditorRuntime).pendingExCommand !== null) {
    super.handleInput(data);
    return;
  }
  // ... custom remaps ...
}
```

**Lifecycle hooks** — if the version provides `setQuitFn` / `setNotifyFn`:
```ts
(newEditor as any).setQuitFn(() => ctx.shutdown());
(newEditor as any).setNotifyFn((message: string) => ctx.ui.notify(message, "warning"));
```

## 6. Derive active mode

When ex-command support is present, colorizer selection must account for three modes
(`insert`, `normal`, `ex`) instead of two. Extract a `getActiveMode` helper to avoid
duplicating the pendingExCommand check across multiple colorizer lookups:

```ts
function getActiveMode(editor: ModalEditorRuntime): "insert" | "normal" | "ex" {
  if (editor.pendingExCommand !== null) return "ex";
  return editor.getMode();
}

// Usage in label rendering:
const active = getActiveMode(editor);
const colorize = editor.labelColorizers?.[active] ?? null;

// Usage in prefix rendering:
const colorize = colorizers[getActiveMode(editor)];
```

This mirrors pi-vim's own `getActiveMode()` method (private on `ModalEditor`).

## 7. ModalEditorRuntime type

`ModalEditor` has private fields that TypeScript won't let you cast to directly.
Define a structural type and use the `unknown` hop (required because e.g. `getModeLabel` is private).

```ts
type ModalEditorRuntime = {
  getMode: () => Mode;
  getModeLabel?: () => string;
  labelColorizers?: ModeColorizers | null;
  borderColor?: (s: string) => string;
  pendingExCommand: string | null;
  pendingOperator: string | null;
  addToHistory?: (text: string) => void;
  history?: string[];
  historyIndex?: number;
};

// Usage:
(this as unknown as ModalEditorRuntime).pendingExCommand
(this as unknown as ModalEditorRuntime).pendingOperator
```

Add fields to this type as new private `ModalEditor` members are introduced.

## 8. Cursor stripping helpers

pi-vim provides surgical helpers for stripping the fake inverse-video cursor only at the
`CURSOR_MARKER` position. Copy these functions verbatim rather than writing equivalent regex logic:

```ts
// Constants
const SOFTWARE_CURSOR_START = "\x1b[7m";
const SOFTWARE_CURSOR_RESETS = ["\x1b[0m", "\x1b[27m"] as const;

// Copied from pi-vim — findSoftwareCursorReset.
function findSoftwareCursorReset(
  line: string,
  startIndex: number,
): { index: number; sequence: (typeof SOFTWARE_CURSOR_RESETS)[number] } | null {
  let firstReset: { index: number; sequence: (typeof SOFTWARE_CURSOR_RESETS)[number] } | null = null;
  for (const sequence of SOFTWARE_CURSOR_RESETS) {
    const index = line.indexOf(sequence, startIndex);
    if (index === -1) continue;
    if (!firstReset || index < firstReset.index) {
      firstReset = { index, sequence };
    }
  }
  return firstReset;
}

// Copied from pi-vim — stripSoftwareCursorAfterMarker.
function stripSoftwareCursorAfterMarker(line: string): string {
  const markerIndex = line.indexOf(CURSOR_MARKER);
  if (markerIndex === -1) return line;
  const searchStart = markerIndex + CURSOR_MARKER.length;
  const cursorStart = line.indexOf(SOFTWARE_CURSOR_START, searchStart);
  if (cursorStart === -1) return line;
  const cursorContentStart = cursorStart + SOFTWARE_CURSOR_START.length;
  const reset = findSoftwareCursorReset(line, cursorContentStart);
  if (!reset) return line;
  return (
    line.slice(0, cursorStart) +
    line.slice(cursorContentStart, reset.index) +
    line.slice(reset.index + reset.sequence.length)
  );
}
```

Call from a method that searches body lines bottom-up:

```ts
private stripFakeCursor(lines: string[], bottomIdx: number): void {
  for (let i = bottomIdx - 1; i >= 1; i--) {
    const stripped = stripSoftwareCursorAfterMarker(lines[i]!);
    if (stripped !== lines[i]!) {
      lines[i] = stripped;
      return;
    }
  }
}
```
