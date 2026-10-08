// Ref: https://github.com/telagod/oh-pi/blob/7e59d1bcbfe1af837494a65d759d047a6474b103/pi-package/extensions/git-guard.ts

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    try {
      const { stdout } = await pi.exec("git", ["status", "--porcelain"]);
      if (stdout.trim() && ctx.hasUI) {
        const lines = stdout.trim().split("\n").length;
        ctx.ui.notify(`⚠️ Dirty repo: ${lines} uncommitted change(s)`, "warning");
      }
    } catch {
      /* not a git repo, ignore */
    }
  });
}
