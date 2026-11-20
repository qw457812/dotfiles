// Adapted from https://github.com/kriswill/dotfiles/blob/5ed9d12df57f4ce976b53a0cc99385018c94cff4/home/herdr-app/.config/herdr-app/mods/vim-nav/main.js

import { View, div } from "gpui-kit";
import { checking, focused, hc, nextCommand, notify, panes, run, terminals } from "herdr";

const CHORD = { left: "ctrl+h", down: "ctrl+j", up: "ctrl+k", right: "ctrl+l" };
const PASSTHROUGH = new Set(["nvim", "tmux", "vi-sql"]);

export default class PaneNav extends View {
  init(_props, cx) {
    if (checking()) return;
    cx.spawn(async () => {
      for (;;) {
        const direction = await nextCommand();
        try {
          await this.navigate(direction);
        } catch (error) {
          notify({ title: "Pane navigation", body: String(error), level: "error" });
        }
      }
    });
  }

  async navigate(direction) {
    if (!Object.hasOwn(CHORD, direction)) return;
    const focus = focused();
    if (!focus) return;
    // Copy mode can temporarily show a different terminal in this pane.
    const terminal = focus.shown ?? focus.terminal;
    const info = terminals().find((t) => t.address === terminal);
    const pane = panes().find((p) => p.pane === focus.pane);
    const program = info?.program ?? pane?.program;
    const foreground = (info?.report?.app || info?.status || pane?.app) && info?.foreground?.name;
    const names = (foreground ? [foreground] : [program?.key, program?.name]).map((name) =>
      String(name ?? "").toLowerCase(),
    );
    const vertical = direction === "up" || direction === "down";
    const passthrough = names.some(
      (name) => PASSTHROUGH.has(name) || (vertical && (name === "fzf" || name === "yazi")),
    );
    if (terminal && passthrough) {
      const result = await hc(["keys", terminal, CHORD[direction]]);
      if (result.code !== 0) throw new Error(result.stderr || "Could not forward navigation key.");
    } else {
      run("pane.go", { direction });
    }
  }

  render() {
    return div();
  }
}
