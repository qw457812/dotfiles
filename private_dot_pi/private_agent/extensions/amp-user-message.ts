import {
  getMarkdownTheme,
  UserMessageComponent,
  type ExtensionAPI,
  type ThemeColor,
} from "@earendil-works/pi-coding-agent";
import { Markdown, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type RenderFn = (width: number) => string[];
type PatchableUserMessagePrototype = {
  render: RenderFn;
  children?: unknown[];
  __ampUserMessageOriginalRender?: RenderFn;
  __ampUserMessagePatched?: boolean;
  __ampUserMessageGetTheme?: () => ThemeLike | undefined;
  __ampUserMessageGetThinkingLevel?: () => string;
};

type MarkdownLike = {
  text?: unknown;
};

type ThemeLike = {
  fg(color: ThemeColor, text: string): string;
  italic?(text: string): string;
};

function thinkingColorFor(level: string): ThemeColor {
  switch (level) {
    case "minimal": return "thinkingMinimal";
    case "low": return "thinkingLow";
    case "medium": return "thinkingMedium";
    case "high": return "thinkingHigh";
    case "xhigh": return "thinkingXhigh";
    default: return "thinkingOff";
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function findMarkdownText(value: unknown): string | undefined {
  if (isRecord(value) && typeof (value as MarkdownLike).text === "string") {
    return (value as { text: string }).text;
  }

  if (!isRecord(value)) return undefined;

  const children = Array.isArray(value.children) ? value.children : [];
  for (const child of children) {
    const text = findMarkdownText(child);
    if (text !== undefined) return text;
  }

  return undefined;
}

function styledUserLine(line: string, width: number, theme: ThemeLike | undefined, color: ThemeColor): string {
  const prefix = theme ? theme.fg(color, "▌") : "▌";
  const contentWidth = Math.max(1, width - visibleWidth(prefix));
  const clipped = truncateToWidth(line, contentWidth, "");
  const text = theme ? theme.fg("userMessageText", theme.italic ? theme.italic(clipped) : clipped) : clipped;
  const padding = " ".repeat(Math.max(0, contentWidth - visibleWidth(clipped)));
  return `${prefix}${text}${padding}`;
}

function renderAmpUserMessage(
  instance: PatchableUserMessagePrototype,
  width: number,
  theme: ThemeLike | undefined,
  color: ThemeColor,
): string[] | undefined {
  const text = findMarkdownText(instance);
  if (text === undefined) return undefined;

  const prefixWidth = 3;
  const contentWidth = Math.max(1, width - prefixWidth);
  const renderer = new Markdown(text, 0, 0, getMarkdownTheme());
  const lines = renderer.render(contentWidth);
  const body = lines.length > 0 ? lines : [""];

  return [
    "",
    ...body.map((line) => styledUserLine(line, width, theme, color)),
  ];
}

function patchUserMessageRender(getTheme: () => ThemeLike | undefined, getThinkingLevel: () => string): void {
  const prototype = UserMessageComponent.prototype as unknown as PatchableUserMessagePrototype;
  prototype.__ampUserMessageGetTheme = getTheme;
  prototype.__ampUserMessageGetThinkingLevel = getThinkingLevel;

  if (prototype.__ampUserMessagePatched) return;

  prototype.__ampUserMessageOriginalRender = prototype.render;
  prototype.render = function renderWithAmpUserMessage(width: number): string[] {
    const original = prototype.__ampUserMessageOriginalRender ?? prototype.render;
    const theme = prototype.__ampUserMessageGetTheme?.();
    const thinkingLevel = prototype.__ampUserMessageGetThinkingLevel?.() ?? "off";
    const color = thinkingColorFor(thinkingLevel);
    const ampLines = renderAmpUserMessage(this as PatchableUserMessagePrototype, width, theme, color);
    return ampLines ?? original.call(this, width);
  };
  prototype.__ampUserMessagePatched = true;
}

export default function (pi: ExtensionAPI) {
  let activeTheme: ThemeLike | undefined;
  let activeThinkingLevel = "off";

  const getTheme = () => activeTheme;
  const getThinkingLevel = () => activeThinkingLevel;

  patchUserMessageRender(getTheme, getThinkingLevel);

  pi.on("session_start", (_event, ctx) => {
    if (!ctx.hasUI) return;
    activeTheme = ctx.ui.theme;
    activeThinkingLevel = pi.getThinkingLevel();
    patchUserMessageRender(getTheme, getThinkingLevel);
  });

  pi.on("thinking_level_select", (event) => {
    activeThinkingLevel = event.level;
  });

  pi.on("before_agent_start", () => {
    activeThinkingLevel = pi.getThinkingLevel();
    patchUserMessageRender(getTheme, getThinkingLevel);
  });
}
