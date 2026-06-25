/**
 * Prompt Inspect: inspect the current system prompt and last provider payload.
 *
 * Command:
 *   /prompt-inspect              Open the effective system prompt (ctx.getSystemPrompt())
 *                                in $VISUAL/$EDITOR.
 *   /prompt-inspect payload      Open the last provider request payload plus its HTTP
 *                                response (status + headers). The request is captured in
 *                                `before_provider_request`; the response in `after_provider_response`
 *                                (body is consumed before that event, so only status/headers).
 *                                Send any message first so there is something to show.
 *   /prompt-inspect diff         Diff three snapshots of the system prompt, split into the
 *                                two extension-mutable stages:
 *               - base -> effective: before_agent_start rewrites (e.g. hide-skills.ts).
 *                 Note: getSystemPrompt() already reflects these by request
 *                 time, so `base` is captured once at session_start (the only
 *                 moment it is unmodified, since before_agent_start fires per
 *                 user message). Per-message base drift from tool changes is
 *                 ignored; use /prompt-inspect for the current value.
 *               - effective -> payload: before_provider_request payload-level rewrites,
 *                 provider identity injection (e.g. Claude Code), and
 *                 serialization. These are invisible to getSystemPrompt().
 *             Empty stages are skipped; if both match, notify "(none)".
 *
 *             Four ways pi mutates the system prompt, and what the diff covers:
 *               1. Build time: SYSTEM.md / --system-prompt / context files /
 *                  skills / tools / --append-system-prompt build the base.
 *                  Visible to getSystemPrompt() (= base). Not a diff stage.
 *               2. before_agent_start returns { systemPrompt } (e.g.
 *                  hide-skills.ts): written back to state.systemPrompt, so
 *                  getSystemPrompt() reflects it; shown as base -> effective.
 *               3. context event returns { messages }: rewrites messages only,
 *                  never system; out of scope.
 *               4. before_provider_request returns a new payload: rewrites the
 *                  provider-level system, invisible to getSystemPrompt();
 *                  shown as effective -> payload.
 *             So the diff covers stages 2 and 4; use /prompt-inspect for stage 1.
 *
 * Outside TUI, or when no editor is set, the command no-ops with a notify.
 *
 * Ref:
 *   registerCommand:
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/coding-agent/docs/extensions.md#L93
 *   ctx.getSystemPrompt + event flow (session_start, before_provider_request):
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/coding-agent/docs/extensions.md#L1016
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/coding-agent/docs/extensions.md#L280
 *   extensions/hide-skills.ts (openDiffInEditor flow, generateUnifiedPatch):
 *     https://github.com/qw457812/dotfiles/blob/dd5505feb520062d6880b6f92ca49811a4f167f9/private_dot_pi/private_agent/extensions/hide-skills.ts#L115
 *     https://github.com/qw457812/dotfiles/blob/dd5505feb520062d6880b6f92ca49811a4f167f9/private_dot_pi/private_agent/extensions/hide-skills.ts#L76
 *   examples/extensions/provider-payload.ts (payload capture):
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/coding-agent/examples/extensions/provider-payload.ts#L6
 *
 * Source (pi monorepo @ a2e3e9d8, pinned to 0.80.2+main):
 *   session_start fires here, with state.systemPrompt already set to base:
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/coding-agent/src/core/agent-session.ts#L2113
 *   before_agent_start result is written back to state.systemPrompt (stage 1):
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/coding-agent/src/core/agent-session.ts#L1132
 *   tool changes rebuild base mid-session (the ignored drift source):
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/coding-agent/src/core/agent-session.ts#L825
 *   emitBeforeAgentStart chains getSystemPrompt across handlers:
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/coding-agent/src/core/extensions/runner.ts#L980
 *   after_provider_request runs AFTER payload serialization (stage 2):
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/coding-agent/src/core/extensions/runner.ts#L946
 *   after_provider_response emits HTTP status + headers (no body):
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/coding-agent/src/core/sdk.ts#L339
 *   ProviderResponse carries only status + headers:
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/ai/src/types.ts#L104
 *   context event (transformContext) also fires after before_agent_start, so
 *   it cannot serve as an unmodified base anchor:
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/coding-agent/src/core/sdk.ts#L351
 *   Per-provider system serialization: see extractSystemFromPayload links.
 */
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
  /** Unmodified system prompt, captured once at session_start. */
  basePrompt?: string;
  /**
   * Snapshot of the last provider request, captured together for accurate pairing.
   * `prompt` is getSystemPrompt() at request time (after before_agent_start).
   */
  lastRequest?: {
    prompt: string;
    payload: unknown;
  };
  /** Last provider response (status + headers); body is consumed before this fires. */
  lastResponse?: { status: number; headers: Record<string, string> };
};

const state: PromptInspectState = {};

type Rec = Record<string, unknown>;
type TextPart = { text?: unknown };

function joinTextParts(parts: unknown[]): string {
  let out = "";
  for (const part of parts) {
    if (part && typeof part === "object" && typeof (part as TextPart).text === "string") {
      out += (part as TextPart).text;
    }
  }
  return out;
}

function normalizeContent(content: unknown): string {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) return joinTextParts(content);
  return "";
}

/** Extract the system instruction from a provider payload across API families.
 * Mirrors how pi-ai serializes context.systemPrompt in each api builder
 * (pi monorepo @ a2e3e9d8, packages/ai/src/api/*.ts):
 *   - codex-responses: payload.instructions
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/ai/src/api/openai-codex-responses.ts#L460
 *   - anthropic: payload.system (string | [{ type:"text", text }])
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/ai/src/api/anthropic-messages.ts#L908
 *   - bedrock: payload.system ([{ text }])
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/ai/src/api/bedrock-converse-stream.ts#L217
 *   - google (gemini/vertex): payload.systemInstruction (string)
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/ai/src/api/google-generative-ai.ts#L358
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/ai/src/api/google-vertex.ts#L457
 *   - openai-completions/responses, azure, mistral: first message in
 *     payload.messages or payload.input with role system/developer
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/ai/src/api/openai-completions.ts#L866
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/ai/src/api/openai-responses-shared.ts#L126
 *     https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/ai/src/api/mistral-conversations.ts#L260 */
function extractSystemFromPayload(payload: unknown): string | undefined {
  if (!payload || typeof payload !== "object") return undefined;
  const p = payload as Rec;

  // OpenAI Codex Responses: top-level instructions.
  if (typeof p.instructions === "string") return p.instructions;

  // Anthropic / Bedrock: top-level system (string | [{ text }] / [{ type:"text", text }]).
  if (typeof p.system === "string") return p.system;
  if (Array.isArray(p.system)) return normalizeContent(p.system);

  // Google (Gemini / Vertex): top-level systemInstruction (string).
  if (typeof p.systemInstruction === "string") return p.systemInstruction;

  // OpenAI Completions / Responses / Azure / Mistral: first item of messages or input
  // with a system/developer role.
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
  // base: getSystemPrompt() at session_start is the unmodified base;
  // before_agent_start only fires per user message
  // (https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/coding-agent/src/core/agent-session.ts#L1111).
  pi.on("session_start", (_event, ctx) => {
    state.basePrompt = ctx.getSystemPrompt();
  });

  // effective: captured together with the payload so the effective->payload
  // stage compares values from the same request; a live getSystemPrompt() in
  // a /prompt-inspect diff could mismatch the payload
  // (https://github.com/earendil-works/pi/blob/a2e3e9d8b26b2e40ed6fd376d3f0819a757559a0/packages/coding-agent/src/core/extensions/runner.ts#L946).
  pi.on("before_provider_request", (event, ctx) => {
    state.lastRequest = {
      prompt: ctx.getSystemPrompt(),
      payload: event.payload,
    };
  });

  // response: HTTP status + headers from after_provider_response, captured per
  // request. The stream body is consumed before this event, so only status/headers
  // are available (ProviderResponse carries no body).
  pi.on("after_provider_response", (event) => {
    state.lastResponse = { status: event.status, headers: event.headers };
  });

  pi.registerCommand("prompt-inspect", {
    description: "Inspect the system prompt (payload | diff)",
    getArgumentCompletions(prefix: string) {
      const items = [
        {
          value: "payload",
          label: "payload",
          description: "open the last provider request payload plus its HTTP response",
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
          const dump = { request: state.lastRequest.payload, response: state.lastResponse ?? null };
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
          // Default: open the current system prompt.
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
