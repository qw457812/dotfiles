/**
 * Prompt Viewer — inspect the current system prompt and last provider payload.
 *
 * Commands:
 *   /prompt   Show the effective system prompt (ctx.getSystemPrompt()).
 *   /payload  Show the last provider request payload, captured from
 *             `before_provider_request`. Send any message first so there is
 *             something to show.
 *
 * In TUI mode the content renders as a scrollable SelectList (j/k or arrows to
 * move, / to filter, enter or esc to close). Outside TUI the full text is
 * written to a temp file and its path is reported, so it can be opened with a
 * pager or copied.
 *
 * Ref: docs/extensions.md (registerCommand, ctx.getSystemPrompt,
 * before_provider_request), examples/extensions/summarize.ts (ui.custom),
 * examples/extensions/provider-payload.ts (payload capture).
 */
import { writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { DynamicBorder } from "@earendil-works/pi-coding-agent";
import { Container, SelectList, Text, type SelectItem } from "@earendil-works/pi-tui";

/** Most recently serialized provider request payload, captured per turn. */
let lastPayload: unknown = undefined;

const MAX_VISIBLE = 30;

const toItems = (text: string): SelectItem[] =>
  text.split("\n").map((line, index) => ({ value: String(index), label: line }));

const dumpToTemp = (name: string, text: string): string => {
  const path = join(tmpdir(), name);
  writeFileSync(path, text, "utf8");
  return path;
};

const showText = async (title: string, text: string, ctx: ExtensionCommandContext) => {
  const tempPath = dumpToTemp("pi-prompt-viewer.txt", text);

  if (ctx.mode !== "tui") {
    ctx.ui.notify(`Written to ${tempPath}`, "info");
    return;
  }

  const items = toItems(text);
  await ctx.ui.custom<void>((tui, theme, _kb, done) => {
    const container = new Container();
    container.addChild(new DynamicBorder((str) => theme.fg("accent", str)));
    container.addChild(new Text(theme.fg("accent", theme.bold(title))));

    const selectList = new SelectList(items, Math.min(items.length, MAX_VISIBLE), {
      selectedPrefix: (text) => theme.fg("accent", text),
      selectedText: (text) => theme.fg("accent", text),
      description: (text) => theme.fg("muted", text),
      scrollInfo: (text) => theme.fg("dim", text),
      noMatch: (text) => theme.fg("warning", text),
    });

    selectList.onSelect = () => done(undefined);
    selectList.onCancel = () => done(undefined);

    container.addChild(selectList);
    container.addChild(new Text(theme.fg("dim", "j/k move · / filter · enter/esc close")));
    container.addChild(new Text(theme.fg("dim", `Full text: ${tempPath}`)));
    container.addChild(new DynamicBorder((str) => theme.fg("accent", str)));

    return {
      render(width: number) {
        return container.render(width);
      },
      invalidate() {
        container.invalidate();
      },
      handleInput(data: string) {
        if (data === "j") {
          selectList.handleInput("\x1b[B"); // down
        } else if (data === "k") {
          selectList.handleInput("\x1b[A"); // up
        } else {
          selectList.handleInput(data);
        }
        tui.requestRender();
      },
    };
  });
};

export default function (pi: ExtensionAPI) {
  pi.on("before_provider_request", (event) => {
    lastPayload = event.payload;
  });

  pi.registerCommand("prompt", {
    description: "Show the current system prompt",
    handler: async (_args, ctx) => {
      await showText("System Prompt", ctx.getSystemPrompt(), ctx);
    },
  });

  pi.registerCommand("payload", {
    description: "Show the last provider request payload",
    handler: async (_args, ctx) => {
      if (lastPayload === undefined) {
        ctx.ui.notify("No provider request yet — send a message first", "warning");
        return;
      }
      await showText("Provider Payload", JSON.stringify(lastPayload, null, 2), ctx);
    },
  });
}
