import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { AutocompleteItem } from "@earendil-works/pi-tui";
import { homedir } from "node:os";
import { isAbsolute, resolve } from "node:path";

function toAbsoluteAtValue(value: string, cwd: string): string {
  if (!value.startsWith("@")) return value;

  const quoted = value.startsWith('@"') && value.endsWith('"');
  const path = quoted ? value.slice(2, -1) : value.slice(1);
  const hasTrailingSlash = path.endsWith("/") || path.endsWith("\\");
  const expandedPath =
    path === "~" ? homedir() : path.startsWith("~/") ? resolve(homedir(), path.slice(2)) : path;
  let absolutePath = isAbsolute(expandedPath) ? resolve(expandedPath) : resolve(cwd, expandedPath);

  // Match pi's autocomplete display format and preserve directory completion.
  absolutePath = absolutePath.replaceAll("\\", "/");
  if (hasTrailingSlash && !absolutePath.endsWith("/")) absolutePath += "/";

  return quoted || absolutePath.includes(" ") ? `@"${absolutePath}"` : `@${absolutePath}`;
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    ctx.ui.addAutocompleteProvider((current) => ({
      getSuggestions: (lines, cursorLine, cursorCol, options) =>
        current.getSuggestions(lines, cursorLine, cursorCol, options),
      applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
        const absoluteItem: AutocompleteItem = prefix.startsWith("@")
          ? { ...item, value: toAbsoluteAtValue(item.value, ctx.cwd) }
          : item;
        return current.applyCompletion(lines, cursorLine, cursorCol, absoluteItem, prefix);
      },
      shouldTriggerFileCompletion: (lines, cursorLine, cursorCol) =>
        current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ?? true,
    }));
  });
}
