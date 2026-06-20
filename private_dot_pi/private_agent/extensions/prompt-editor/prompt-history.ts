// Ref: https://github.com/mitsuhiko/agent-stuff/blob/2b70e8d53647c1e0277bd54dbbb2519cb5bea92b/extensions/prompt-editor.ts

import { CONFIG_DIR_NAME } from "@earendil-works/pi-coding-agent";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { Dirent } from "node:fs";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

const MAX_HISTORY_ENTRIES = 100;
const MAX_RECENT_PROMPTS = 30;

export interface PromptEntry {
  text: string;
  timestamp: number;
}

function expandUserPath(p: string): string {
  if (p === "~") return os.homedir();
  if (p.startsWith("~/")) return path.join(os.homedir(), p.slice(2));
  return p;
}

function getGlobalAgentDir(): string {
  const env = process.env.PI_CODING_AGENT_DIR;
  if (env) return expandUserPath(env);
  return path.join(os.homedir(), CONFIG_DIR_NAME, "agent");
}

function extractText(content: Array<{ type: string; text?: string }>): string {
  return content
    .filter((item) => item.type === "text" && typeof item.text === "string")
    .map((item) => item.text ?? "")
    .join("")
    .trim();
}

function collectUserPromptsFromEntries(entries: Array<any>): PromptEntry[] {
  const prompts: PromptEntry[] = [];

  for (const entry of entries) {
    if (entry?.type !== "message") continue;
    const message = entry?.message;
    if (!message || message.role !== "user" || !Array.isArray(message.content)) {
      continue;
    }
    const text = extractText(message.content);
    if (!text) continue;
    const timestamp = Number(message.timestamp ?? entry.timestamp ?? Date.now());
    prompts.push({ text, timestamp });
  }

  return prompts;
}

function getSessionDirForCwd(cwd: string): string {
  const safePath = `--${cwd.replace(/^[/\\]/, "").replace(/[/\\:]/g, "-")}--`;
  return path.join(getGlobalAgentDir(), "sessions", safePath);
}

async function readTail(filePath: string, maxBytes = 256 * 1024): Promise<string> {
  let fileHandle: fs.FileHandle | undefined;
  try {
    const stats = await fs.stat(filePath);
    const size = stats.size;
    const start = Math.max(0, size - maxBytes);
    const length = size - start;
    if (length <= 0) return "";

    const buffer = Buffer.alloc(length);
    fileHandle = await fs.open(filePath, "r");
    const { bytesRead } = await fileHandle.read(buffer, 0, length, start);
    if (bytesRead === 0) return "";
    let chunk = buffer.subarray(0, bytesRead).toString("utf8");
    if (start > 0) {
      const firstNewline = chunk.indexOf("\n");
      if (firstNewline !== -1) {
        chunk = chunk.slice(firstNewline + 1);
      }
    }
    return chunk;
  } catch {
    return "";
  } finally {
    await fileHandle?.close();
  }
}

async function loadPromptHistoryForCwd(
  cwd: string,
  excludeSessionFile?: string,
): Promise<PromptEntry[]> {
  const sessionDir = getSessionDirForCwd(path.resolve(cwd));
  const resolvedExclude = excludeSessionFile ? path.resolve(excludeSessionFile) : undefined;
  const prompts: PromptEntry[] = [];

  let entries: Dirent[] = [];
  try {
    entries = await fs.readdir(sessionDir, { withFileTypes: true });
  } catch {
    return prompts;
  }

  const files = await Promise.all(
    entries
      .filter((entry) => entry.isFile() && entry.name.endsWith(".jsonl"))
      .map(async (entry) => {
        const filePath = path.join(sessionDir, entry.name);
        try {
          const stats = await fs.stat(filePath);
          return { filePath, mtimeMs: stats.mtimeMs };
        } catch {
          return undefined;
        }
      }),
  );

  const sortedFiles = files
    .filter((file): file is { filePath: string; mtimeMs: number } => Boolean(file))
    .sort((a, b) => b.mtimeMs - a.mtimeMs);

  for (const file of sortedFiles) {
    if (resolvedExclude && path.resolve(file.filePath) === resolvedExclude) {
      continue;
    }

    const tail = await readTail(file.filePath);
    if (!tail) continue;
    const lines = tail.split("\n").filter(Boolean);
    for (const line of lines) {
      let entry: any;
      try {
        entry = JSON.parse(line);
      } catch {
        continue;
      }
      if (entry?.type !== "message") continue;
      const message = entry?.message;
      if (!message || message.role !== "user" || !Array.isArray(message.content)) {
        continue;
      }
      const text = extractText(message.content);
      if (!text) continue;
      const timestamp = Number(message.timestamp ?? entry.timestamp ?? Date.now());
      prompts.push({ text, timestamp });
      if (prompts.length >= MAX_RECENT_PROMPTS) break;
    }
    if (prompts.length >= MAX_RECENT_PROMPTS) break;
  }

  return prompts;
}

function buildHistoryList(
  currentSession: PromptEntry[],
  previousSessions: PromptEntry[],
): PromptEntry[] {
  const all = [...currentSession, ...previousSessions];
  all.sort((a, b) => a.timestamp - b.timestamp);

  const seen = new Set<string>();
  const deduped: PromptEntry[] = [];
  for (const prompt of all) {
    const key = `${prompt.timestamp}:${prompt.text}`;
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(prompt);
  }

  return deduped.slice(-MAX_HISTORY_ENTRIES);
}

let loadCounter = 0;

function historiesMatch(a: PromptEntry[], b: PromptEntry[]): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i += 1) {
    if (a[i]?.text !== b[i]?.text || a[i]?.timestamp !== b[i]?.timestamp) {
      return false;
    }
  }
  return true;
}

function buildEditorHistory(history: PromptEntry[]): string[] {
  const entries: string[] = [];

  for (const prompt of history) {
    const text = prompt.text.trim();
    if (!text) continue;
    if (entries[0] === text) continue;
    entries.unshift(text);
    if (entries.length > MAX_HISTORY_ENTRIES) {
      entries.pop();
    }
  }

  return entries;
}

export function hydratePromptHistory(
  editor: { addToHistory?: (text: string) => void },
  history: PromptEntry[],
): void {
  for (const prompt of history) {
    editor.addToHistory?.(prompt.text);
  }
}

export function replacePromptHistory(
  editor: { history?: string[]; historyIndex?: number },
  history: PromptEntry[],
): void {
  editor.history = buildEditorHistory(history);
  editor.historyIndex = -1;
}

export function applyPromptHistory(
  ctx: ExtensionContext,
  setEditor: (history: PromptEntry[]) => void,
  updateHistory?: (history: PromptEntry[]) => void,
): void {
  const sessionFile = ctx.sessionManager.getSessionFile();
  const currentEntries = ctx.sessionManager.getBranch();
  const currentPrompts = collectUserPromptsFromEntries(currentEntries);
  const immediateHistory = buildHistoryList(currentPrompts, []);

  const currentLoad = ++loadCounter;
  const initialText = ctx.ui.getEditorText();
  setEditor(immediateHistory);

  void (async () => {
    const previousPrompts = await loadPromptHistoryForCwd(ctx.cwd, sessionFile ?? undefined);
    if (currentLoad !== loadCounter) return;
    if (ctx.ui.getEditorText() !== initialText) return;
    const history = buildHistoryList(currentPrompts, previousPrompts);
    if (historiesMatch(history, immediateHistory)) return;
    if (updateHistory) {
      updateHistory(history);
      return;
    }
    setEditor(history);
  })();
}
