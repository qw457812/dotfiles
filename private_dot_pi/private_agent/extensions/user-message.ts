import { UserMessageComponent, type ExtensionAPI, type Theme } from "@earendil-works/pi-coding-agent";
import { stripTerminalSequences } from "@earendil-works/pi-tui";

const OSC133_ZONE_PREFIX = /^((?:\x1b\]133;[ABC](?:\x07|\x1b\\))+)/;

type RenderFn = (width: number) => string[];
type ThinkingLevel = ReturnType<ExtensionAPI["getThinkingLevel"]>;
type PatchableUserMessagePrototype = {
  render: RenderFn;
  outputPad?: number;
  __prefixedUserMessageOriginalRender?: RenderFn;
  __prefixedUserMessagePatched?: boolean;
  __prefixedUserMessageGetTheme?: () => Theme | undefined;
  __prefixedUserMessageGetThinkingLevel?: () => ThinkingLevel;
};

function prependAfterPromptMarkers(line: string, prefix: string): string {
  const markers = line.match(OSC133_ZONE_PREFIX)?.[0] ?? "";
  return markers + prefix + line.slice(markers.length);
}

function findFirstContentLine(lines: string[]): number {
  const contentLine = lines.findIndex((line) => stripTerminalSequences(line).trim().length > 0);
  if (contentLine >= 0) return contentLine;

  // Box currently adds one line of vertical padding around image-only content.
  return lines.length > 2 ? 1 : -1;
}

function decorateUserMessage(
  lines: string[],
  gutterWidth: number,
  theme: Theme,
  thinkingLevel: ThinkingLevel,
): string[] {
  const firstContentLine = findFirstContentLine(lines);
  const emptyGutter = theme.bg("userMessageBg", " ".repeat(gutterWidth));
  const prompt = theme.getThinkingBorderColor(thinkingLevel)("❯");
  const promptGutter = theme.bg("userMessageBg", prompt + " ".repeat(Math.max(0, gutterWidth - 1)));

  return lines.map((line, index) =>
    prependAfterPromptMarkers(line, index === firstContentLine ? promptGutter : emptyGutter),
  );
}

function patchUserMessageRender(getTheme: () => Theme | undefined, getThinkingLevel: () => ThinkingLevel): void {
  const prototype = UserMessageComponent.prototype as unknown as PatchableUserMessagePrototype;
  prototype.__prefixedUserMessageGetTheme = getTheme;
  prototype.__prefixedUserMessageGetThinkingLevel = getThinkingLevel;

  if (prototype.__prefixedUserMessagePatched) return;

  prototype.__prefixedUserMessageOriginalRender = prototype.render;
  prototype.render = function renderWithUserMessagePrefix(width: number): string[] {
    const original = prototype.__prefixedUserMessageOriginalRender ?? prototype.render;
    const theme = prototype.__prefixedUserMessageGetTheme?.();
    if (!theme) return original.call(this, width);

    const outputPad = this.outputPad === 0 ? 0 : 1;
    const gutterWidth = Math.min(2 - outputPad, Math.max(0, width - 1));
    if (gutterWidth === 0) return original.call(this, width);

    const lines = original.call(this, width - gutterWidth);
    const thinkingLevel = prototype.__prefixedUserMessageGetThinkingLevel?.() ?? "off";
    return decorateUserMessage(lines, gutterWidth, theme, thinkingLevel);
  };
  prototype.__prefixedUserMessagePatched = true;
}

export default function (pi: ExtensionAPI) {
  let activeTheme: Theme | undefined;
  let activeThinkingLevel: ThinkingLevel = "off";

  patchUserMessageRender(() => activeTheme, () => activeThinkingLevel);

  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI) return;
    activeTheme = ctx.ui.theme;
    activeThinkingLevel = pi.getThinkingLevel();
    patchUserMessageRender(() => activeTheme, () => activeThinkingLevel);
  });

  pi.on("thinking_level_select", (event) => {
    activeThinkingLevel = event.level;
  });

  pi.on("before_agent_start", () => {
    activeThinkingLevel = pi.getThinkingLevel();
  });
}
