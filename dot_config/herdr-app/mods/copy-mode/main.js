// Inspired by https://github.com/SiegfredLorelle/.dotfiles/blob/aa19918189dd3a502035c61986acd6093046a2e7/herdr-app/.config/herdr-app/mods/copy-mode/main.js

import { View, div } from "gpui-kit";
import { checking, closeOverlay, focused, hc, notify, props, run, terminals } from "herdr";

const HISTORY_LINES = 50000;
const SHOW_ATTEMPTS = 30;
const SHOW_RETRY_MS = 100;

const SCROLLBACK_SCRIPT = `
tmpdir=$(mktemp -d) || exit 1
trap 'rm -rf "$tmpdir"' EXIT
scrollback="$tmpdir/scrollback"
hc read --json --lines ${HISTORY_LINES} "$1" > "$tmpdir/read.json" || exit 1
jq -ej '.text | strings' "$tmpdir/read.json" > "$scrollback" || exit 1
HERDR_SCROLLBACK_INCOMPLETE=$(jq -r 'if .complete then "0" else "1" end' "$tmpdir/read.json") || exit 1
export HERDR_SCROLLBACK_INCOMPLETE
nvim --cmd 'lua vim.g.terminal_scrollback_pager = true' \\
  -c 'lua U.terminal.colorize()' \\
  -c 'lua if vim.env.HERDR_SCROLLBACK_INCOMPLETE == "1" then U.on_very_very_lazy(function() vim.notify("Older output may be missing", vim.log.levels.WARN, { title = "Scrollback" }) end) end' \\
  -- "$scrollback"
`;

export default class CopyMode extends View {
  init(_props, cx) {
    if (checking()) return;
    const { terminal, pane } = focused() ?? {};
    if (!terminal || !pane) {
      notify({ title: "Copy mode", body: "Focus a terminal pane first.", level: "warning" });
      closeOverlay(props().overlay);
      return;
    }
    cx.spawn(async (cx) => {
      let address;
      try {
        const result = await hc([
          "run",
          "--bg",
          "--rm",
          "--no-parent",
          "--json",
          "--",
          "sh",
          "-c",
          SCROLLBACK_SCRIPT,
          "herdr-copy-mode",
          terminal,
        ]);
        if (result.code !== 0) throw new Error(result.stderr || `hc exited ${result.code}`);
        address = JSON.parse(result.stdout).address;
        for (let i = 0; i < SHOW_ATTEMPTS; i++) {
          if (focused()?.pane !== pane) throw new Error("Focus changed before copy mode opened.");
          if (terminals().some((t) => t.address === address)) {
            run("terminal.show", { pane, terminal: address });
            if (focused()?.shown === address) {
              closeOverlay(props().overlay);
              return;
            }
          }
          await cx.sleep(SHOW_RETRY_MS);
        }
        throw new Error("Could not show the Neovim terminal.");
      } catch (error) {
        if (address) await hc(["kill", address]);
        notify({ title: "Copy mode", body: String(error), level: "error" });
        closeOverlay(props().overlay);
      }
    });
  }

  render() {
    return div();
  }
}
