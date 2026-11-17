import { View, div } from "gpui-kit";
import { checking, closeOverlay, focused, notify, props, run } from "herdr";

const script = `
trap '[ -z "$scrollback" ] || rm -f "$scrollback"; [ -n "$HC_TERMINAL_ID" ] && hc kill "$HC_TERMINAL_ID"' EXIT
scrollback=$(mktemp) || exit 1
hc read --lines 50000 "$1" > "$scrollback" &&
  nvim --cmd 'lua vim.g.terminal_scrollback_pager = true' -c 'normal! G' -- "$scrollback"
`;

export default class CopyMode extends View {
  init() {
    if (checking()) return;
    const terminal = focused()?.terminal;
    closeOverlay(props().overlay);
    if (!terminal) {
      notify({ title: "Copy mode", body: "Focus a terminal first.", level: "warning" });
      return;
    }
    run("terminal.open", {
      name: "Scrollback",
      place: "tab",
      argv: ["sh", "-c", script, "herdr-copy-mode", terminal],
    });
  }

  render() {
    return div();
  }
}
