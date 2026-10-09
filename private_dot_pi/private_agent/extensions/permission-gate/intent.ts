import { createHash } from "node:crypto";
import type { UserMessage } from "@earendil-works/pi-ai";
import type { SessionEntry } from "@earendil-works/pi-coding-agent";

export type GateInputSource = "interactive" | "rpc" | "extension" | "unknown";

export function userText(content: UserMessage["content"]): string {
  return typeof content === "string"
    ? content
    : content
        .filter((block) => block.type === "text")
        .map((block) => block.text)
        .join("\n");
}

/** Transient correlation only; no raw input is stored in provenance metadata. */
export function inputFingerprint(text: string): string {
  return createHash("sha256").update(text).digest("hex");
}

/** Latest attributable real user only. Legacy/uncorrelated input asks, rather than guessing its source. */
export function latestUserIntent(
  entries: readonly SessionEntry[],
): { id: string; text: string } | undefined {
  for (let i = entries.length - 1; i >= 0; i--) {
    const entry = entries[i];
    if (entry.type !== "message" || entry.message.role !== "user") continue;
    if ("customType" in entry.message) continue;
    const source = (entry.message as UserMessage & { permissionGateSource?: GateInputSource })
      .permissionGateSource;
    if (source === "extension") continue;
    const text =
      source === "interactive" || source === "rpc" ? userText(entry.message.content) : "";
    return { id: entry.id, text };
  }
  return undefined;
}
