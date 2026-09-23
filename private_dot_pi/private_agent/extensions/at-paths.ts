import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { AutocompleteItem } from "@earendil-works/pi-tui";
import { homedir } from "node:os";
import { isAbsolute, resolve } from "node:path";

// Pi 0.86 autocompleteSeparatorRegex (not exported from the public entry point).
const pathSeparator =
  /(?:\s|(?=\p{Punctuation})[\p{Script_Extensions=Han}\p{Script_Extensions=Hiragana}\p{Script_Extensions=Katakana}\p{Script_Extensions=Hangul}\p{Script_Extensions=Bopomofo}]|[，．：；！？（）［］｛｝“”‘’…—])/u;

function formatAtPath(value: string, cwd: string): string {
  if (!value.startsWith("@")) return value;

  const quoted = value.startsWith('@"') && value.endsWith('"');
  const path = quoted ? value.slice(2, -1) : value.slice(1);
  const hasTrailingSlash = path.endsWith("/") || path.endsWith("\\");
  const expandedPath =
    path === "~" ? homedir() : path.startsWith("~/") ? resolve(homedir(), path.slice(2)) : path;
  let displayPath = isAbsolute(expandedPath) ? resolve(expandedPath) : resolve(cwd, expandedPath);

  // Match pi's autocomplete display format and preserve directory completion.
  displayPath = displayPath.replaceAll("\\", "/");
  const home = resolve(homedir()).replaceAll("\\", "/");
  if (displayPath === home || displayPath.startsWith(`${home}/`)) {
    displayPath = `~${displayPath.slice(home.length)}`;
  }
  if (hasTrailingSlash && !displayPath.endsWith("/")) displayPath += "/";

  return quoted || pathSeparator.test(displayPath) ? `@"${displayPath}"` : `@${displayPath}`;
}

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    ctx.ui.addAutocompleteProvider((current) => ({
      getSuggestions: (lines, cursorLine, cursorCol, options) =>
        current.getSuggestions(lines, cursorLine, cursorCol, options),
      applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
        const formattedItem: AutocompleteItem = prefix.startsWith("@")
          ? { ...item, value: formatAtPath(item.value, ctx.cwd) }
          : item;
        return current.applyCompletion(lines, cursorLine, cursorCol, formattedItem, prefix);
      },
      shouldTriggerFileCompletion: (lines, cursorLine, cursorCol) =>
        current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ?? true,
    }));
  });
}
