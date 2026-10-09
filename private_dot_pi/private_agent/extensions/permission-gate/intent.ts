import type { UserMessage } from "@earendil-works/pi-ai";
import type { SessionEntry } from "@earendil-works/pi-coding-agent";

export function userText(content: UserMessage["content"]): string {
  return typeof content === "string"
    ? content
    : content
        .filter((block) => block.type === "text")
        .map((block) => block.text)
        .join("\n");
}

/** Latest ordinary user on the current branch, including extension-injected user messages. */
export function latestUserIntent(
  entries: readonly SessionEntry[],
): { id: string; text: string } | undefined {
  for (let i = entries.length - 1; i >= 0; i--) {
    const entry = entries[i];
    if (entry.type !== "message" || entry.message.role !== "user") continue;
    if ("customType" in entry.message) continue;
    return { id: entry.id, text: userText(entry.message.content) };
  }
  return undefined;
}
