// Real source dependency for component tests; lifecycle.test.ts mocks this module.
export * from "pi-vim";
export { resolveClipboardMirrorPolicy } from "pi-vim/clipboard-policy.ts";
export { CURSOR_SHAPE_SEQUENCES } from "pi-vim/cursor-shape.ts";
export { createCursorBindingResolver } from "pi-vim/input-keys.ts";
export { cancelModeChangeCommands, createModeChangeHandler } from "pi-vim/mode-change-command.ts";
export { buildModeColorizers, buildOffBorderColor, resolveModeColors } from "pi-vim/mode-colors.ts";
export {
  readPiVimSettings,
  resolveCursorShapeSettings,
  resolveExCommandSettings,
  resolveHistoryNavigation,
  resolveLabelPosition,
  resolveSurfaceSyncMaps,
} from "pi-vim/settings.ts";
