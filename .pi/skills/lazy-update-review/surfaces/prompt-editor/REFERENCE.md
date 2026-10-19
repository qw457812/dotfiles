# Prompt-editor compatibility patterns

Load each heading only when its owning surface appears in an upstream diff.

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
super(tui, theme, kb, {
  labelColorizers,
  borderColorizers,
  borderSync,
  labelSync,
  offBorderColor,
  labelTransform,
});
```

Colorizer keys can differ from editor modes. For pi-vim 0.14, both visual editor
modes share one color key:

```ts
type Mode = "insert" | "normal" | "visual" | "visual-line";
type ModeColorKey = "insert" | "normal" | "visual" | "ex";
type ModeColorizers = Record<ModeColorKey, (text: string) => string>;
```

Every label colorizer key is required because narrow rendering still delegates to
`ModalEditor.render()` even when the wide renderer is overridden.

### Per-surface synchronization

Resolve `borderSync` and `labelSync` with upstream's resolver so project/global
precedence and deprecated-key translation remain identical:

```ts
const { borderSync, labelSync } = resolveSurfaceSyncMaps(piVimSettings);
const borderColorizers = buildModeColorizers(theme, modeColors);
const offBorderColor = buildOffBorderColor(theme);
```

Pass both maps, `offBorderColor`, and the label's reverse-video transform to the
constructor. Do not emulate a host fallback by deleting colorizer keys; encode it
explicitly as `"host"` in `borderSync`. For example, Insert can retain Pi's current
thinking border while Normal, Visual, and Ex use mode colors:

```json
{
  "borderSync": {
    "insert": "host",
    "normal": "mode",
    "visual": "mode",
    "ex": "mode"
  }
}
```

For custom prefixes, make a mode plain only when its border policy is always
`"mode"`; retain a colored prefix for `"host"` and `"thinking"`, where the border
may not communicate the mode.

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

Use structural access to `getModeLabelColorizer()` rather than indexing
`labelColorizers` directly. The method applies `labelSync`, host-border inheritance,
and the label transform:

```ts
const colorize = editor.getModeLabelColorizer?.() ?? null;
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

Local `cursor.ts` owns both `createCursorController()` and cursor-cell wrapping;
`index.ts` forwards installation, render, focus, mode-change, and shutdown events.
Compare the controller with the target TUI's hardware-cursor getter/setter and
renderer-switch behavior: retain Pi's stable Proxy setter across editor reinstalls,
read live settings before rendering only while focused, and apply effective
visibility outside render to avoid re-entry. A forced-off cursor on blur is not a
changed user preference. Verify shutdown clears references and resets DECSCUSR
through stdout, including when no editor was installed.

Test native focus input separately from injected `my:focus_change` events. In Pi
1.3.0, fullscreen `handleViewportInput()` consumes `ESC[I` / `ESC[O` before
`focus.ts`'s terminal-input listener, so controller event tests alone cannot prove
end-to-end focus tracking. Recheck input-listener ordering at the target revision;
report a blocked native-focus path explicitly rather than treating injected events
as a pass. Exercise a live regular/fullscreen switch to verify the captured Proxy
setter still reaches the replacement renderer.

Pi 1.2 emits APC markers through `renderFakeCursor()`; the TUI resolves them after component
rendering. Compare `renderPromptCursor()` with the exact target's Editor and
`resolveFakeCursors()`, not just pi-vim's `cursor-shape.ts` (0.14.2 still assumes
SGR reverse video). Update its source revision comment when the protocol changes.

Complete when hardware/software cursor modes, live setting toggles, focus/blur,
mode changes, editor reinstalls, shutdown reset, a missing hardware marker, clipped
APC endings, wide/combining graphemes, and narrow rendering pass.
Preserve cursor-cell text and selection styles; restrict changes to the editor body,
leaving borders, mode labels, and autocomplete rows intact. Run
`tests/prompt-editor-cursor.test.ts` against the target host as well as interactive checks.

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

Use small structural types grouped by runtime surface, extending the common shape
when a specialized private surface needs more fields. Keep an `unknown` hop at each
access:

```ts
type ModalEditorRuntime = {
  getMode: () => Mode;
  getModeLabel?: () => string;
  getModeLabelColorizer?: () => ((text: string) => string) | null;
  borderColor?: (text: string) => string;
  pendingExCommand: string | null;
  pendingOperator: string | null;
};

(this as unknown as ModalEditorRuntime).pendingExCommand;
```

Add a field only when local behavior reads or writes it. Remove fields when the
integration stops using them.

### Navigation remaps

Local `navigation.ts` owns two navigation behaviors and their structural runtime
type across Pi and pi-vim. `index.ts` retains the Ex guard, mode dispatch,
Backspace mapping, and upstream fallback; it calls the helpers directly:

- standalone Normal-mode `h`/`l` and mapped Backspace stay on the current logical
  line and move by grapheme;
- `j`/`k`/`H`/`L` use Pi's visual-line layout as `gj`/`gk`/`g^`/`g$`.

On every upgrade, compare pi-vim's input dispatch and pending fields in `index.ts`.
A pending state owns the next key, so a navigation handler returns `false` and lets
pi-vim consume it. The horizontal handler consumes its prefix count through
`takeTotalCount()` but delegates operators, `g`, character motions, replacement,
text objects, and bracketed-paste discard. The display-line handler additionally
delegates prefix and operator counts. Keep the Ex guard before every remap and keep
each structural guard aligned with every pending field it reads.

Compare the handlers with the target revision's
`packages/tui/src/components/editor.ts` in the librarian cache rather than the
normally outdated lazy worktree:

```bash
git -C "$PI_CHK" show \
  "$PI_LAZY_TARGET_REV:packages/tui/src/components/editor.ts"
git -C "$PI_CHK" show \
  "$PI_TARGET_REV:packages/tui/src/components/editor.ts"
```

Inspect `navigation.ts`'s `NavigationEditorRuntime` field by field. For each applicable Pi
target, revalidate `buildVisualLineMap`, `findCurrentVisualLine`, `moveToVisualLine`,
`segment`, `setCursorCol`, `updateAutocomplete`, cursor state, and sticky-column
state. For each applicable pi-vim target, revalidate `takeTotalCount`,
`discardingBracketedPasteInNormalMode`, pending state, and
`refreshPendingDispatchRestore`. Treat these members as one navigation compatibility
surface; fail loudly when a prerequisite is unavailable rather than consume a remap
with partial semantics.

For Normal `h`/`l`, derive positions from grapheme starts plus the `line.length`
sentinel. Clamp ordinary movement to the first and last grapheme starts. If visual
or vertical movement left the cursor at `line.length`, `l` is a no-op and `h` lands
on the final grapheme. Move through `setCursorCol()` so Pi clears sticky-column and
snapped-cursor state, then call `updateAutocomplete()` so a visible picker tracks
the new cursor.

Move `j`/`k` through `moveToVisualLine`; Pi's raw Up/Down handling navigates prompt
history at display boundaries instead of acting like Vim's `gj`/`gk` no-op. Clear
`preferredVisualCol` after horizontal `H`/`L` movement so the next vertical motion
derives a display-line-relative column.

Every consumed remap bypasses `ModalEditor.handleInput()`, so call pi-vim's private
`refreshPendingDispatchRestore()` after moving. This keeps the latest cursor in the
restore snapshot while an asynchronous Ex dispatch is pending.

Horizontal verification is complete when multiline boundaries, counted movement,
emoji and combining graphemes, `v$` followed by Escape and `l`, wrapped-line
`h`/`l` followed by `j`/`k`, active autocomplete, split bracketed paste, and mapped
Backspace pass. Display-line verification is complete when endpoints pass in
Normal, Visual, and Visual-line modes and pending sequences still reach pi-vim. At
minimum, exercise replacement characters (`rj`, `rk`, `rH`, `rL`), asynchronous Ex
restoration, failure when a required private member is unavailable, plus any pending
state changed by the target release.

### Visual paste

pi-vim 0.14.1 swallows visual `p`/`P`, so local `visual-paste.ts` composes its private
visual operator and put helpers and owns `VisualPasteEditorRuntime`. `index.ts`
retains the Visual-mode dispatch, calling paste before navigation. Revalidate `getPasteRegisterText`, visual ranges,
`applyVisualOperator`, `putBefore`/`putAfter`, unnamed-register preference,
clipboard-mirror policy, and undo-window closure together.

Resolve the put payload before deleting the selection. Visual `p` leaves deleted
text in the unnamed register; visual `P` preserves the original register and must
not mirror the deletion. Preserve the raw pending count across the deletion so the
put receives it. Restore the absolute selection start after a characterwise
end-of-line deletion. A final linewise selection starting below line zero needs
`putAfter`; other replacements use `putBefore`.

Do not intercept `p`/`P` while an operator, `g`, character motion, replacement, or
text object is pending; pi-vim must finish that sequence. Counts are not such a
guard because they belong to the visual put.

Verification must cover characterwise and linewise `p`/`P`, counted puts, `fp`/`tp`
and pending-`g` sequences, selections ending at the buffer end, one-step undo, the
post-`p` deleted register, and the post-`P` preserved register. Fail loudly if any
required private runtime member is unavailable. Run
`tests/prompt-editor-visual-paste.test.ts`; verify actual buffer, register, and
one-step undo behavior against the installed pi-vim runtime, not just mocked calls.

## Clipboard bridge

Local `clipboard.ts` owns platform detection, reads, Termux writes, and hook
installation. When upstream clipboard behavior changes, compare pi-vim's
`setClipboardReadFn`, `setClipboardFn`, register fallback, mirror cancellation,
and circuit-breaker error classification with this module.

macOS overrides reads only, using an absolute `pbpaste` path and a UTF-8 locale;
Termux overrides reads and writes only when both Termux:API commands are available.
Other environments retain upstream behavior. Preserve empty text (`""`) versus
failed reads (`null`), which let pi-vim fall back to its unnamed register. Keep
read limits and timeouts shared across both platforms. Termux write failures must
retain the spawn-style metadata consumed by pi-vim's circuit breaker, and aborts
must kill the helper and remove the abort listener.

Complete when `tests/prompt-editor-clipboard.test.ts` passes, and changed upstream hook,
register-fallback, or mirror contracts have been verified against the target
pi-vim runtime. Mocked process tests alone do not prove those contracts.

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
