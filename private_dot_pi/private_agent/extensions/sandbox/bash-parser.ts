import { createRequire } from "node:module";
import { homedir } from "node:os";
import path from "node:path";
import type { Node as SyntaxNode, Parser as WebTreeSitterParser } from "web-tree-sitter";

const require = createRequire(import.meta.url);

export type StaticEnvAssignment = {
  name: string;
  value: string;
};

export type StaticSimpleCommand = {
  executable: string;
  args: string[];
  cwd: string;
  envAssignments: StaticEnvAssignment[];
};

let bashParserPromise: Promise<WebTreeSitterParser> | undefined;
let bashParser: WebTreeSitterParser | undefined;

export async function initializeBashParser(): Promise<WebTreeSitterParser> {
  if (bashParser) return bashParser;
  if (bashParserPromise) return bashParserPromise;

  bashParserPromise = (async (): Promise<WebTreeSitterParser> => {
    try {
      const { Parser, Language } = await import("web-tree-sitter");
      const treeWasmPath = require.resolve("web-tree-sitter/tree-sitter.wasm");
      const bashWasmPath = require.resolve("tree-sitter-bash/tree-sitter-bash.wasm");

      await Parser.init({
        locateFile() {
          return treeWasmPath;
        },
      });

      const bashLanguage = await Language.load(bashWasmPath);
      const parser = new Parser();
      parser.setLanguage(bashLanguage);
      bashParser = parser;
      return parser;
    } catch (err) {
      bashParserPromise = undefined;
      throw err;
    }
  })();

  return bashParserPromise;
}

export async function parseStaticCommandChain(
  command: string,
  cwd: string,
): Promise<StaticSimpleCommand[] | null> {
  if (!command) return null;

  const parser = await initializeBashParser();
  const tree = parser.parse(command);
  if (!tree) throw new Error("Failed to parse command");

  try {
    return getStaticSimpleCommands(tree.rootNode, cwd);
  } finally {
    tree.delete();
  }
}

function getStaticSimpleCommands(root: SyntaxNode, cwd: string): StaticSimpleCommand[] | null {
  if (root.hasError) return null;
  if (containsDynamicShellSyntax(root) || containsRedirection(root)) return null;

  const children = namedAndOperatorChildren(root);
  if (children.length === 1 && children[0].type === "command") {
    const command = extractSimpleCommand(children[0], cwd);
    return command ? [command] : null;
  }

  if (children.length === 1 && children[0].type === "program") {
    return getStaticSimpleCommands(children[0], cwd);
  }

  if (children.length === 1 && children[0].type === "list") {
    return extractCdAndCommandChain(children[0], cwd);
  }

  return null;
}

function extractCdAndCommandChain(listNode: SyntaxNode, cwd: string): StaticSimpleCommand[] | null {
  const commandNodes = flattenAndList(listNode);
  if (!commandNodes || commandNodes.length === 0) return null;

  let currentCwd = cwd;
  const commands: StaticSimpleCommand[] = [];
  for (let i = 0; i < commandNodes.length; i++) {
    const command = extractSimpleCommand(commandNodes[i], currentCwd);
    if (!command) return null;

    if (i === 0 && command.executable === "cd") {
      if (command.args.length !== 1) return null;
      const nextCwd = resolveStaticPath(command.args[0], currentCwd);
      if (!nextCwd) return null;
      currentCwd = nextCwd;
      continue;
    }

    if (command.executable === "cd") return null;
    commands.push(command);
  }

  return commands.length > 0 ? commands : null;
}

function flattenAndList(node: SyntaxNode): SyntaxNode[] | null {
  if (node.type === "command") return [node];
  if (node.type !== "list") return null;

  const parts = namedAndOperatorChildren(node);
  if (parts.length !== 3 || parts[1].type !== "&&") return null;

  const left = flattenAndList(parts[0]);
  const right = flattenAndList(parts[2]);
  if (!left || !right) return null;
  return [...left, ...right];
}

function extractSimpleCommand(commandNode: SyntaxNode, cwd: string): StaticSimpleCommand | null {
  const children = namedAndOperatorChildren(commandNode);
  const envAssignments: StaticEnvAssignment[] = [];

  for (const child of children) {
    if (child.type !== "variable_assignment") continue;
    const assignment = parseStaticEnvAssignment(child.text);
    if (!assignment) return null;
    envAssignments.push(assignment);
  }

  const commandNameNode = children.find((child) => child.type === "command_name");
  if (!commandNameNode) return null;

  const executable = unquote(commandNameNode.text);
  if (!isStaticText(executable)) return null;

  const args: string[] = [];
  for (const child of children) {
    if (child === commandNameNode || child.type === "variable_assignment") continue;
    if (!isStaticArgumentNode(child)) return null;
    const arg = unquote(child.text);
    if (!isStaticText(arg)) return null;
    args.push(arg);
  }

  return { executable, args, cwd, envAssignments };
}

function parseStaticEnvAssignment(text: string): StaticEnvAssignment | null {
  const match = text.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
  if (!match) return null;
  const value = unquote(match[2] ?? "");
  if (!isStaticText(value)) return null;
  return { name: match[1]!, value };
}

function namedAndOperatorChildren(node: SyntaxNode): SyntaxNode[] {
  const out: SyntaxNode[] = [];
  for (let i = 0; i < node.childCount; i++) {
    const child = node.child(i);
    if (!child) continue;
    if (child.isNamed || child.type === "&&") out.push(child);
  }
  return out;
}

function isStaticArgumentNode(node: SyntaxNode): boolean {
  return (
    node.type === "word" ||
    node.type === "string" ||
    node.type === "raw_string" ||
    node.type === "number"
  );
}

function containsDynamicShellSyntax(root: SyntaxNode): boolean {
  if (root.text.includes("$") || root.text.includes("`")) return true;
  return Boolean(
    root.descendantsOfType([
      "command_substitution",
      "process_substitution",
      "simple_expansion",
      "expansion",
    ]).length,
  );
}

function containsRedirection(root: SyntaxNode): boolean {
  return Boolean(
    root.descendantsOfType([
      "redirected_statement",
      "file_redirect",
      "heredoc_redirect",
      "herestring_redirect",
    ]).length,
  );
}

function isStaticText(text: string): boolean {
  return !text.includes("$") && !text.includes("`");
}

function unquote(text: string): string {
  if (text.length < 2) return text;
  const first = text[0];
  const last = text[text.length - 1];
  if ((first === '"' || first === "'") && first === last) return text.slice(1, -1);
  return text;
}

function expandHome(text: string): string {
  if (text === "~") return homedir();
  if (text.startsWith("~/")) return path.join(homedir(), text.slice(2));
  return text;
}

function resolveStaticPath(text: string, cwd: string): string | null {
  const expanded = expandHome(text);
  if (!isStaticText(expanded)) return null;
  return path.resolve(cwd, expanded);
}
