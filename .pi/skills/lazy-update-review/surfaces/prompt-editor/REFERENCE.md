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
  labelPosition,
  selectionColorizer,
});
```

Colorizer keys differ from editor modes: both visual editor modes share one
color key:

```ts
type Mode = "insert" | "normal" | "visual" | "visual-line";
type ModeColorKey = "insert" | "normal" | "visual" | "ex";
type ModeColorizers = Record<ModeColorKey, (text: string) => string>;
```

Every label colorizer key is required: both narrow and wide paths delegate to
`ModalEditor.render()`.

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

Ex is a normal-mode substate, and `visual-line` uses the `visual` colorizer.
Prefix coloring accounts for both mode unions; labels and pending-command feedback
belong to upstream.

Local rendering calls `super.render(width - PREFIX_WIDTH)` before adding body
prefixes and extending borders; it uses full width only when the prefix cannot fit.
Both upstream label positions are supported. For `bottom-right`, extending the
bottom border after upstream render intentionally leaves two trailing dashes after
the label. During autocomplete, the label remains on the last rendered row, even
when that overwrites suggestion text. The user accepts both behaviors; retain
upstream placement rather than adding a bottom-border relocation workaround.
`top-left` stays on the top border during autocomplete. Cover both positions in
component tests. `selectionColorizer` uses the live theme with reverse-video
fallback for missing or reset-only `selectedBg`.

### Render and preflight contracts

Compare every side effect in the target `ModalEditor.render`, not just its label.
In pi-vim 0.15.1 that includes `preflightHost`, Visual paint, and recording the host's
post-render `lastWidth` in `displayLineWidth` for `gj`/`gk`. Keep the upstream pipeline
at the actual prefix-reduced width, before local decoration.

A failed preflight must reach stock input and rendering before local navigation,
labels, or cursor ownership. Locate these paths with:

```bash
rg -n 'preflightHost|super.render|canRemapNavigation' \
  private_dot_pi/private_agent/extensions/prompt-editor
```

Complete when exact-target component tests cover wrapped `gj`/`gk`, Visual paint,
resize and narrow-to-wide transitions, plus missing-action degradation through the
real local entry point.

## Cursor ownership

`prompt-editor` owns DECSCUSR cursor shape and hardware-cursor visibility. Disable
pi-vim's cursor runtime after construction to prevent competing terminal writes:

```ts
(this as any).cursorShapeRuntime = null;
```

Resolve `cursorShape` with upstream's resolver and map it through
`CURSOR_SHAPE_SEQUENCES`; the local controller receives the resulting sequences.
Non-Insert modes share the Normal shape. Shape settings are upstream-owned;
visibility, focus and safe cursor-cell unwrapping are local policy.

Local `cursor.ts` owns both `createCursorController()` and cursor-cell wrapping;
`index.ts` forwards installation, render, focus, mode-change, and shutdown events.
Compare the controller with the target TUI's hardware-cursor getter/setter and
renderer-switch behavior: retain Pi's stable Proxy setter across editor reinstalls,
read live settings before rendering only while focused, and apply effective
visibility outside render to avoid re-entry. A forced-off cursor on blur is not a
changed user preference. A competing upstream factory forces hardware visibility
on, so both successful and degraded installations resolve the configured
`pi.getSettings().showHardwareCursor` preference, using Pi's `PI_HARDWARE_CURSOR`
default when unset. A failed preflight releases local ownership, then restores
visibility directly on the injected TUI. Cover the full installation path with
forced-on visibility, a false preference and missing host actions; retain tests
for explicit settings overriding the environment default. Verify shutdown clears
references and resets DECSCUSR through stdout, including when no editor was installed.

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
`tests/prompt-editor/cursor.test.ts` against the target host as well as interactive checks.

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
  borderColor?: (text: string) => string;
  pendingExCommand: string | null;
  pendingOperator: string | null;
};

(this as unknown as ModalEditorRuntime).pendingExCommand;
```

Add a field only when local behavior reads or writes it. Remove fields when the
integration stops using them.

### Navigation remaps

Local `navigation.ts` owns logical-line `h`/`l` clamping, display-line endpoints
`H`/`L`, and the shared `canRemapNavigation` guard. `index.ts` delegates `j`/`k`
to upstream's `g` then `j`/`k` input path, including counts. Cursor aliases come
from upstream's `createCursorBindingResolver`, retaining Escape and Vim undo/redo
ownership. Arrows and literal keys share display-row navigation; bare j/k stay
buffer-local rather than recalling history. Backspace maps to `h`; the guarded
`cl -> s` compatibility remap is retained. Successful `cc` still uses upstream
editing, then calls Pi's private `cancelAutocomplete()` to clear the visible picker
and abort pending suggestions: direct host deletion alone leaves the picker alive.
Revalidate this cleanup with visible, in-flight and multiline autocomplete cases.

Literal Normal-mode `gj` aliases upstream `J` (normalized line join). Clear only
`pendingG` before forwarding `J`, retaining the prefix count and upstream undo/dot
recording. Synthetic `j -> gj` calls `super.handleInput` directly and stays a display
motion. Visual `gj`, operator forms such as `dgj`/`cgj`, `gJ`, `gk` and commands with
`pendingGCount` retain upstream semantics. Verify join, count override, dot-repeat,
one-step undo/redo and EOF no-ops without losing the previous repeatable change.

On every upgrade, compare upstream's input dispatch and pending fields. A pending
argument, EX or bracketed-paste discard owns the next key. Revalidate operators,
`pendingG`, `pendingGCount`, `pendingZ`, character motions, replacement and text objects. In
particular, `ZlQ` and `ZjQ` must cancel at the invalid suffix rather than retain
a force-quit prefix. Endpoint H/L helpers additionally delegate pending counts.

Compare every field in `NavigationEditorRuntime` with the exact applicable targets:
Pi's `buildVisualLineMap`, `findCurrentVisualLine`, `segment`, `setCursorCol`,
`updateAutocomplete`, cursor and sticky-column state; pi-vim's `takeTotalCount`,
`displayWantedColumn`, pending fields and `refreshPendingDispatchRestore`. Use exact hashes in librarian
caches rather than normally outdated lazy working trees. Fail loudly when a local
helper's prerequisite is unavailable.

For Normal h/l, derive positions from grapheme starts plus the `line.length`
sentinel. Clamp ordinary motion to first/last grapheme starts; at the sentinel,
l is a no-op and h lands on the final grapheme. Use `setCursorCol` to clear sticky
and snapped columns, then `updateAutocomplete`. H/L clear `preferredVisualCol`.
Both helpers clear upstream's `displayWantedColumn`, so j after local h/l/H/L uses
the new column rather than the previous gj/gk target. These helpers bypass upstream input, so refresh `refreshPendingDispatchRestore`
after moving to preserve asynchronous EX restoration. j/k instead use the upstream
input path, never raw Up/Down host history or a second movement implementation.

Complete when `navigation.test.ts` and `runtime.test.ts` cover multiline boundaries,
counts, emoji/combining graphemes, v$ then Escape/l, wrapped h/l then j/k, H/L in all
selection modes, autocomplete, split paste, Backspace, cursor aliases, rj/rk/rH/rL,
asynchronous EX restoration and every pending state changed by the target.

### Visual paste

pi-vim 0.15.1 still swallows visual `p`/`P`, so local `visual-paste.ts` composes its private
visual operator and put helpers and owns `VisualPasteEditorRuntime`. `index.ts`
retains the Visual-mode dispatch, calling paste before navigation. Revalidate `getSafePutText`, visual ranges,
`applyVisualOperator`, `putBefore`/`putAfter`, unnamed-register preference,
clipboard-mirror policy, and undo-window closure together.

Resolve and validate the effective put payload before deleting the selection.
pi-vim 0.15 filters C0/DEL/C1 controls and normalizes CR/newlines and tabs through
`getSafePutText`; a nonempty raw register can therefore become an empty no-op put.
Verify control-only payloads leave the selection and buffer untouched, and retain
the original register when normalization changes only the insertion payload.
Visual `p` leaves deleted text in the unnamed register; visual `P` preserves the
original register and must not mirror the deletion. Preserve the raw pending count
across the deletion so the put receives it. Restore the absolute selection start
after a characterwise end-of-line deletion. A final linewise selection starting
below line zero needs `putAfter`; other replacements use `putBefore`.

Do not intercept `p`/`P` while an operator, `g`, character motion, replacement, or
text object is pending; pi-vim must finish that sequence. Counts are not such a
guard because they belong to the visual put.

Verification must cover characterwise and linewise `p`/`P`, counted puts, `fp`/`tp`
and pending-`g` sequences, selections ending at the buffer end, one-step undo, the
post-`p` deleted register, and the post-`P` preserved register. Fail loudly if any
required private runtime member is unavailable. Run
`tests/prompt-editor/visual-paste.test.ts`; verify actual buffer, register, and
one-step undo behavior against the installed pi-vim runtime, not just mocked calls.

## Upstream clipboard transport

The local bridge was removed for pi-vim 0.15.1 on Pi 1.5.0. Runtime reads and writes
use upstream defaults; settings still flow through `setClipboardMirrorPolicy`.
Review pi-vim's `clipboard-mirror.ts` and `clipboard-platform.ts` plus Pi's
`copyToClipboard` when their contracts change. Platform reads have a shared 750 ms
budget; ordinary Node writes run Pi's backend through a helper. Termux detection
depends on `TERMUX_VERSION`; macOS uses `/usr/bin/pbpaste`, and Wayland reads
require `WAYLAND_DISPLAY`.

Complete when actual target transport preserves UTF-8, successful empty reads
versus failure (`null`), register fallback, mirror ordering/cancellation and failure
classification. Native clipboard tests snapshot before writing and restore in
`finally`; if snapshotting fails, skip writes and report the blocker. Report
untested operating systems explicitly rather than treating Termux as proof of
macOS/Wayland behavior.

## Replacement-editor session parity

`PromptEditor` replaces the instance configured by pi-vim's `session_start`, so it
must mirror every relevant setting and callback from the target factory:

```ts
editor.setClipboardMirrorPolicy(clipboardMirrorPolicy.policy);
editor.setQuitFn(() => ctx.shutdown());
editor.setNotifyFn((message) => ctx.ui.notify(message, "warning"));
editor.setModeChangeFn(modeChangeHandler);
editor.setHistoryNavigation(historyNavigation.enabled);
editor.setCursorShapeSettings(cursorShape.settings);
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

### Installation lifecycle

Run `tests/prompt-editor/lifecycle.test.ts` for the real extension entry point and
prompt-history helpers against a controlled host and mocked pi-vim dependencies.
The fixture models Pi's text/callback transfer and post-factory border overwrite;
those are host responsibilities, not work performed by prompt-editor itself.
Revalidate that contract against the target `setCustomEditorComponent()`.

Verify late competing installs, coalesced reinstalls, retained drafts/history,
setter callbacks, fresh command names, same/new UI session replacement, and stale
timer callbacks after session replacement or shutdown. History retention includes
both asynchronously loaded previous-session prompts and prompts added since
startup, not only the initial branch snapshot. Reinstalls clone the current
session-owned editor's history, including an intentionally empty array, and reset
its browsing index to `-1`. Only the first install hydrates the branch snapshot;
a new session starts with a fresh editor reference rather than copying its peer.
Shutdown must cancel queued work,
restore an unwrapped bound setter, unsubscribe focus, and release cursor resources.
`tests/prompt-editor/runtime.test.ts` loads the real pinned dependency via the
fixture wrapper and checks the actual local class, routing, selection paint,
wrapped motions, safe Visual puts, cursor ownership and degradation. Host-contract
and component tests do not replace interactive target checks.
