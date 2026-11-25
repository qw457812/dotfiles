import { posix } from "node:path";
import type { Node as SyntaxNode } from "web-tree-sitter";

const GIT_GUARDED_SUBCOMMANDS = new Set([
  "add",
  "commit",
  "push",
  "pull",
  "merge",
  "rebase",
  "reset",
  "checkout",
  "switch",
  "stash",
  "cherry-pick",
  "revert",
  "restore",
  "clean",
]);
const GIT_OPTIONS_WITH_VALUE = new Set([
  "-C",
  "-c",
  "--git-dir",
  "--work-tree",
  "--namespace",
  "--config-env",
  "--super-prefix",
  "--attr-source",
]);
const GIT_FLAG_OPTIONS = new Set([
  "--no-pager",
  "--paginate",
  "-p",
  "-P",
  "--bare",
  "--no-replace-objects",
  "--literal-pathspecs",
  "--glob-pathspecs",
  "--noglob-pathspecs",
  "--icase-pathspecs",
  "--no-optional-locks",
  "--no-lazy-fetch",
  "--no-advice",
]);

/** Decode literal shell words, never evaluate expansions. */
function wordText(node: SyntaxNode | null): string | undefined {
  if (!node) return undefined;
  if (node.type === "command_name" || node.type === "concatenation") {
    let value = "";
    for (const child of node.namedChildren) {
      const part = wordText(child);
      if (part === undefined) return undefined;
      value += part;
    }
    return value;
  }
  if (node.type === "raw_string") return node.text.slice(1, -1);
  if (node.type === "string") {
    if (node.namedChildren.some((child) => child?.type !== "string_content")) return undefined;
    return node.text.slice(1, -1).replace(/\\([\s\S])/g, (match, char: string) => {
      if (char === "\n") return "";
      return '$`"\\'.includes(char) ? char : match;
    });
  }
  if (node.type === "word" || node.type === "number") {
    if (/(^|[^\\])(?:\\\\)*[$`*?[~]/.test(node.text)) return undefined;
    return node.text.replace(/\\([\s\S])/g, (_match, char: string) => (char === "\n" ? "" : char));
  }
  return undefined;
}

/**
 * Resolve git's subcommand past its global options. Words may be undefined because only
 * option names and the subcommand itself have to be literal. Anything that cannot be
 * resolved returns undefined and does not trigger Git approval.
 */
function gitSubcommand(words: readonly (string | undefined)[]): string | undefined {
  for (let i = 0; i < words.length; i++) {
    const word = words[i];
    if (word === undefined) return undefined;
    if (word === "--") return words[i + 1];
    if (!word.startsWith("-")) return word;
    if (word === "-h" || word === "--help" || word === "-v" || word === "--version") return word;
    if (GIT_FLAG_OPTIONS.has(word)) continue;
    // Attached global-option values: --git-dir=PATH, -Cpath, -ck=v.
    const equals = word.indexOf("=");
    if (
      (equals > 0 && GIT_OPTIONS_WITH_VALUE.has(word.slice(0, equals))) ||
      (word.length > 2 && (word.startsWith("-C") || word.startsWith("-c")))
    )
      continue;
    if (GIT_OPTIONS_WITH_VALUE.has(word)) {
      i++; // consume the separate value
      if (i >= words.length) return undefined;
      continue;
    }
    return undefined;
  }
  return undefined;
}

export function hasGuardedGitCommand(root: SyntaxNode): boolean {
  for (const node of root.descendantsOfType("command")) {
    if (!node) continue;
    const name = wordText(node.childForFieldName("name"));
    if (name === undefined || posix.basename(name) !== "git") continue;
    const args = node.childrenForFieldName("argument").map((arg) => wordText(arg));
    const subcommand = gitSubcommand(args);
    if (subcommand && GIT_GUARDED_SUBCOMMANDS.has(subcommand)) return true;
  }
  return false;
}
