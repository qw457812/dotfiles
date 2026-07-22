# pi-vim compatibility patterns

Load only the headings implicated by the upstream diff.

## Pi-managed module resolution

Resolve pi-vim below Pi's agent directory:

```ts
import { getAgentDir } from "@earendil-works/pi-coding-agent";

function findPiVimEntry(): string {
  const entry = join(getAgentDir(), "npm", "node_modules", "pi-vim", "index.ts");
  if (existsSync(entry)) return entry;
  throw new Error("prompt-editor: pi-vim not found");
}
```

`prompt-editor` generates a sibling wrapper because its loader cannot reliably
resolve pi-vim directly. Re-export `index.ts` plus any required internal helper from
the same installed directory:

```ts
export * from ${JSON.stringify(piVimEntry)};
export { readPiVimSettings } from ${JSON.stringify(join(piVimDir, "settings.ts"))};
```

The wrapper's complete condition is that every re-export resolves below
`getAgentDir()/npm/node_modules/pi-vim`.

## Constructor and colorizers

Diff `ModalEditor`'s constructor and options on every upgrade. Keep the local
constructor parameters aligned with the options passed to `super()`:

```ts
super(tui, theme, kb, { labelColorizers, borderColorizers });
```

Colorizer keys can differ from editor modes. For pi-vim 0.13, both visual editor
modes share one color key:

```ts
type Mode = "insert" | "normal" | "visual" | "visual-line";
type ModeColorKey = "insert" | "normal" | "visual" | "ex";
type ModeColorizers = Record<ModeColorKey, (text: string) => string>;
```

Every label colorizer key is required because narrow rendering still delegates to
`ModalEditor.render()` even when the wide renderer is overridden.

### Mode-synced border with Insert fallback

Pi assigns its thinking-level `borderColor` after editor construction. pi-vim's
mode-aware property setter retains that assignment as the base fallback. To keep
Insert on the thinking-level border while coloring Normal, Visual, and Ex, omit the
Insert colorizer at runtime:

```ts
const borderColorizers =
  piVimSettings.syncBorderColorWithMode === true
    ? buildModeColorizers(theme, modeColors)
    : null;
if (borderColorizers) {
  delete (borderColorizers as Partial<ModeColorizers>).insert;
}
```

The `Partial` cast bridges pi-vim's complete `Record` type to its runtime fallback
behavior. When mode-synced borders already carry state, plain prefixes avoid a
second competing mode signal; otherwise retain mode-colored prefixes.

## Active mode and labels

Ex is a normal-mode substate, and `visual-line` uses the `visual` colorizer:

```ts
function getActiveMode(editor: ModalEditorRuntime): ModeColorKey {
  if (editor.pendingExCommand !== null) return "ex";
  const mode = editor.getMode();
  return mode === "visual-line" ? "visual" : mode;
}
```

A renderer that bypasses `ModalEditor.render()` needs fallback labels for every
editor mode:

```ts
const labels: Record<Mode, string> = {
  insert: " INSERT ",
  normal: " NORMAL ",
  visual: " VISUAL ",
  "visual-line": " V-LINE ",
};
```

The complete condition is that label, prefix, border, and cursor code all account
for every member of both unions.

## Cursor ownership

`prompt-editor` owns DECSCUSR cursor shape and hardware-cursor visibility. Disable
pi-vim's cursor runtime after construction to prevent competing terminal writes:

```ts
(this as any).cursorShapeRuntime = null;
```

Treat every non-Insert mode as a block cursor unless the upstream mode semantics
require another shape:

```ts
function getCursorStyle(mode: Mode): string {
  return mode === "insert" ? CURSOR_STYLE_INSERT : CURSOR_STYLE_NORMAL;
}
```

The local `findSoftwareCursorReset` and `stripSoftwareCursorAfterMarker` copies must
match the target `cursor-shape.ts` implementation exactly. Compare them during any
cursor-related upstream change and update their source revision comments.

## Ex input passthrough

While `pendingExCommand` is active, delegate input before applying custom Normal-mode
remaps:

```ts
override handleInput(data: string): void {
  if ((this as unknown as ModalEditorRuntime).pendingExCommand !== null) {
    super.handleInput(data);
    return;
  }
  // custom remaps
}
```

This keeps command text, paste guards, Enter submission, and Escape handling under
pi-vim's Ex state machine.

## Structural access to private runtime state

Use one structural type for private fields required by the integration, with an
`unknown` hop at each access:

```ts
type ModalEditorRuntime = {
  getMode: () => Mode;
  getModeLabel?: () => string;
  labelColorizers?: ModeColorizers | null;
  borderColor?: (text: string) => string;
  pendingExCommand: string | null;
  pendingOperator: string | null;
  setClipboardFn?: (fn: (text: string, signal?: AbortSignal) => unknown) => void;
  setClipboardReadFn?: (fn: () => string | null) => void;
};

(this as unknown as ModalEditorRuntime).pendingExCommand;
```

Add a field only when local behavior reads or writes it. Remove fields when the
integration stops using them.

## Replacement-editor session parity

`PromptEditor` replaces the instance configured by pi-vim's `session_start`, so it
must mirror every relevant setting and callback from the target factory:

```ts
editor.setClipboardMirrorPolicy(clipboardMirrorPolicy.policy);
editor.setQuitFn(() => ctx.shutdown());
editor.setNotifyFn((message) => ctx.ui.notify(message, "warning"));
editor.setModeChangeFn(modeChangeHandler);
editor.setExCommandSettings(exCommand.settings);
editor.setCommandNamesFn(
  () => new Set([...PI_VIM_BUILTIN_COMMAND_NAMES, ...pi.getCommands().map((c) => c.name)]),
);
```

Resolve command names at submit time so reloads and mid-session registrations are
visible. `pi.getCommands()` excludes builtin interactive commands, so keep the local
builtin list aligned with pi-vim's `EX_BUILTIN_COMMAND_NAMES`.

Use upstream settings readers and resolvers to preserve global/project trust rules,
including the global-only clipboard-copy setting. Pair each upstream process or
resource setup with its target `session_shutdown` cleanup, such as
`cancelModeChangeCommands()`.

The complete condition is a setter-by-setter comparison with the target pi-vim
factory: every difference is either mirrored or justified by `prompt-editor` owning
that behavior (for example cursor shape or thinking-level border fallback).
