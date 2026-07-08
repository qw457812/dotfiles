/**
 * Inspect pi's system prompt pipeline.
 *
 * /prompt-inspect          Current effective system prompt.
 * /prompt-inspect payload  Last provider request payload, HTTP metadata, and
 *                          Pi's parsed assistant message.
 * /prompt-inspect diff     Diff system prompt stages:
 *                          base -> effective -> payload.
 *
 * Stages:
 *   base      getSystemPrompt() at session_start
 *   effective getSystemPrompt() at provider request time
 *   payload   system instructions serialized in the provider request payload
 */

import type { AssistantMessage, ProviderResponse } from "@earendil-works/pi-ai";
import {
  type ExtensionAPI,
  type ExtensionCommandContext,
  generateUnifiedPatch,
} from "@earendil-works/pi-coding-agent";
import { spawn } from "node:child_process";
import { rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

type PromptInspectState = {
  basePrompt?: string;
  lastRequest?: {
    prompt: string;
    payload: unknown;
  };
  lastResponse?: ProviderResponse;
  lastAssistant?: AssistantMessage;
};

type Rec = Record<string, unknown>;
type PayloadTextPart = { text?: unknown };

function joinTextParts(parts: readonly unknown[]): string {
  let out = "";
  for (const part of parts) {
    if (part && typeof part === "object" && typeof (part as PayloadTextPart).text === "string") {
      out += (part as PayloadTextPart).text;
    }
  }
  return out;
}

function normalizeContent(content: unknown): string {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) return joinTextParts(content);
  return "";
}

// Extract provider-serialized system instructions across supported API payload shapes.
function extractSystemFromPayload(payload: unknown): string | undefined {
  if (!payload || typeof payload !== "object") return undefined;
  const p = payload as Rec;

  // OpenAI Codex Responses
  if (typeof p.instructions === "string") return p.instructions;

  // Anthropic / Bedrock
  if (typeof p.system === "string") return p.system;
  if (Array.isArray(p.system)) return normalizeContent(p.system);

  // Google (Gemini / Vertex)
  if (typeof p.systemInstruction === "string") return p.systemInstruction;

  // OpenAI Completions / Responses / Azure / Mistral
  for (const key of ["messages", "input"] as const) {
    const list = p[key];
    if (Array.isArray(list) && list.length > 0) {
      const head = list[0];
      if (head && typeof head === "object") {
        const m = head as Rec;
        if (m.role === "system" || m.role === "developer") return normalizeContent(m.content);
      }
    }
  }

  return undefined;
}

function buildPromptPatch(
  fromLabel: string,
  fromText: string,
  toLabel: string,
  toText: string,
): string {
  return generateUnifiedPatch("system-prompt", fromText, toText)
    .replace("--- system-prompt\n", `--- ${fromLabel}\n`)
    .replace("+++ system-prompt\n", `+++ ${toLabel}\n`);
}

export default function (pi: ExtensionAPI) {
  const state: PromptInspectState = {};

  pi.on("session_start", (_event, ctx) => {
    state.basePrompt = ctx.getSystemPrompt();
  });

  pi.on("before_provider_request", (event, ctx) => {
    state.lastRequest = {
      prompt: ctx.getSystemPrompt(),
      payload: event.payload,
    };
  });

  pi.on("after_provider_response", (event) => {
    state.lastResponse = { status: event.status, headers: event.headers };
  });

  pi.on("message_end", (event) => {
    if (event.message.role === "assistant") {
      state.lastAssistant = event.message;
    }
  });

  pi.registerCommand("prompt-inspect", {
    description: "Inspect the system prompt (payload | diff)",
    getArgumentCompletions(prefix: string) {
      const items = [
        {
          value: "payload",
          label: "payload",
          description: "open provider payload/HTTP metadata plus Pi's parsed assistant response",
        },
        {
          value: "diff",
          label: "diff",
          description: "diff the base, effective, and payload system-prompt stages",
        },
      ];
      const filtered = items.filter((item) => item.value.startsWith(prefix.trimStart()));
      return filtered.length > 0 ? filtered : null;
    },
    handler: async (args, ctx) => {
      const arg = args.trim();
      switch (arg) {
        case "payload": {
          if (state.lastRequest === undefined) {
            ctx.ui.notify("No provider request yet. Send a message first.", "warning");
            return;
          }
          const dump = {
            provider: {
              request: state.lastRequest.payload,
              response: state.lastResponse ?? null,
            },
            pi: {
              assistant: state.lastAssistant ?? null,
            },
          };
          await openInEditor(ctx, JSON.stringify(dump, null, 2), "json");
          return;
        }
        case "diff": {
          if (state.lastRequest === undefined) {
            ctx.ui.notify("No provider request yet. Send a message first.", "warning");
            return;
          }
          if (state.basePrompt === undefined) {
            ctx.ui.notify("No session_start snapshot yet. Restart pi.", "warning");
            return;
          }
          await openDiffInEditor(
            ctx,
            state.basePrompt,
            state.lastRequest.prompt,
            state.lastRequest.payload,
          );
          return;
        }
        case "":
          await openInEditor(ctx, ctx.getSystemPrompt(), "md");
          return;
        default:
          ctx.ui.notify(
            `Unknown argument "${arg}". Usage: /prompt-inspect [payload|diff]`,
            "warning",
          );
          return;
      }
    },
  });
}

async function openDiffInEditor(
  ctx: ExtensionCommandContext,
  base: string,
  effective: string,
  payload: unknown,
): Promise<void> {
  const patches: string[] = [];

  // Stage 1: before_agent_start rewrites (base -> effective).
  if (base !== effective) {
    patches.push(
      buildPromptPatch("system-prompt.base", base, "system-prompt.effective", effective),
    );
  }

  // Stage 2: before_provider_request payload-level rewrites (effective -> payload).
  const sent = extractSystemFromPayload(payload);
  if (sent === undefined) {
    ctx.ui.notify(
      "Could not extract system from payload for /prompt-inspect diff; use /prompt-inspect payload for raw JSON",
      "warning",
    );
  } else if (effective !== sent) {
    patches.push(
      buildPromptPatch("system-prompt.effective", effective, "system-prompt.payload", sent),
    );
  }

  if (patches.length === 0) {
    ctx.ui.notify("System prompt diff: (none; all stages match)", "info");
    return;
  }
  await openInEditor(ctx, patches.join("\n\n"), "diff");
}

async function openInEditor(
  ctx: ExtensionCommandContext,
  text: string,
  ext: string,
): Promise<void> {
  const editorCmd = process.env.VISUAL || process.env.EDITOR;
  if (ctx.mode !== "tui" || !editorCmd) {
    ctx.ui.notify("No editor available ($VISUAL/$EDITOR unset or non-TUI)", "warning");
    return;
  }

  await ctx.ui.custom<void>((tui, _theme, _kb, done) => {
    const filePath = join(tmpdir(), `pi-extension-pager-prompt-inspect-${Date.now()}.${ext}`);
    let stopped = false;

    void (async () => {
      try {
        writeFileSync(filePath, text);
        tui.stop();
        stopped = true;

        const [editor, ...editorArgs] = editorCmd.split(" ");
        process.stdout.write(
          `Opening ${filePath} in ${editorCmd}\nPi will resume when the editor exits.\n`,
        );
        await new Promise<void>((resolve) => {
          const child = spawn(editor, [...editorArgs, filePath], {
            stdio: "inherit",
            shell: process.platform === "win32",
            env: process.env,
          });
          child.on("error", () => resolve());
          child.on("close", () => resolve());
        });
      } finally {
        rmSync(filePath, { force: true });
        if (stopped) {
          tui.start();
          tui.requestRender(true);
        }
        done();
      }
    })();

    return { render: () => [], invalidate: () => {} };
  });
}
