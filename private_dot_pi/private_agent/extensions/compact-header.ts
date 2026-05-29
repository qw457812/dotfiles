// Ref: https://github.com/telagod/oh-pi/blob/c8cb786cf5d934e3b61d3463ccba658943d99bc2/pi-package/extensions/compact-header.ts

/**
 * oh-pi Compact Header — table-style startup info with dynamic column widths
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI) return;

    ctx.ui.setHeader((_tui, theme) => ({
      render(width: number): string[] {
        const d = (s: string) => theme.fg("dim", s);
        const a = (s: string) => theme.fg("accent", s);

        const home = process.env.HOME || process.env.USERPROFILE;
        const cwd = home && ctx.cwd.startsWith(home) ? `~${ctx.cwd.slice(home.length)}` : ctx.cwd;
        const sid = ctx.sessionManager.getSessionId().slice(0, 8);
        const cmds = pi.getCommands();
        const prompts = cmds.filter(c => c.source === "prompt").map(c => `/${c.name}`).join("  ");
        const skills = cmds.filter(c => c.source === "skill").map(c => c.name.replace(/^skill:/, "")).join("  ");

        const pad = (s: string, w: number) => s + " ".repeat(Math.max(0, w - visibleWidth(s)));
        const t = (s: string) => truncateToWidth(s, width, "…");
        const lk = 9; // label width

        const lines: string[] = [""];

        lines.push(t(`${pad(d("cwd"), lk)}${a(cwd)}`));
        lines.push(t(`${pad(d("session"), lk)}${a(sid)}`));
        if (prompts) lines.push(t(`${pad(d("prompts"), lk)}${a(prompts)}`));
        if (skills) lines.push(t(`${pad(d("skills"), lk)}${a(skills)}`));
        lines.push(d("─".repeat(width)));

        return lines;
      },
      invalidate() {},
    }));
  });
}
