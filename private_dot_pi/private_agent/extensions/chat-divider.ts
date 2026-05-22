/**
 * Chat Divider Extension
 *
 * Neovim can `search('^ ─\\{10,}')` to jump between user messages.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("message_start", (event, ctx) => {
    if (event.message.role !== "user") return;

    const width = process.stdout.columns || 80;
    const divider = "─".repeat(width - 2);
    ctx.ui.notify(divider, "info");
  });
}
