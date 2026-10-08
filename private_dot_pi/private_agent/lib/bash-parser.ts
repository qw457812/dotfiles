import { createRequire } from "node:module";
import type { Node as SyntaxNode, Parser as WebTreeSitterParser } from "web-tree-sitter";

const require = createRequire(import.meta.url);

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

/**
 * The visitor must be synchronous and return plain data, not nodes:
 * the tree is deleted as soon as the visitor returns.
 */
export async function withBashTree<T>(command: string, visit: (root: SyntaxNode) => T): Promise<T> {
  const parser = await initializeBashParser();
  const tree = parser.parse(command);
  if (!tree) throw new Error("Failed to parse command");

  try {
    return visit(tree.rootNode);
  } finally {
    tree.delete();
  }
}
