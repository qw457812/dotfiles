import { parse as parseYaml } from "yaml";

export interface ParsedPromptFile {
  meta: Record<string, unknown>;
  body: string;
}

/** Parse prompt frontmatter with the same YAML semantics and delimiters as Pi. */
export function parsePromptFile(text: string): ParsedPromptFile {
  const normalized = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
  if (!normalized.startsWith("---")) return { meta: {}, body: normalized };
  const endIndex = normalized.indexOf("\n---", 3);
  if (endIndex === -1) return { meta: {}, body: normalized };

  const yamlString = normalized.slice(4, endIndex);
  const parsed: unknown = parseYaml(yamlString);
  return {
    meta: (parsed ?? {}) as Record<string, unknown>,
    body: normalized.slice(endIndex + 4).trim(),
  };
}

/** Parse command arguments respecting Pi's single- and double-quoted grouping. */
export function parseCommandArgs(argsString: string): string[] {
  const args: string[] = [];
  let current = "";
  let inQuote: string | null = null;
  for (let index = 0; index < argsString.length; index++) {
    const character = argsString[index];
    if (inQuote !== null) {
      if (character === inQuote) inQuote = null;
      else current += character;
    } else if (character === '"' || character === "'") {
      inQuote = character;
    } else if (/\s/u.test(character ?? "")) {
      if (current !== "") {
        args.push(current);
        current = "";
      }
    } else {
      current += character;
    }
  }
  if (current !== "") args.push(current);
  return args;
}

/** Substitute Pi prompt-template argument placeholders in one non-recursive pass. */
export function substituteArgs(content: string, args: string[]): string {
  const allArgs = args.join(" ");
  return content.replace(
    /\$\{(\d+|ARGUMENTS|@):-([^}]*)\}|\$\{@:(\d+)(?::(\d+))?\}|\$(ARGUMENTS|@|\d+)/gu,
    (
      _match: string,
      defaultTarget: string | undefined,
      defaultValue: string | undefined,
      sliceStart: string | undefined,
      sliceLength: string | undefined,
      simple: string | undefined,
    ): string => {
      if (defaultTarget !== undefined) {
        const value =
          defaultTarget === "@" || defaultTarget === "ARGUMENTS"
            ? allArgs
            : args[Number.parseInt(defaultTarget, 10) - 1];
        return value ? value : (defaultValue ?? "");
      }
      if (sliceStart !== undefined) {
        const start = Math.max(0, Number.parseInt(sliceStart, 10) - 1);
        if (sliceLength !== undefined) {
          return args.slice(start, start + Number.parseInt(sliceLength, 10)).join(" ");
        }
        return args.slice(start).join(" ");
      }
      if (simple === "ARGUMENTS" || simple === "@") return allArgs;
      if (simple === undefined) return _match;
      return args[Number.parseInt(simple, 10) - 1] ?? "";
    },
  );
}
