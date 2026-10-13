import { tmpdir } from "node:os";
import { posix } from "node:path";
import type { Node as SyntaxNode } from "web-tree-sitter";

const TEMP_DIRECTORIES = [
  "/tmp",
  "/var/tmp",
  tmpdir(),
  ...(process.platform === "darwin" ? ["/private/tmp", "/private/var/tmp"] : []),
]
  .map((path) => posix.normalize(path).replace(/\/+$/, ""))
  .filter((path) => posix.isAbsolute(path));

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

function redirectRequiresApproval(node: SyntaxNode): boolean {
  const writes = node.children.some(
    (child) => child && [">", ">>", ">|", "&>", "&>>", ">&", "<>"].includes(child.type),
  );
  if (!writes) return false;

  const destination = wordText(node.childForFieldName("destination"));
  if (destination === undefined) return false;
  const path = posix.normalize(destination);
  return path.startsWith("/dev/") && !/^\/dev\/(?:null|stdout|stderr|fd\/[012])$/.test(path);
}

function rmRequiresApproval(words: readonly (string | undefined)[]): boolean {
  const paths = words.map((word) =>
    word === undefined ? undefined : posix.normalize(word).replace(/\/+$/, "") || "/",
  );

  // Only common, leading flags are eligible for the temporary-target exemption.
  let start = 0;
  while (/^(?:-[dfiIrRv]+|--(?:force|recursive|dir|verbose))$/.test(words[start] ?? "")) start++;
  if (words[start] === "--") start++;
  const targets = paths.slice(start);
  if (targets.some((path) => path !== undefined && TEMP_DIRECTORIES.includes(path))) return true;
  if (
    targets.length > 0 &&
    targets.every(
      (path) => path !== undefined && TEMP_DIRECTORIES.some((dir) => path.startsWith(`${dir}/`)),
    )
  )
    return false;

  const end = words.indexOf("--");
  const options = end < 0 ? words : words.slice(0, end);
  return (
    options.some((word) => /^-[^-]*[rR]/.test(word ?? "") || word === "--recursive") ||
    paths.some((path) => path !== undefined && ["/", ".", ".."].includes(path))
  );
}

function chmodRequiresApproval(words: readonly (string | undefined)[]): boolean {
  const end = words.indexOf("--");
  const options = end < 0 ? words : words.slice(0, end);
  if (options.some((word) => /^-[^-]*R/.test(word ?? "") || word === "--recursive")) return true;

  if (options.some((word) => word === "--reference" || word?.startsWith("--reference=")))
    return false;

  const mode =
    end < 0
      ? words.find(
          (word) => word === undefined || !word.startsWith("-") || /^-0*[0-7]{1,4}$/.test(word),
        )
      : words[end + 1];
  if (!mode) return false;
  if (/^[+=-]?0*[0-7]{1,4}$/.test(mode)) {
    if (mode.startsWith("-")) return false;
    const permissions = Number.parseInt(mode.replace(/^[+=]/, ""), 8);
    return (permissions & 0o002) !== 0 || (permissions & 0o6000) !== 0;
  }
  return mode
    .split(",")
    .some((part) => /[+=][^,]*s/.test(part) || /^(?:[ug]*[oa][ugoa]*|)[+=][^,]*w/.test(part));
}

export const RULE_LABELS = {
  "device-write": "Device write",
  sudo: "Sudo",
  dd: "Disk/data copy",
  mkfs: "Filesystem formatting",
  rm: "Deletion",
  chmod: "Permission change",
  chown: "Ownership change",
  chgrp: "Group change",
  git: "Git mutation",
} as const;

export type GateRule = keyof typeof RULE_LABELS;

/** Inspect synchronously; retain only fixed rule names, never SyntaxNode or command text. */
export function approvalRules(root: SyntaxNode, gitEnabled: boolean): GateRule[] {
  const rules = new Set<GateRule>();
  if (
    root.descendantsOfType("file_redirect").some((node) => node && redirectRequiresApproval(node))
  )
    rules.add("device-write");

  for (const node of root.descendantsOfType("command")) {
    if (!node) continue;
    const name = wordText(node.childForFieldName("name"));
    if (name === undefined) continue;
    const executable = posix.basename(name);
    if (executable === "sudo" || executable === "dd") {
      rules.add(executable);
      continue;
    }
    if (executable === "mkfs" || executable.startsWith("mkfs.")) {
      rules.add("mkfs");
      continue;
    }
    if (!["git", "rm", "chmod", "chown", "chgrp"].includes(executable)) continue;

    const args = node.childrenForFieldName("argument").map((arg) => wordText(arg));
    if (executable === "git") {
      const subcommand = gitSubcommand(args);
      if (gitEnabled && subcommand !== undefined && GIT_GUARDED_SUBCOMMANDS.has(subcommand))
        rules.add("git");
    } else if (executable === "rm") {
      if (rmRequiresApproval(args)) rules.add("rm");
    } else if (executable === "chmod") {
      if (chmodRequiresApproval(args)) rules.add("chmod");
    } else {
      const end = args.indexOf("--");
      const options = end < 0 ? args : args.slice(0, end);
      if (options.some((arg) => /^-[^-]*R/.test(arg ?? "") || arg === "--recursive"))
        rules.add(executable as "chown" | "chgrp");
    }
  }
  return [...rules];
}
