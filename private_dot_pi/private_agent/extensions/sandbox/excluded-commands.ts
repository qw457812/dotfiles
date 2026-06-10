import { homedir } from "node:os";
import path from "node:path";
import {
  initializeBashParser,
  parseStaticCommandChain,
  type StaticSimpleCommand,
} from "./bash-parser.ts";

export type ExcludedCommandMatch = {
  pattern: string;
  candidate: string;
};

const MAX_ALLOWED_SLEEP_SECONDS = 60;

export async function initializeExcludedCommandMatcher(): Promise<void> {
  await initializeBashParser();
}

export async function matchExcludedCommand(
  command: string,
  cwd: string,
  patterns: readonly string[],
): Promise<ExcludedCommandMatch | null> {
  if (!command || !Array.isArray(patterns) || patterns.length === 0) return null;

  const commands = await parseStaticCommandChain(command, cwd);
  if (!commands) return null;

  let firstMatch: ExcludedCommandMatch | null = null;
  for (const simple of commands) {
    if (isAllowedChainUtility(simple)) continue;

    const match = matchSimpleCommand(simple, patterns);
    if (!match) return null;
    firstMatch ??= match;
  }

  return firstMatch;
}

function isAllowedChainUtility(simple: StaticSimpleCommand): boolean {
  if (simple.executable !== "sleep" || simple.args.length !== 1) return false;
  const seconds = Number(simple.args[0]);
  return (
    /^\d+(?:\.\d+)?$/.test(simple.args[0]) &&
    Number.isFinite(seconds) &&
    seconds >= 0 &&
    seconds <= MAX_ALLOWED_SLEEP_SECONDS
  );
}

function matchSimpleCommand(
  simple: StaticSimpleCommand,
  patterns: readonly string[],
): ExcludedCommandMatch | null {
  const candidates = buildCandidates(simple);
  for (const pattern of patterns) {
    if (typeof pattern !== "string" || pattern.length === 0) continue;
    for (const candidate of candidates) {
      if (matchesPattern(pattern, candidate)) {
        return { pattern, candidate };
      }
    }
  }
  return null;
}

function buildCandidates(simple: StaticSimpleCommand): string[] {
  const candidates: string[] = [];
  const args = simple.args.join(" ");
  const add = (value: string) => {
    if (value && !candidates.includes(value)) candidates.push(value);
  };
  const withArgs = (head: string) => (args ? `${head} ${args}` : head);

  const rawExecutable = expandHome(simple.executable);
  const resolvedExecutable = resolveExecutable(simple.executable, simple.cwd);
  const isPathInvocation = hasPathSeparator(simple.executable) || hasPathSeparator(rawExecutable);

  add(withArgs(rawExecutable));
  add(rawExecutable);
  if (resolvedExecutable) {
    add(withArgs(resolvedExecutable));
    add(resolvedExecutable);
  }

  // Only bare command invocations get basename candidates. Do not let `gh:*`
  // match `./gh repo view` or `/tmp/gh repo view`; path invocations must use
  // explicit path patterns such as `*/skills/web-browser/scripts/*`.
  if (!isPathInvocation) {
    const baseExecutable = path.basename(rawExecutable);
    add(withArgs(baseExecutable));
    add(baseExecutable);
  }

  return candidates;
}

function expandHome(text: string): string {
  if (text === "~") return homedir();
  if (text.startsWith("~/")) return path.join(homedir(), text.slice(2));
  return text;
}

function resolveExecutable(executable: string, cwd: string): string | null {
  const expanded = expandHome(executable);
  if (
    expanded.startsWith("/") ||
    expanded.startsWith("./") ||
    expanded.startsWith("../") ||
    expanded.includes("/")
  ) {
    return path.resolve(cwd, expanded);
  }
  return null;
}

function hasPathSeparator(text: string): boolean {
  return text.includes("/") || text.includes("\\");
}

function matchesPattern(pattern: string, candidate: string): boolean {
  const expandedPattern = expandHome(pattern);
  const prefix = extractLegacyPrefix(expandedPattern);
  if (prefix !== null) {
    return candidate === prefix || candidate.startsWith(`${prefix} `);
  }

  if (hasUnescapedWildcard(expandedPattern)) {
    return wildcardToRegex(expandedPattern).test(candidate);
  }

  return candidate === expandedPattern;
}

function extractLegacyPrefix(pattern: string): string | null {
  const match = pattern.match(/^(.+):\*$/);
  return match?.[1] ?? null;
}

function hasUnescapedWildcard(pattern: string): boolean {
  if (pattern.endsWith(":*")) return false;
  for (let i = 0; i < pattern.length; i++) {
    if (pattern[i] !== "*") continue;
    let backslashes = 0;
    let j = i - 1;
    while (j >= 0 && pattern[j] === "\\") {
      backslashes++;
      j--;
    }
    if (backslashes % 2 === 0) return true;
  }
  return false;
}

function wildcardToRegex(pattern: string): RegExp {
  let source = "";
  for (let i = 0; i < pattern.length; i++) {
    const char = pattern[i];
    if (char === "\\" && i + 1 < pattern.length) {
      const next = pattern[i + 1];
      if (next === "*" || next === "\\") {
        source += escapeRegex(next);
        i++;
        continue;
      }
    }
    if (char === "*") {
      source += ".*";
    } else {
      source += escapeRegex(char);
    }
  }
  return new RegExp(`^${source}$`, "s");
}

function escapeRegex(text: string): string {
  return text.replace(/[.+?^${}()|[\]\\'"/]/g, "\\$&");
}
