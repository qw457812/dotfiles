/**
 * Permission Gate: accidental-operation confirmation for the bash tool, not a security boundary.
 *
 * Commands:
 *   /gate             Show usage.
 *   /gate git         Show Git approval: ON/OFF without changing it.
 *   /gate git on|off  Control Git confirmation only; other rules remain enabled.
 * Git confirmation defaults to ON, lives only in this extension instance, and resets on /reload.
 *
 * Approval rules:
 * - sudo, mkfs/mkfs.*, and dd.
 * - chown/chgrp: recursive options only.
 * - rm: recursive options or targets lexically normalized to `/`, `.` or `..`.
 *   Literal absolute descendants of /tmp, /var/tmp or the host process's tmpdir() are
 *   exempt when every target is temporary and only common options precede the targets.
 *   On macOS, /private/tmp and /private/var/tmp are also explicitly recognized.
 *   Temporary directory roots themselves still require approval. Variables/globs and
 *   shell-local TMPDIR assignments are not resolved; sudo and other rules still apply.
 * - chmod: recursive or matching world-writable/set-ID modes.
 * - Git: only recognized subcommands in GIT_GUARDED_SUBCOMMANDS.
 * - Writes to /dev/* (including <>), except null, stdout, stderr and fd/0..2.
 *
 * Unresolved arguments and output destinations alone do not require approval. Known
 * recursive options, dangerous modes and literal dangerous targets still do. Unknown
 * deletion targets cannot qualify for the temporary-directory exemption.
 *
 * Syntax errors alone do not require approval; recognized hazards in recovered syntax
 * trees still do. Parser exceptions skip checks and allow execution, with a warning when
 * UI is available. Unknown/unresolved Git subcommands do not trigger Git approval.
 *
 * The shared Tree-sitter Bash parser inspects compound commands and nested substitutions,
 * not ordinary quoted text, comments or SQL keywords. Each tool_call prompts at most once
 * and shows the complete command. If approval is required without UI, execution is blocked.
 * Denial calls ctx.abort() and returns a blocking result with reason "Blocked by user".
 *
 * Coverage limits: only literal executable names (including paths) are recognized.
 * Dynamic names, aliases and functions are not resolved; wrappers such as env, command,
 * xargs and shell -c, and eval strings, are not unwrapped. Variables/globs are not evaluated;
 * filesystem state, symlinks and actual permission effects are not inspected. An unresolved
 * executable name alone does not trigger approval. Device-read redirections are not guarded.
 * Only bash tool_call events are handled, not other tools or user_bash.
 * safe-guard.ts owns write/edit path protection; dirty-repo-guard.ts owns dirty-repo reminders.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { tmpdir } from "node:os";
import { posix } from "node:path";
import type { Node as SyntaxNode } from "web-tree-sitter";
import { withBashTree } from "../lib/bash-parser.ts";

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

/** Inspect the current tree synchronously; return only a boolean, never retain SyntaxNode. */
function requiresApproval(root: SyntaxNode, gitEnabled: boolean): boolean {
  if (
    root.descendantsOfType("file_redirect").some((node) => node && redirectRequiresApproval(node))
  ) {
    return true;
  }

  return root.descendantsOfType("command").some((node) => {
    if (!node) return false;
    const name = wordText(node.childForFieldName("name"));
    if (name === undefined) return false;
    const executable = posix.basename(name);
    if (["sudo", "dd", "mkfs"].includes(executable) || executable.startsWith("mkfs.")) return true;
    if (!["git", "rm", "chmod", "chown", "chgrp"].includes(executable)) return false;

    const args = node.childrenForFieldName("argument").map((arg) => wordText(arg));
    if (executable === "git") {
      if (!gitEnabled) return false;
      const subcommand = gitSubcommand(args);
      return subcommand !== undefined && GIT_GUARDED_SUBCOMMANDS.has(subcommand);
    }
    if (executable === "rm") return rmRequiresApproval(args);
    if (executable === "chmod") return chmodRequiresApproval(args);

    const end = args.indexOf("--");
    const options = end < 0 ? args : args.slice(0, end);
    return options.some((arg) => /^-[^-]*R/.test(arg ?? "") || arg === "--recursive");
  });
}

export default function (pi: ExtensionAPI) {
  let gitEnabled = true;

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;
    const command = (event.input as { command?: string }).command ?? "";
    if (!command.trim()) return;

    const needsApproval = await withBashTree(command, (root) =>
      requiresApproval(root, gitEnabled),
    ).catch(() => {
      if (ctx.hasUI)
        ctx.ui.notify("Permission Gate: command checks skipped (parser failure)", "warning");
      return false;
    });
    if (!needsApproval) return;
    if (!ctx.hasUI) return { block: true, reason: "Command requires user confirmation" };

    pi.events.emit("my:notification", { title: "Pi Danger Approval", body: command });
    const ok = await ctx.ui.confirm("🔐 Allow this command?", command);
    if (!ok) {
      ctx.abort();
      return { block: true, reason: "Blocked by user" };
    }
  });

  pi.registerCommand("gate", {
    description: "Control command confirmation (/gate git [on|off])",
    getArgumentCompletions(prefix: string) {
      const query = prefix.trimStart().toLowerCase();
      const items = (query.includes(" ") ? ["git on", "git off"] : ["git"])
        .filter((item) => item.startsWith(query))
        .map((item) => ({ value: item, label: item }));
      return items.length > 0 ? items : null;
    },
    handler: async (args, ctx) => {
      const [rule, value, ...extra] = args.trim().toLowerCase().split(/\s+/);
      if (rule !== "git" || extra.length || (value && value !== "on" && value !== "off")) {
        ctx.ui.notify("Usage: /gate git [on|off]", args.trim() ? "error" : "info");
        return;
      }
      if (value) gitEnabled = value === "on";
      ctx.ui.notify(`Git approval: ${gitEnabled ? "ON" : "OFF"}`, "info");
    },
  });
}
