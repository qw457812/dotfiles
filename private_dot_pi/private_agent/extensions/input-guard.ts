/**
 * Prevents accidental prompts consisting of one ASCII letter repeated one or
 * more times, such as `q` or `qqqq`.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SUSPICIOUS_INPUT = /^([A-Za-z])\1*$/;

export default function (pi: ExtensionAPI) {
  pi.on("input", async (event, ctx) => {
    if (event.source !== "interactive" || ctx.mode !== "tui" || event.images?.length) {
      return { action: "continue" };
    }

    const text = event.text.trim();
    if (!SUSPICIOUS_INPUT.test(text)) {
      return { action: "continue" };
    }

    const choice = await ctx.ui.select(`Suspicious input: ${JSON.stringify(text)}`, [
      "Discard",
      "Send anyway",
    ]);
    if (choice === "Send anyway") {
      return { action: "continue" };
    }

    return { action: "handled" };
  });
}
